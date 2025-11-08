// Complete SwiftUI iOS app that consumes The Cat API (https://thecatapi.com/)
// Single-file reference implementation (split into logical sections).
// Requirements satisfied:
// - Modular separation (Models, Network service, Image cache, ViewModels, Views)
// - Async/await networking with error handling
// - Basic image cache (NSCache)
// - SwiftUI interface, dynamic updates
// - No external dependencies
// - Clear comments explaining each major part

import SwiftUI
import Combine

// MARK: - Configuration
/// API configuration. The Cat API allows anonymous requests, but you may provide an API key
/// if you have one (optional). If you use a key, set it here; otherwise leave nil.
private enum APIConfig {
    static let baseURL = "https://api.thecatapi.com/v1"
    static let imagesSearchPath = "/images/search"
    // Optional: paste your API key here to increase rate-limits: "YOUR_API_KEY"
    static let apiKey: String? = nil
}

// MARK: - Models
/// Main model representing an image object returned by The Cat API.
struct CatImage: Codable, Identifiable, Equatable {
    let id: String
    let url: URL
    let width: Int?
    let height: Int?
    let breeds: [Breed]?

    // The API sometimes returns other fields; we only model what's needed.
    enum CodingKeys: String, CodingKey {
        case id, url, width, height, breeds
    }
}

/// Breed information (optional, may be empty).
struct Breed: Codable, Equatable {
    let id: String?
    let name: String?
    let temperament: String?
    let origin: String?
    let description: String?
}

// MARK: - Networking
/// Low-level NetworkError used across the app
enum NetworkError: LocalizedError {
    case invalidURL
    case requestFailed(statusCode: Int)
    case noData
    case decodingFailed(Error)
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .requestFailed(let status): return "Request failed with status \(status)"
        case .noData: return "No data received from server"
        case .decodingFailed(let err): return "Decoding failed: \(err.localizedDescription)"
        case .underlying(let err): return err.localizedDescription
        }
    }
}

/// A small, modular networking service tailored for The Cat API.
final class NetworkService {
    static let shared = NetworkService()
    private init() {}

    private var defaultSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    /// Fetches cat images from The Cat API.
    /// - Parameters:
    ///   - limit: number of images to request
    /// - Returns: an array of `CatImage`
    func fetchCatImages(limit: Int = 20) async throws -> [CatImage] {
        guard var components = URLComponents(string: APIConfig.baseURL + APIConfig.imagesSearchPath) else {
            throw NetworkError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            // You can add extra query items such as size, mime_types, order, page, breed_ids etc.
            // e.g. URLQueryItem(name: "mime_types", value: "jpg,png")
        ]

        guard let url = components.url else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Add API key header if provided (optional)
        if let key = APIConfig.apiKey {
            request.setValue(key, forHTTPHeaderField: "x-api-key")
        }

        do {
            let (data, response) = try await defaultSession.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw NetworkError.requestFailed(statusCode: http.statusCode)
            }

            let decoder = JSONDecoder()
            do {
                let images = try decoder.decode([CatImage].self, from: data)
                return images
            } catch {
                throw NetworkError.decodingFailed(error)
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.underlying(error)
        }
    }
}

// MARK: - Image Cache
/// Basic in-memory image cache using NSCache. This avoids re-downloading images during the session.
final class ImageCache {
    static let shared = ImageCache()
    private init() {}

    private let cache = NSCache<NSURL, UIImage>()

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func insertImage(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }

    func removeImage(for url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }

    func removeAll() {
        cache.removeAllObjects()
    }
}

// MARK: - Image Loader
/// ObservableObject that loads a remote image and publishes updates. Uses cache first.
@MainActor
final class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading: Bool = false
    @Published var error: Error?

    private var task: Task<Void, Never>?

    deinit { task?.cancel() }

    /// Loads an image from a URL with caching.
    func load(from url: URL) {
        // If already cached, return immediately
        if let cached = ImageCache.shared.image(for: url) {
            self.image = cached
            return
        }

        isLoading = true
        error = nil

        task = Task { [weak self] in
            guard let self = self else { return }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    throw NetworkError.requestFailed(statusCode: http.statusCode)
                }
                guard let uiImage = UIImage(data: data) else { throw NetworkError.noData }

                // Store in cache
                ImageCache.shared.insertImage(uiImage, for: url)

                // Publish on main actor
                await MainActor.run {
                    self.image = uiImage
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }

    func cancel() {
        task?.cancel()
    }
}

// MARK: - ViewModels
/// Represents UI state for the list of cats
@MainActor
final class CatListViewModel: ObservableObject {
    @Published private(set) var cats: [CatImage] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    /// Fetch images
    func fetchCats(limit: Int = 30) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let images = try await NetworkService.shared.fetchCatImages(limit: limit)
                // update published property
                self.cats = images
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    /// Refresh explicitly
    func refresh() {
        fetchCats(limit: cats.count > 0 ? cats.count : 30)
    }
}

// MARK: - Views
/// Simple, reusable AsyncImageView that uses ImageLoader and ImageCache.
struct AsyncCachedImageView: View {
    @StateObject private var loader = ImageLoader()
    let url: URL
    let contentMode: ContentMode
    let placeholder: AnyView

    init(url: URL,
         contentMode: ContentMode = .fill,
         placeholder: AnyView = AnyView(ProgressView())) {
        self.url = url
        self.contentMode = contentMode
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let img = loader.image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if loader.isLoading {
                placeholder
            } else if loader.error != nil {
                // Show a simple fallback
                VStack {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                    Text("Erro ao carregar imagem")
                        .font(.caption)
                }
            } else {
                placeholder
            }
        }
        .task(id: url) {
            loader.load(from: url)
        }
        .onDisappear {
            loader.cancel()
        }
    }
}

/// Main screen: grid of cat images
struct CatGridView: View {
    @StateObject private var vm = CatListViewModel()
    @State private var columns: [GridItem] = [GridItem(.flexible()), GridItem(.flexible())]
    @State private var selected: CatImage?
    @State private var showDetail: Bool = false

    var body: some View {
        NavigationView {
            Group {
                if vm.isLoading && vm.cats.isEmpty {
                    VStack {
                        ProgressView("Carregando gatos...")
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = vm.errorMessage {
                    VStack(spacing: 12) {
                        Text("Erro: \(err)")
                            .multilineTextAlignment(.center)
                        Button("Tentar novamente") { vm.refresh() }
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(vm.cats) { cat in
                                CatCellView(cat: cat)
                                    .onTapGesture {
                                        selected = cat
                                        showDetail = true
                                    }
                            }
                        }
                        .padding(8)
                        .animation(.default, value: vm.cats)
                    }
                    .refreshable { vm.refresh() }
                }
            }
            .navigationTitle("Gatos")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { vm.fetchCats(limit: 30) }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Recarregar")
                }
            }
            .sheet(isPresented: $showDetail) {
                if let selected = selected {
                    CatDetailView(cat: selected)
                }
            }
            .task { vm.fetchCats(limit: 30) }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

/// Small tile for each cat in the grid
struct CatCellView: View {
    let cat: CatImage

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncCachedImageView(url: cat.url, contentMode: .fill, placeholder: AnyView(ProgressView()))
                .frame(height: 160)
                .clipped()
                .cornerRadius(8)

            // Overlay with breed name if available
            if let firstBreed = cat.breeds?.first, let name = firstBreed.name {
                Text(name)
                    .font(.caption)
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(6)
                    .padding(8)
            }
        }
        .shadow(radius: 1)
    }
}

/// Detail view that shows a larger image and extra info
struct CatDetailView: View {
    let cat: CatImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                AsyncCachedImageView(url: cat.url, contentMode: .fit, placeholder: AnyView(ProgressView()))
                    .frame(maxHeight: 400)
                    .padding()

                VStack(alignment: .leading, spacing: 8) {
                    Text("ID: \(cat.id)")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    if let breeds = cat.breeds, !breeds.isEmpty {
                        ForEach(breeds.indices, id: \.self) { idx in
                            let breed = breeds[idx]
                            if let name = breed.name {
                                Text(name).font(.headline)
                            }
                            if let origin = breed.origin {
                                Text("Origem: \(origin)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            if let temperament = breed.temperament {
                                Text(temperament)
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if let desc = breed.description {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        Text("Sem informações de raça disponíveis para esta imagem.")
                            .font(.body)
                    }
                }
                .padding()

                Spacer()
            }
            .navigationTitle("Detalhes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: shareImage) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    private func shareImage() {
        guard let image = ImageCache.shared.image(for: cat.url) else { return }
        let av = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            root.present(av, animated: true, completion: nil)
        }
    }
}

// MARK: - App Entry
@main
struct TheCatApp: App {
    var body: some Scene {
        WindowGroup {
            CatGridView()
        }
    }
}

// MARK: - Notes / Future expansion ideas
/*
 - This single-file example is intentionally modular: move each section into separate files
   in a real project (Models/, Services/, ViewModels/, Views/).
 - Add persistent disk cache for images to survive app restarts.
 - Add pagination (page & order query params) to support larger datasets.
 - Add filters for breeds (thecatapi provides /breeds endpoint).
 - Add unit tests for NetworkService and ViewModels.
 - Consider extracting APIConfig to a more secure place if storing private API keys (Keychain).
*/
