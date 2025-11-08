// VIPER-structured SwiftUI app consuming The Cat API
// Single-file reference with fixes for: main-actor init, view bridge, keypath escape, catch/throw, Equatable, etc.

import SwiftUI
import Combine

// MARK: - Config
private enum APIConfig {
    static let baseURL = "https://api.thecatapi.com/v1"
    static let imagesSearchPath = "/images/search"
    static let apiKey: String? = nil // optional API key
}

// MARK: - Entities
struct Breed: Codable, Equatable {
    let id: String?
    let name: String?
    let temperament: String?
    let origin: String?
    let description: String?
}

struct CatImage: Codable, Identifiable, Equatable {
    let id: String
    let url: URL
    let width: Int?
    let height: Int?
    let breeds: [Breed]?

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

// MARK: - Image Cache & Loader (unchanged behavior)
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

// MARK: - VIPER Protocols

// View <- Presenter: class-bound so Presenter can call bridge methods (bridge is a class)
protocol CatListPresenterToViewProtocol: AnyObject {
    func showLoading()
    func hideLoading()
    func showCats(_ cats: [CatImage])
    func showError(_ message: String)
}

// View -> Presenter
protocol CatListViewToPresenterProtocol: AnyObject {
    func viewDidLoad()
    func didPullToRefresh()
    func didSelectCat(_ cat: CatImage)
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
    // Create module on main actor so @MainActor Presenter init is safe
    @MainActor
    static func createModule() -> some View {
        let interactor = CatListInteractor()
        let router = CatListRouter()
        let presenter = CatListPresenter(interactor: interactor, router: router) // Presenter is @MainActor
        interactor.presenter = presenter

        // Bridge (ObservableObject) that the SwiftUI view will observe and that conforms to the view protocol
        let bridge = CatListViewBridge()
        presenter.view = bridge
        bridge.presenter = presenter // bridge can call actions on presenter

        // SwiftUI view observes bridge and receives presenter for user actions
        return CatListView(presenter: presenter, bridge: bridge)
    }

    // Present detail using UIKit hosting controller
    func navigateToDetail(from view: UIViewController?, with cat: CatImage) {
        let detail = CatDetailView(cat: cat)
        let hosting = UIHostingController(rootView: detail)
        hosting.modalPresentationStyle = .automatic
        // If view is provided, present from it; otherwise fallback to root controller
        if let v = view {
            v.present(hosting, animated: true, completion: nil)
        } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let root = windowScene.windows.first?.rootViewController {
            root.present(hosting, animated: true, completion: nil)
        }
    }
}

// MARK: - Presenter
@MainActor
final class CatListPresenter: CatListViewToPresenterProtocol, CatListInteractorToPresenterProtocol {
    private let interactor: CatListPresenterToInteractorProtocol
    private let router: CatListPresenterToRouterProtocol
    weak var view: CatListPresenterToViewProtocol? // will be the bridge (class)

    private(set) var cats: [CatImage] = []

    init(interactor: CatListPresenterToInteractorProtocol, router: CatListPresenterToRouterProtocol) {
        self.interactor = interactor
        self.router = router
    }

    // View actions
    func viewDidLoad() {
        view?.showLoading()
        interactor.fetchCats(limit: 30)
    }

    func didPullToRefresh() {
        interactor.fetchCats(limit: cats.count > 0 ? cats.count : 30)
    }

    func didSelectCat(_ cat: CatImage) {
        // Presenter asks view (bridge) for underlying UIViewController if needed
        if let bridge = view as? CatListViewBridge {
            router.navigateToDetail(from: bridge.viewController, with: cat)
        } else {
            router.navigateToDetail(from: nil, with: cat)
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

// MARK: - View Bridge (class) - Presenter -> View communication
// Bridge is ObservableObject so SwiftUI view can observe published properties.
// It also conforms to CatListPresenterToViewProtocol so Presenter can call it.
final class CatListViewBridge: ObservableObject, CatListPresenterToViewProtocol {
    // Published properties that SwiftUI will bind to
    @Published var cats: [CatImage] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Weak reference to a UIViewController provided by the SwiftUI view (used for Router presentation)
    weak var viewController: UIViewController?

    // Keep a presenter reference to call actions (View -> Presenter)
    weak var presenter: CatListViewToPresenterProtocol?

    // Presenter calls these:
    func showLoading() { Task { await MainActor.run { self.isLoading = true; self.errorMessage = nil } } }
    func hideLoading() { Task { await MainActor.run { self.isLoading = false } } }
    func showCats(_ cats: [CatImage]) { Task { await MainActor.run { self.cats = cats; self.errorMessage = nil } } }
    func showError(_ message: String) { Task { await MainActor.run { self.errorMessage = message } } }
}

// MARK: - SwiftUI Views (View layer)

// Controller accessor to obtain UIViewController to pass to bridge (for Router)
struct ControllerAccessor: UIViewControllerRepresentable {
    let callback: (UIViewController?) -> Void
    func makeUIViewController(context: Context) -> ControllerAccessorViewController { ControllerAccessorViewController(callback: callback) }
    func updateUIViewController(_ uiViewController: ControllerAccessorViewController, context: Context) {}
}

final class ControllerAccessorViewController: UIViewController {
    var callback: (UIViewController?) -> Void
    init(callback: @escaping (UIViewController?) -> Void) { self.callback = callback; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // pass the parent (embedding controller) so Router can present from correct VC
        callback(parent ?? self)
    }
}

// Main list view.
// The view is driven by the bridge (ObservableObject) and sends user actions to presenter.
struct CatListView: View {
    // Presenter receives actions (View -> Presenter)
    let presenter: CatListViewToPresenterProtocol
    // Bridge provides published state (Presenter -> View)
    @ObservedObject var bridge: CatListViewBridge

    // Local UI state for sheet selection
    @State private var selected: CatImage?

    init(presenter: CatListViewToPresenterProtocol, bridge: CatListViewBridge) {
        self.presenter = presenter
        self._bridge = ObservedObject(wrappedValue: bridge)
    }

    var body: some View {
        NavigationView {
            Group {
                if bridge.isLoading && bridge.cats.isEmpty {
                    ProgressView("Carregando gatos...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = bridge.errorMessage {
                    VStack(spacing: 12) {
                        Text("Erro: \(err)")
                            .multilineTextAlignment(.center)
                        Button("Tentar novamente") { presenter.didPullToRefresh() }
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(bridge.cats) { cat in
                                CatCellView(cat: cat)
                                    .onTapGesture {
                                        selected = cat
                                        presenter.didSelectCat(cat)
                                    }
                            }
                        }
                        .padding(8)
                        .animation(.default, value: bridge.cats)
                    }
                    .refreshable { presenter.didPullToRefresh() }
                }
            }
            .navigationTitle("Gatos")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { presenter.viewDidLoad() }) { Image(systemName: "arrow.clockwise") }
                }
            }
            .onAppear { presenter.viewDidLoad() }
            .sheet(item: $selected) { cat in CatDetailView(cat: cat) }
            // Provide UIViewController to bridge for Router usage
            .background(ControllerAccessor { vc in
                if bridge.viewController == nil {
                    bridge.viewController = vc
                }
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// Cell view
struct CatCellView: View {
    let cat: CatImage
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncCachedImageView(url: cat.url, contentMode: .fill)
                .frame(height: 160)
                .clipped()
                .cornerRadius(8)
            if let name = cat.breeds?.first?.name {
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

// Detail view remains SwiftUI
struct CatDetailView: View {
    let cat: CatImage
    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                AsyncCachedImageView(url: cat.url, contentMode: .fit)
                    .frame(maxHeight: 400)
                    .padding()

                VStack(alignment: .leading, spacing: 8) {
                    Text("ID: \(cat.id)").font(.footnote).foregroundColor(.secondary)
                    if let breeds = cat.breeds, !breeds.isEmpty {
                        ForEach(breeds.indices, id: \.self) { idx in
                            let b = breeds[idx]
                            if let name = b.name { Text(name).font(.headline) }
                            if let origin = b.origin { Text("Origem: \(origin)").font(.subheadline).foregroundColor(.secondary) }
                            if let t = b.temperament { Text(t).font(.body) }
                            if let d = b.description { Text(d).font(.caption).foregroundColor(.secondary) }
                        }
                    } else {
                        Text("Sem informações de raça disponíveis.").font(.body)
                    }
                }
                .padding()
                Spacer()
            }
            .navigationTitle("Detalhes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") {
                        // close using root view controller
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let root = windowScene.windows.first?.rootViewController {
                            root.dismiss(animated: true)
                        }
                    }
                }
            }
        }
    }
}

// Async image view using ImageLoader and ImageCache
struct AsyncCachedImageView: View {
    @StateObject private var loader = ImageLoader()
    let url: URL
    let contentMode: ContentMode

    init(url: URL, contentMode: ContentMode = .fill) {
        self.url = url
        self.contentMode = contentMode
    }

    var body: some View {
        Group {
            if let img = loader.image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if loader.isLoading {
                ProgressView()
            } else if loader.error != nil {
                VStack { Image(systemName: "photo"); Text("Erro ao carregar") }
            } else {
                ProgressView()
            }
        }
        .task(id: url) { loader.load(from: url) }
        .onDisappear { loader.cancel() }
    }
}

// MARK: - App Entry
@main
struct TheCatApp_VIPER_Fixed: App {
    var body: some Scene {
        WindowGroup {
            // Module creation is on MainActor inside Router.createModule()
            CatListRouter.createModule()
        }
    }
}
