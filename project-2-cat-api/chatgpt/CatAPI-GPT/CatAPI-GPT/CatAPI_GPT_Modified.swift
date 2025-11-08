// VIPER-structured SwiftUI iOS app that consumes The Cat API
// Single-file reference implementation for clarity. In a real project, split into separate files:
// Entities/, Interactors/, Presenters/, Routers/, Views/, Services/

import SwiftUI
import Combine

// MARK: - Configuration
private enum APIConfig {
    static let baseURL = "https://api.thecatapi.com/v1"
    static let imagesSearchPath = "/images/search"
    static let apiKey: String? = nil // optional
}

// MARK: - Entities (Model Objects)
/// Breed entity
struct Breed: Codable, Equatable {
    let id: String?
    let name: String?
    let temperament: String?
    let origin: String?
    let description: String?
}

/// CatImage entity
struct CatImage: Codable, Identifiable, Equatable {
    let id: String
    let url: URL
    let width: Int?
    let height: Int?
    let breeds: [Breed]?

    // Consider two cat images equal if their id matches.
    static func == (lhs: CatImage, rhs: CatImage) -> Bool { lhs.id == rhs.id }
}

// MARK: - Networking / Services
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

/// Network service (single responsibility: fetch API data)
final class NetworkService {
    static let shared = NetworkService()
    private init() {}

    private var session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: cfg)
    }()

    func fetchCatImages(limit: Int = 20) async throws -> [CatImage] {
        guard var components = URLComponents(string: APIConfig.baseURL + APIConfig.imagesSearchPath) else {
            throw NetworkError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]
        guard let url = components.url else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let key = APIConfig.apiKey { request.setValue(key, forHTTPHeaderField: "x-api-key") }

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw NetworkError.requestFailed(statusCode: http.statusCode)
            }
            let decoder = JSONDecoder()
            do {
                let images = try decoder.decode([CatImage].self, from: data)
                return images
            } catch let err {
                throw NetworkError.decodingFailed(err)
            }
        } catch let err as NetworkError {
            throw err
        } catch let err {
            throw NetworkError.underlying(err)
        }
    }
}

// MARK: - Image Cache & Loader
final class ImageCache {
    static let shared = ImageCache()
    private init() {}
    private let cache = NSCache<NSURL, UIImage>()
    func image(for url: URL) -> UIImage? { cache.object(forKey: url as NSURL) }
    func insertImage(_ image: UIImage, for url: URL) { cache.setObject(image, forKey: url as NSURL) }
}

@MainActor
final class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading: Bool = false
    @Published var error: Error?

    private var task: Task<Void, Never>?

    deinit { task?.cancel() }

    func load(from url: URL) {
        if let cached = ImageCache.shared.image(for: url) { self.image = cached; return }
        isLoading = true; error = nil
        task = Task { [weak self] in
            guard let self = self else { return }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    throw NetworkError.requestFailed(statusCode: http.statusCode)
                }
                guard let ui = UIImage(data: data) else { throw NetworkError.noData }
                ImageCache.shared.insertImage(ui, for: url)
                await MainActor.run { self.image = ui; self.isLoading = false }
            } catch let err {
                await MainActor.run { self.error = err; self.isLoading = false }
            }
        }
    }

    func cancel() { task?.cancel() }
}

// MARK: - VIPER Protocol Definitions
// Define clear protocols so components can be swapped/tested independently.

// View -> Presenter
protocol CatListViewToPresenterProtocol: AnyObject {
    func viewDidLoad()
    func didPullToRefresh()
    func didSelectCat(_ cat: CatImage)
}

// Presenter -> View
protocol CatListPresenterToViewProtocol: AnyObject {
    func showLoading()
    func hideLoading()
    func showCats(_ cats: [CatImage])
    func showError(_ message: String)
}

// Presenter -> Interactor
protocol CatListPresenterToInteractorProtocol: AnyObject {
    func fetchCats(limit: Int)
}

// Interactor -> Presenter
protocol CatListInteractorToPresenterProtocol: AnyObject {
    func fetched(cats: [CatImage])
    func failedFetch(error: Error)
}

// Presenter -> Router
protocol CatListPresenterToRouterProtocol: AnyObject {
    func navigateToDetail(from view: UIViewController?, with cat: CatImage)
}

// MARK: - Interactor
final class CatListInteractor: CatListPresenterToInteractorProtocol {
    weak var presenter: CatListInteractorToPresenterProtocol?

    func fetchCats(limit: Int = 30) {
        Task {
            do {
                let cats = try await NetworkService.shared.fetchCatImages(limit: limit)
                presenter?.fetched(cats: cats)
            } catch let err {
                presenter?.failedFetch(error: err)
            }
        }
    }
}

// MARK: - Router
final class CatListRouter: CatListPresenterToRouterProtocol {
    static func createModule() -> some View {
        // Build VIPER stack and return SwiftUI hosting view that injects presenter into SwiftUI view
        let interactor = CatListInteractor()
        let router = CatListRouter()
        let presenter = CatListPresenter(interactor: interactor, router: router)
        interactor.presenter = presenter
        let contentView = CatListContainerView(presenter: presenter)
        return contentView
    }

    func navigateToDetail(from view: UIViewController?, with cat: CatImage) {
        // Present a simple UIHostingController with detail view
        let detail = CatDetailView(cat: cat)
        let hosting = UIHostingController(rootView: detail)
        hosting.modalPresentationStyle = .automatic
        view?.present(hosting, animated: true, completion: nil)
    }
}

// MARK: - Presenter
@MainActor
final class CatListPresenter: CatListViewToPresenterProtocol, CatListInteractorToPresenterProtocol {
    // References to other layers
    private let interactor: CatListPresenterToInteractorProtocol
    private let router: CatListPresenterToRouterProtocol
    weak var view: CatListPresenterToViewProtocol?

    // Keep last state
    private(set) var cats: [CatImage] = []

    init(interactor: CatListPresenterToInteractorProtocol, router: CatListPresenterToRouterProtocol) {
        self.interactor = interactor
        self.router = router
    }

    // View lifecycle
    func viewDidLoad() { view?.showLoading(); interactor.fetchCats(limit: 30) }
    func didPullToRefresh() { interactor.fetchCats(limit: cats.count > 0 ? cats.count : 30) }

    func didSelectCat(_ cat: CatImage) {
        // We need a UIViewController reference from the SwiftUI view to present UIKit modal.
        // The container view will pass the controller when calling this method.
        // For simplicity, presenter asks view to provide it through the view reference via method on view protocol.
        if let viewController = (view as? CatListViewPresenterBridge)?.viewController {
            router.navigateToDetail(from: viewController, with: cat)
        }
    }

    // Interactor callbacks
    func fetched(cats: [CatImage]) {
        self.cats = cats
        view?.hideLoading()
        view?.showCats(cats)
    }

    func failedFetch(error: Error) {
        view?.hideLoading()
        view?.showError(error.localizedDescription)
    }
}

// A small bridge to allow presenter to access UIViewController from SwiftUI view when needed
protocol CatListViewPresenterBridge: CatListPresenterToViewProtocol {
    var viewController: UIViewController? { get }
}

// MARK: - SwiftUI Views (View Layer)

/// A container that adapts the SwiftUI view to the Presenter interface and provides a VC bridge.
struct CatListContainerView: View, CatListViewPresenterBridge {
    // Presenter injected by Router
    @ObservedObject private var holder: PresenterHolder

    // Provide access to an underlying UIViewController to the presenter when needed
    var viewController: UIViewController?

    // Local view state
    @State private var cats: [CatImage] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showDetail: Bool = false
    @State private var selected: CatImage?

    init(presenter: CatListPresenter) {
        let holder = PresenterHolder(presenter: presenter)
        self._holder = ObservedObject(wrappedValue: holder)
        holder.presenter.view = holder
    }

    var body: some View {
        NavigationView {
            Group {
                if isLoading && cats.isEmpty {
                    ProgressView("Carregando gatos...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = errorMessage {
                    VStack(spacing: 12) {
                        Text("Erro: \(err)")
                            .multilineTextAlignment(.center)
                        Button("Tentar novamente") { holder.presenter.didPullToRefresh() }
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(cats) { cat in
                                CatCellView(cat: cat)
                                    .onTapGesture {
                                        selected = cat
                                        // Let presenter handle navigation
                                        holder.presenter.didSelectCat(cat)
                                    }
                            }
                        }
                        .padding(8)
                        .animation(.default, value: cats)
                    }
                    .refreshable { holder.presenter.didPullToRefresh() }
                }
            }
            .navigationTitle("Gatos")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(action: { holder.presenter.viewDidLoad() }) { Image(systemName: "arrow.clockwise") } } }
            .onAppear { holder.presenter.viewDidLoad() }
            .sheet(item: $selected) { cat in CatDetailView(cat: cat) }
        }
        .background(ControllerAccessor { vc in self.setViewControllerIfNeeded(vc) })
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - CatListPresenterToViewProtocol methods (via PresenterHolder)
    func showLoading() { isLoading = true }
    func hideLoading() { isLoading = false }
    func showCats(_ cats: [CatImage]) { self.cats = cats }
    func showError(_ message: String) { errorMessage = message }

    // Helper: supply VC to presenter on first set
    private func setViewControllerIfNeeded(_ vc: UIViewController?) {
        if viewController == nil { viewController = vc; holder.presenter.view = self }
    }
}

/// PresenterHolder acts as an ObservableObject wrapper for the presenter to allow SwiftUI updates.
final class PresenterHolder: ObservableObject, CatListPresenterToViewProtocol {
    let presenter: CatListPresenter
    init(presenter: CatListPresenter) { self.presenter = presenter }

    // The presenter will call these methods on the holder; holder forwards to SwiftUI container via closure injection.
    func showLoading() { DispatchQueue.main.async { self.objectWillChange.send() } }
    func hideLoading() { DispatchQueue.main.async { self.objectWillChange.send() } }
    func showCats(_ cats: [CatImage]) { DispatchQueue.main.async { self.objectWillChange.send() } }
    func showError(_ message: String) { DispatchQueue.main.async { self.objectWillChange.send() } }
}

// A utility that inserts a UIViewController into the SwiftUI view hierarchy so we can bridge to UIKit for navigation.
struct ControllerAccessor: UIViewControllerRepresentable {
    var callback: (UIViewController?) -> Void
    func makeUIViewController(context: Context) -> ControllerAccessorViewController { ControllerAccessorViewController(callback: callback) }
    func updateUIViewController(_ uiViewController: ControllerAccessorViewController, context: Context) {}
}

final class ControllerAccessorViewController: UIViewController {
    var callback: (UIViewController?) -> Void
    init(callback: @escaping (UIViewController?) -> Void) { self.callback = callback; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); callback(parent ?? self) }
}

// MARK: - Reusable Views
struct AsyncCachedImageView: View {
    @StateObject private var loader = ImageLoader()
    let url: URL
    let contentMode: ContentMode

    init(url: URL, contentMode: ContentMode = .fill) { self.url = url; self.contentMode = contentMode }

    var body: some View {
        Group {
            if let img = loader.image { Image(uiImage: img).resizable().aspectRatio(contentMode: contentMode) }
            else if loader.isLoading { ProgressView() }
            else if loader.error != nil { VStack { Image(systemName: "photo"); Text("Erro ao carregar") } }
            else { ProgressView() }
        }
        .task(id: url) { loader.load(from: url) }
        .onDisappear { loader.cancel() }
    }
}

struct CatCellView: View {
    let cat: CatImage
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncCachedImageView(url: cat.url, contentMode: .fill)
                .frame(height: 160)
                .clipped()
                .cornerRadius(8)
            if let name = cat.breeds?.first?.name {
                Text(name).font(.caption).padding(6).background(.ultraThinMaterial).cornerRadius(6).padding(8)
            }
        }
        .shadow(radius: 1)
    }
}

struct CatDetailView: View {
    let cat: CatImage
    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                AsyncCachedImageView(url: cat.url, contentMode: .fit).frame(maxHeight: 400).padding()
                VStack(alignment: .leading, spacing: 8) {
                    Text("ID: \(cat.id)").font(.footnote).foregroundColor(.secondary)
                    if let breeds = cat.breeds, !breeds.isEmpty {
                        ForEach(breeds.indices, id: \\.self) { idx in
                            let b = breeds[idx]
                            if let name = b.name { Text(name).font(.headline) }
                            if let origin = b.origin { Text("Origem: \(origin)").font(.subheadline).foregroundColor(.secondary) }
                            if let t = b.temperament { Text(t).font(.body) }
                            if let d = b.description { Text(d).font(.caption).foregroundColor(.secondary) }
                        }
                    } else { Text("Sem informações de raça disponíveis.").font(.body) }
                }
                .padding()
                Spacer()
            }
            .navigationTitle("Detalhes")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fechar") { if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene, let root = windowScene.windows.first?.rootViewController { root.dismiss(animated: true) } } } }
        }
    }
}

// MARK: - App Entry
@main
struct TheCatApp_VIPER: App {
    var body: some Scene { WindowGroup { CatListRouter.createModule() } }
}

// MARK: - Notes
/*
 - This file demonstrates VIPER in a compact form using SwiftUI for the view layer.
 - For production: split into files per layer and add unit tests for Interactor/Presenter.
 - PresenterHolder currently is a minimal bridge. For richer updates, forward model data through Combine publishers from Presenter to the SwiftUI view.
 - Router uses a simple UIKit presentation approach. You can expand to navigation stacks or deep links.
*/
