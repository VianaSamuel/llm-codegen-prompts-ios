// MARK: - VIPER Architecture Implementation
// Aplicativo Cat API refatorado de MVVM para VIPER
// Mantém toda funcionalidade existente com melhor separação de responsabilidades

import Foundation
import UIKit

// MARK: - Entities (Models) - Mantidos da arquitetura original

struct Cat: Codable, Identifiable {
    let id: String
    let url: String
    let width: Int
    let height: Int
    let breeds: [Breed]?
    let categories: [Category]?
    var isFavorite: Bool = false
}

struct Breed: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let temperament: String?
    let origin: String?
    let life_span: String?
    let weight: Weight?
    let energy_level: Int?
    
    var allTraits: String {
        var traits: [String] = []
        if let temperament = temperament { traits.append(temperament) }
        if let origin = origin { traits.append("Origin: \(origin)") }
        if let lifeSpan = life_span { traits.append("Life Span: \(lifeSpan)") }
        return traits.joined(separator: " • ")
    }
}

struct Weight: Codable {
    let imperial: String
    let metric: String
}

struct Category: Codable, Identifiable {
    let id: Int
    let name: String
}

// MARK: - Infrastructure (Mantido inalterado)

enum CatAPIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case noData
    case rateLimitExceeded
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .decodingError: return "Failed to decode response"
        case .noData: return "No data received"
        case .rateLimitExceeded: return "Too many requests. Please wait."
        case .serverError(let code): return "Server error: \(code)"
        }
    }
}

enum LoadingState {
    case idle
    case loading
    case loaded
    case error(Error)
}

class NetworkManager {
    static let shared = NetworkManager()
    private init() {}
    
    private let baseURL = "https://api.thecatapi.com/v1"
    private let apiKey = ""
    private var lastRequestTime: Date?
    private let minimumRequestInterval: TimeInterval = 0.1
    
    private func checkRateLimit() async throws {
        if let lastTime = lastRequestTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < minimumRequestInterval {
                try await Task.sleep(nanoseconds: UInt64((minimumRequestInterval - elapsed) * 1_000_000_000))
            }
        }
        lastRequestTime = Date()
    }
    
    private func request<T: Decodable>(endpoint: String, queryItems: [URLQueryItem] = []) async throws -> T {
        try await checkRateLimit()
        
        guard var components = URLComponents(string: "\(baseURL)\(endpoint)") else {
            throw CatAPIError.invalidURL
        }
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw CatAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CatAPIError.noData
            }
            
            if httpResponse.statusCode == 429 {
                throw CatAPIError.rateLimitExceeded
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw CatAPIError.serverError(httpResponse.statusCode)
            }
            
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as CatAPIError {
            throw error
        } catch {
            throw CatAPIError.networkError(error)
        }
    }
    
    func fetchRandomCats(limit: Int = 10, breedId: String? = nil, categoryId: Int? = nil) async throws -> [Cat] {
        var queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]
        if let breedId = breedId {
            queryItems.append(URLQueryItem(name: "breed_ids", value: breedId))
        }
        if let categoryId = categoryId {
            queryItems.append(URLQueryItem(name: "category_ids", value: "\(categoryId)"))
        }
        return try await request(endpoint: "/images/search", queryItems: queryItems)
    }
    
    func fetchBreeds() async throws -> [Breed] {
        return try await request(endpoint: "/breeds")
    }
    
    func fetchCategories() async throws -> [Category] {
        return try await request(endpoint: "/categories")
    }
}

class CatService {
    private let networkManager: NetworkManager
    
    init(networkManager: NetworkManager = .shared) {
        self.networkManager = networkManager
    }
    
    func getRandomCats(limit: Int = 10, breedId: String? = nil, categoryId: Int? = nil) async -> Result<[Cat], CatAPIError> {
        do {
            let cats = try await networkManager.fetchRandomCats(limit: limit, breedId: breedId, categoryId: categoryId)
            return .success(cats)
        } catch let error as CatAPIError {
            return .failure(error)
        } catch {
            return .failure(.networkError(error))
        }
    }
    
    func getBreeds() async -> Result<[Breed], CatAPIError> {
        do {
            let breeds = try await networkManager.fetchBreeds()
            return .success(breeds)
        } catch let error as CatAPIError {
            return .failure(error)
        } catch {
            return .failure(.networkError(error))
        }
    }
    
    func getCategories() async -> Result<[Category], CatAPIError> {
        do {
            let categories = try await networkManager.fetchCategories()
            return .success(categories)
        } catch let error as CatAPIError {
            return .failure(error)
        } catch {
            return .failure(.networkError(error))
        }
    }
}

class ImageCache {
    static let shared = ImageCache()
    private init() {}
    
    private let cache = NSCache<NSString, UIImage>()
    private var downloadTasks: [String: Task<UIImage?, Never>] = [:]
    
    func image(for url: String) -> UIImage? {
        return cache.object(forKey: url as NSString)
    }
    
    func setImage(_ image: UIImage, for url: String) {
        cache.setObject(image, forKey: url as NSString)
    }
    
    func downloadImage(from urlString: String, targetSize: CGSize? = nil) async -> UIImage? {
        if let cachedImage = image(for: urlString) {
            return cachedImage
        }
        
        if let existingTask = downloadTasks[urlString] {
            return await existingTask.value
        }
        
        let task = Task<UIImage?, Never> {
            guard let url = URL(string: urlString) else { return nil }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard var image = UIImage(data: data) else { return nil }
                
                if let targetSize = targetSize {
                    image = image.resized(to: targetSize) ?? image
                }
                
                setImage(image, for: urlString)
                downloadTasks.removeValue(forKey: urlString)
                return image
            } catch {
                downloadTasks.removeValue(forKey: urlString)
                return nil
            }
        }
        
        downloadTasks[urlString] = task
        return await task.value
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
}

class FavoritesManager {
    static let shared = FavoritesManager()
    private init() {}
    
    private let key = "FavoriteCats"
    private let defaults = UserDefaults.standard
    
    func addFavorite(_ cat: Cat) {
        var favorites = getFavorites()
        if !favorites.contains(where: { $0.id == cat.id }) {
            favorites.append(cat)
            saveFavorites(favorites)
        }
    }
    
    func removeFavorite(_ cat: Cat) {
        var favorites = getFavorites()
        favorites.removeAll { $0.id == cat.id }
        saveFavorites(favorites)
    }
    
    func isFavorite(_ cat: Cat) -> Bool {
        return getFavorites().contains { $0.id == cat.id }
    }
    
    func getFavorites() -> [Cat] {
        guard let data = defaults.data(forKey: key),
              let cats = try? JSONDecoder().decode([Cat].self, from: data) else {
            return []
        }
        return cats
    }
    
    private func saveFavorites(_ cats: [Cat]) {
        if let data = try? JSONEncoder().encode(cats) {
            defaults.set(data, forKey: key)
        }
    }
}

class SettingsManager {
    static let shared = SettingsManager()
    private init() {}
    
    private let defaults = UserDefaults.standard
    
    var gridColumns: Int {
        get { defaults.integer(forKey: "GridColumns") != 0 ? defaults.integer(forKey: "GridColumns") : 2 }
        set { defaults.set(newValue, forKey: "GridColumns") }
    }
    
    var useHighQuality: Bool {
        get { defaults.bool(forKey: "UseHighQuality") }
        set { defaults.set(newValue, forKey: "UseHighQuality") }
    }
}

// MARK: - VIPER Module: CatsList

// MARK: CatsList Protocols

protocol CatsListViewProtocol: AnyObject {
    func showCats(_ cats: [Cat])
    func showLoading()
    func hideLoading()
    func showError(_ message: String)
    func showEmptyState()
    func hideEmptyState()
    func reloadData()
    func showFilterOptions(breeds: [Breed], selectedBreed: Breed?)
}

protocol CatsListPresenterProtocol: AnyObject {
    var view: CatsListViewProtocol? { get set }
    var interactor: CatsListInteractorInputProtocol? { get set }
    var router: CatsListRouterProtocol? { get set }
    
    func viewDidLoad()
    func refreshRequested()
    func loadMoreCats()
    func didSelectCat(_ cat: Cat)
    func toggleFavorite(_ cat: Cat)
    func filterButtonTapped()
    func applyFilter(breed: Breed?, category: Category?)
    func searchTextChanged(_ text: String)
}

protocol CatsListInteractorInputProtocol: AnyObject {
    var presenter: CatsListInteractorOutputProtocol? { get set }
    
    func fetchInitialData()
    func fetchMoreCats()
    func refreshCats()
    func toggleFavorite(_ cat: Cat)
    func applyFilter(breed: Breed?, category: Category?)
    func getBreeds() -> [Breed]
    func getCategories() -> [Category]
}

protocol CatsListInteractorOutputProtocol: AnyObject {
    func didFetchCats(_ cats: [Cat])
    func didFetchMoreCats(_ cats: [Cat])
    func didFailWithError(_ error: Error)
    func didToggleFavorite()
    func didLoadMetadata(breeds: [Breed], categories: [Category])
}

protocol CatsListRouterProtocol: AnyObject {
    static func createModule() -> UIViewController
    func navigateToCatDetail(from view: CatsListViewProtocol?, with cat: Cat)
}

// MARK: CatsList View

class CatsListView: UIViewController {
    var presenter: CatsListPresenterProtocol?
    
    private var collectionView: UICollectionView!
    private let refreshControl = UIRefreshControl()
    private let searchController = UISearchController(searchResultsController: nil)
    private var cats: [Cat] = []
    
    private lazy var emptyStateView: UIView = {
        let view = UIView()
        let label = UILabel()
        label.text = "No cats found"
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        view.isHidden = true
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionView()
        setupSearchController()
        presenter?.viewDidLoad()
    }
    
    private func setupUI() {
        title = "Cats"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
            style: .plain,
            target: self,
            action: #selector(filterButtonTapped)
        )
    }
    
    private func setupCollectionView() {
        let columns = CGFloat(SettingsManager.shared.gridColumns)
        let spacing: CGFloat = 8
        let availableWidth = view.bounds.width - (spacing * (columns + 1))
        let itemWidth = availableWidth / columns
        
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: itemWidth, height: itemWidth)
        layout.minimumInteritemSpacing = spacing
        layout.minimumLineSpacing = spacing
        layout.sectionInset = UIEdgeInsets(top: spacing, left: spacing, bottom: spacing, right: spacing)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(CatCollectionViewCell.self, forCellWithReuseIdentifier: CatCollectionViewCell.identifier)
        collectionView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        
        view.addSubview(collectionView)
        view.addSubview(emptyStateView)
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            emptyStateView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search breeds..."
        navigationItem.searchController = searchController
        definesPresentationContext = true
    }
    
    @objc private func handleRefresh() {
        presenter?.refreshRequested()
    }
    
    @objc private func filterButtonTapped() {
        presenter?.filterButtonTapped()
    }
}

extension CatsListView: CatsListViewProtocol {
    func showCats(_ cats: [Cat]) {
        self.cats = cats
        reloadData()
    }
    
    func showLoading() {
        if !refreshControl.isRefreshing {
            refreshControl.beginRefreshing()
        }
    }
    
    func hideLoading() {
        refreshControl.endRefreshing()
    }
    
    func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    func showEmptyState() {
        emptyStateView.isHidden = false
    }
    
    func hideEmptyState() {
        emptyStateView.isHidden = true
    }
    
    func reloadData() {
        collectionView.reloadData()
        emptyStateView.isHidden = !cats.isEmpty
    }
    
    func showFilterOptions(breeds: [Breed], selectedBreed: Breed?) {
        let alert = UIAlertController(title: "Filters", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "All Cats", style: .default) { [weak self] _ in
            self?.presenter?.applyFilter(breed: nil, category: nil)
        })
        
        for breed in breeds.prefix(10) {
            alert.addAction(UIAlertAction(title: breed.name, style: .default) { [weak self] _ in
                self?.presenter?.applyFilter(breed: breed, category: nil)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

extension CatsListView: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return cats.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CatCollectionViewCell.identifier, for: indexPath) as! CatCollectionViewCell
        let cat = cats[indexPath.item]
        cell.configure(with: cat)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cat = cats[indexPath.item]
        presenter?.didSelectCat(cat)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if indexPath.item == cats.count - 5 {
            presenter?.loadMoreCats()
        }
    }
}

extension CatsListView: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard let text = searchController.searchBar.text else { return }
        presenter?.searchTextChanged(text)
    }
}

// MARK: CatsList Presenter

class CatsListPresenter: CatsListPresenterProtocol {
    weak var view: CatsListViewProtocol?
    var interactor: CatsListInteractorInputProtocol?
    var router: CatsListRouterProtocol?
    
    private var cats: [Cat] = []
    private var breeds: [Breed] = []
    private var categories: [Category] = []
    
    func viewDidLoad() {
        view?.showLoading()
        interactor?.fetchInitialData()
    }
    
    func refreshRequested() {
        interactor?.refreshCats()
    }
    
    func loadMoreCats() {
        interactor?.fetchMoreCats()
    }
    
    func didSelectCat(_ cat: Cat) {
        router?.navigateToCatDetail(from: view, with: cat)
    }
    
    func toggleFavorite(_ cat: Cat) {
        interactor?.toggleFavorite(cat)
    }
    
    func filterButtonTapped() {
        guard let breeds = interactor?.getBreeds() else { return }
        view?.showFilterOptions(breeds: breeds, selectedBreed: nil)
    }
    
    func applyFilter(breed: Breed?, category: Category?) {
        view?.showLoading()
        interactor?.applyFilter(breed: breed, category: category)
    }
    
    func searchTextChanged(_ text: String) {
        // Implementar busca se necessário
    }
}

extension CatsListPresenter: CatsListInteractorOutputProtocol {
    func didFetchCats(_ cats: [Cat]) {
        self.cats = cats
        view?.hideLoading()
        view?.showCats(cats)
        
        if cats.isEmpty {
            view?.showEmptyState()
        } else {
            view?.hideEmptyState()
        }
    }
    
    func didFetchMoreCats(_ cats: [Cat]) {
        self.cats.append(contentsOf: cats)
        view?.showCats(self.cats)
    }
    
    func didFailWithError(_ error: Error) {
        view?.hideLoading()
        view?.showError(error.localizedDescription)
    }
    
    func didToggleFavorite() {
        view?.reloadData()
    }
    
    func didLoadMetadata(breeds: [Breed], categories: [Category]) {
        self.breeds = breeds
        self.categories = categories
    }
}

// MARK: CatsList Interactor

class CatsListInteractor: CatsListInteractorInputProtocol {
    weak var presenter: CatsListInteractorOutputProtocol?
    
    private let catService: CatService
    private let favoritesManager: FavoritesManager
    private var currentPage = 0
    private let pageSize = 20
    private var selectedBreed: Breed?
    private var selectedCategory: Category?
    private var breeds: [Breed] = []
    private var categories: [Category] = []
    private var allCats: [Cat] = []
    
    init(catService: CatService = CatService(), favoritesManager: FavoritesManager = .shared) {
        self.catService = catService
        self.favoritesManager = favoritesManager
    }
    
    func fetchInitialData() {
        Task {
            await loadBreeds()
            await loadCategories()
            await loadCats(refresh: true)
            
            await MainActor.run {
                presenter?.didLoadMetadata(breeds: breeds, categories: categories)
            }
        }
    }
    
    func fetchMoreCats() {
        Task {
            await loadCats(refresh: false)
        }
    }
    
    func refreshCats() {
        Task {
            await loadCats(refresh: true)
        }
    }
    
    func toggleFavorite(_ cat: Cat) {
        if favoritesManager.isFavorite(cat) {
            favoritesManager.removeFavorite(cat)
        } else {
            favoritesManager.addFavorite(cat)
        }
        
        if let index = allCats.firstIndex(where: { $0.id == cat.id }) {
            allCats[index].isFavorite = favoritesManager.isFavorite(cat)
        }
        
        presenter?.didToggleFavorite()
    }
    
    func applyFilter(breed: Breed?, category: Category?) {
        selectedBreed = breed
        selectedCategory = category
        Task {
            await loadCats(refresh: true)
        }
    }
    
    func getBreeds() -> [Breed] {
        return breeds
    }
    
    func getCategories() -> [Category] {
        return categories
    }
    
    private func loadBreeds() async {
        let result = await catService.getBreeds()
        if case .success(let fetchedBreeds) = result {
            breeds = fetchedBreeds
        }
    }
    
    private func loadCategories() async {
        let result = await catService.getCategories()
        if case .success(let fetchedCategories) = result {
            categories = fetchedCategories
        }
    }
    
    private func loadCats(refresh: Bool) async {
        if refresh {
            currentPage = 0
            allCats = []
        }
        
        let result = await catService.getRandomCats(
            limit: pageSize,
            breedId: selectedBreed?.id,
            categoryId: selectedCategory?.id
        )
        
        await MainActor.run {
            switch result {
            case .success(let newCats):
                var updatedCats = newCats
                for i in updatedCats.indices {
                    updatedCats[i].isFavorite = favoritesManager.isFavorite(updatedCats[i])
                }
                
                if refresh {
                    allCats = updatedCats
                    presenter?.didFetchCats(updatedCats)
                } else {
                    allCats.append(contentsOf: updatedCats)
                    presenter?.didFetchMoreCats(updatedCats)
                }
                currentPage += 1
                
            case .failure(let error):
                presenter?.didFailWithError(error)
            }
        }
    }
}

// MARK: CatsList Router

class CatsListRouter: CatsListRouterProtocol {
    weak var viewController: UIViewController?
    
    static func createModule() -> UIViewController {
        let view = CatsListView()
        let presenter = CatsListPresenter()
        let interactor = CatsListInteractor()
        let router = CatsListRouter()
        
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.router = router
        interactor.presenter = presenter
        router.viewController = view
        
        return view
    }
    
    func navigateToCatDetail(from view: CatsListViewProtocol?, with cat: Cat) {
        let detailVC = CatDetailRouter.createModule(with: cat)
        guard let sourceVC = viewController else { return }
        sourceVC.navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - VIPER Module: CatDetail

// MARK: CatDetail Protocols

protocol CatDetailViewProtocol: AnyObject {
    func displayCatDetails(_ cat: Cat, isFavorite: Bool)
    func updateFavoriteStatus(_ isFavorite: Bool)
    func displayImage(_ image: UIImage)
}

protocol CatDetailPresenterProtocol: AnyObject {
    var view: CatDetailViewProtocol? { get set }
    var interactor: CatDetailInteractorInputProtocol? { get set }
    var router: CatDetailRouterProtocol? { get set }
    
    func viewDidLoad()
    func toggleFavorite()
    func shareImage(_ image: UIImage)
}

protocol CatDetailInteractorInputProtocol: AnyObject {
    var presenter: CatDetailInteractorOutputProtocol? { get set }
    
    func loadCatDetails()
    func loadImage()
    func toggleFavorite()
    func isFavorite() -> Bool
}

protocol CatDetailInteractorOutputProtocol: AnyObject {
    func didLoadCatDetails(_ cat: Cat, isFavorite: Bool)
    func didLoadImage(_ image: UIImage)
    func didToggleFavorite(_ isFavorite: Bool)
}

protocol CatDetailRouterProtocol: AnyObject {
    static func createModule(with cat: Cat) -> UIViewController
    func shareImage(_ image: UIImage, from view: CatDetailViewProtocol?)
}

// MARK: CatDetail View

class CatDetailView: UIViewController {
    var presenter: CatDetailPresenterProtocol?
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let imageView = UIImageView()
    private let detailsLabel = UILabel()
    private let favoriteButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter?.viewDidLoad()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(imageView)
        contentView.addSubview(detailsLabel)
        contentView.addSubview(favoriteButton)
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        detailsLabel.translatesAutoresizingMaskIntoConstraints = false
        favoriteButton.translatesAutoresizingMaskIntoConstraints = false
        
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .systemGray6
        imageView.layer.cornerRadius = 12
        imageView.clipsToBounds = true
        
        detailsLabel.numberOfLines = 0
        detailsLabel.font = .systemFont(ofSize: 16)
        
        favoriteButton.addTarget(self, action: #selector(toggleFavorite), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            imageView.heightAnchor.constraint(equalToConstant: 300),
            
            favoriteButton.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 16),
            favoriteButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            favoriteButton.heightAnchor.constraint(equalToConstant: 44),
            
            detailsLabel.topAnchor.constraint(equalTo: favoriteButton.bottomAnchor, constant: 16),
            detailsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            detailsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            detailsLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareImage))
    }
    
    @objc private func toggleFavorite() {
        presenter?.toggleFavorite()
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    @objc private func shareImage() {
        guard let image = imageView.image else { return }
        presenter?.shareImage(image)
    }
}

extension CatDetailView: CatDetailViewProtocol {
    func displayCatDetails(_ cat: Cat, isFavorite: Bool) {
        title = cat.breeds?.first?.name ?? "Cat Details"
        
        if let breed = cat.breeds?.first {
            var text = "Breed: \(breed.name)\n\n"
            
            if let desc = breed.description {
                text += "\(desc)\n\n"
            }
            if let temperament = breed.temperament {
                text += "Temperament: \(temperament)\n\n"
            }
            if let origin = breed.origin {
                text += "Origin: \(origin)\n\n"
            }
            if let lifeSpan = breed.life_span {
                text += "Life Span: \(lifeSpan) years\n"
            }
            if let weight = breed.weight {
                text += "Weight: \(weight.metric) kg\n"
            }
            if let energyLevel = breed.energy_level {
                text += "Energy Level: \(energyLevel)/5\n"
            }
            
            detailsLabel.text = text
        } else {
            detailsLabel.text = "No breed information available"
        }
        
        updateFavoriteStatus(isFavorite)
    }
    
    func updateFavoriteStatus(_ isFavorite: Bool) {
        let icon = isFavorite ? "heart.fill" : "heart"
        let title = isFavorite ? "Remove from Favorites" : "Add to Favorites"
        favoriteButton.setImage(UIImage(systemName: icon), for: .normal)
        favoriteButton.setTitle(title, for: .normal)
        favoriteButton.tintColor = isFavorite ? .systemRed : .systemBlue
    }
    
    func displayImage(_ image: UIImage) {
        imageView.image = image
    }
}

// MARK: CatDetail Presenter

class CatDetailPresenter: CatDetailPresenterProtocol {
    weak var view: CatDetailViewProtocol?
    var interactor: CatDetailInteractorInputProtocol?
    var router: CatDetailRouterProtocol?
    
    func viewDidLoad() {
        interactor?.loadCatDetails()
        interactor?.loadImage()
    }
    
    func toggleFavorite() {
        interactor?.toggleFavorite()
    }
    
    func shareImage(_ image: UIImage) {
        router?.shareImage(image, from: view)
    }
}

extension CatDetailPresenter: CatDetailInteractorOutputProtocol {
    func didLoadCatDetails(_ cat: Cat, isFavorite: Bool) {
        view?.displayCatDetails(cat, isFavorite: isFavorite)
    }
    
    func didLoadImage(_ image: UIImage) {
        view?.displayImage(image)
    }
    
    func didToggleFavorite(_ isFavorite: Bool) {
        view?.updateFavoriteStatus(isFavorite)
    }
}

// MARK: CatDetail Interactor

class CatDetailInteractor: CatDetailInteractorInputProtocol {
    weak var presenter: CatDetailInteractorOutputProtocol?
    
    private let cat: Cat
    private let favoritesManager: FavoritesManager
    private let imageCache: ImageCache
    
    init(cat: Cat, favoritesManager: FavoritesManager = .shared, imageCache: ImageCache = .shared) {
        self.cat = cat
        self.favoritesManager = favoritesManager
        self.imageCache = imageCache
    }
    
    func loadCatDetails() {
        let isFav = favoritesManager.isFavorite(cat)
        presenter?.didLoadCatDetails(cat, isFavorite: isFav)
    }
    
    func loadImage() {
        Task {
            if let image = await imageCache.downloadImage(from: cat.url) {
                await MainActor.run {
                    presenter?.didLoadImage(image)
                }
            }
        }
    }
    
    func toggleFavorite() {
        if favoritesManager.isFavorite(cat) {
            favoritesManager.removeFavorite(cat)
        } else {
            favoritesManager.addFavorite(cat)
        }
        
        let isFav = favoritesManager.isFavorite(cat)
        presenter?.didToggleFavorite(isFav)
    }
    
    func isFavorite() -> Bool {
        return favoritesManager.isFavorite(cat)
    }
}

// MARK: CatDetail Router

class CatDetailRouter: CatDetailRouterProtocol {
    weak var viewController: UIViewController?
    
    static func createModule(with cat: Cat) -> UIViewController {
        let view = CatDetailView()
        let presenter = CatDetailPresenter()
        let interactor = CatDetailInteractor(cat: cat)
        let router = CatDetailRouter()
        
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.router = router
        interactor.presenter = presenter
        router.viewController = view
        
        return view
    }
    
    func shareImage(_ image: UIImage, from view: CatDetailViewProtocol?) {
        guard let sourceVC = viewController else { return }
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        sourceVC.present(activityVC, animated: true)
    }
}

// MARK: - VIPER Module: Favorites

// MARK: Favorites Protocols

protocol FavoritesViewProtocol: AnyObject {
    func showFavorites(_ cats: [Cat])
    func showEmptyState()
    func hideEmptyState()
    func reloadData()
}

protocol FavoritesPresenterProtocol: AnyObject {
    var view: FavoritesViewProtocol? { get set }
    var interactor: FavoritesInteractorInputProtocol? { get set }
    var router: FavoritesRouterProtocol? { get set }
    
    func viewWillAppear()
    func didSelectCat(_ cat: Cat)
    func clearAllFavorites()
    func removeFavorite(_ cat: Cat)
}

protocol FavoritesInteractorInputProtocol: AnyObject {
    var presenter: FavoritesInteractorOutputProtocol? { get set }
    
    func fetchFavorites()
    func clearAllFavorites()
    func removeFavorite(_ cat: Cat)
}

protocol FavoritesInteractorOutputProtocol: AnyObject {
    func didFetchFavorites(_ cats: [Cat])
    func didClearFavorites()
}

protocol FavoritesRouterProtocol: AnyObject {
    static func createModule() -> UIViewController
    func navigateToCatDetail(from view: FavoritesViewProtocol?, with cat: Cat)
}

// MARK: Favorites View

class FavoritesView: UIViewController {
    var presenter: FavoritesPresenterProtocol?
    
    private var favorites: [Cat] = []
    private var collectionView: UICollectionView!
    
    private lazy var emptyStateView: UIView = {
        let view = UIView()
        let label = UILabel()
        label.text = "No favorites yet\nStart adding cats you love!"
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
        view.isHidden = true
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presenter?.viewWillAppear()
    }
    
    private func setupUI() {
        title = "Favorites"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Clear All",
            style: .plain,
            target: self,
            action: #selector(clearAllFavorites)
        )
    }
    
    private func setupCollectionView() {
        let columns = CGFloat(SettingsManager.shared.gridColumns)
        let spacing: CGFloat = 8
        let availableWidth = view.bounds.width - (spacing * (columns + 1))
        let itemWidth = availableWidth / columns
        
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: itemWidth, height: itemWidth)
        layout.minimumInteritemSpacing = spacing
        layout.minimumLineSpacing = spacing
        layout.sectionInset = UIEdgeInsets(top: spacing, left: spacing, bottom: spacing, right: spacing)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(CatCollectionViewCell.self, forCellWithReuseIdentifier: CatCollectionViewCell.identifier)
        
        view.addSubview(collectionView)
        view.addSubview(emptyStateView)
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            emptyStateView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    @objc private func clearAllFavorites() {
        let alert = UIAlertController(title: "Clear All Favorites?", message: "This action cannot be undone.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            self?.presenter?.clearAllFavorites()
        })
        present(alert, animated: true)
    }
}

extension FavoritesView: FavoritesViewProtocol {
    func showFavorites(_ cats: [Cat]) {
        self.favorites = cats
        reloadData()
    }
    
    func showEmptyState() {
        emptyStateView.isHidden = false
        navigationItem.rightBarButtonItem?.isEnabled = false
    }
    
    func hideEmptyState() {
        emptyStateView.isHidden = true
        navigationItem.rightBarButtonItem?.isEnabled = true
    }
    
    func reloadData() {
        collectionView.reloadData()
        if favorites.isEmpty {
            showEmptyState()
        } else {
            hideEmptyState()
        }
    }
}

extension FavoritesView: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return favorites.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CatCollectionViewCell.identifier, for: indexPath) as! CatCollectionViewCell
        var cat = favorites[indexPath.item]
        cat.isFavorite = true
        cell.configure(with: cat)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cat = favorites[indexPath.item]
        presenter?.didSelectCat(cat)
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let removeAction = UIAction(title: "Remove from Favorites", image: UIImage(systemName: "heart.slash"), attributes: .destructive) { _ in
                guard let self = self else { return }
                let cat = self.favorites[indexPath.item]
                self.presenter?.removeFavorite(cat)
            }
            return UIMenu(children: [removeAction])
        }
    }
}

// MARK: Favorites Presenter

class FavoritesPresenter: FavoritesPresenterProtocol {
    weak var view: FavoritesViewProtocol?
    var interactor: FavoritesInteractorInputProtocol?
    var router: FavoritesRouterProtocol?
    
    func viewWillAppear() {
        interactor?.fetchFavorites()
    }
    
    func didSelectCat(_ cat: Cat) {
        router?.navigateToCatDetail(from: view, with: cat)
    }
    
    func clearAllFavorites() {
        interactor?.clearAllFavorites()
    }
    
    func removeFavorite(_ cat: Cat) {
        interactor?.removeFavorite(cat)
    }
}

extension FavoritesPresenter: FavoritesInteractorOutputProtocol {
    func didFetchFavorites(_ cats: [Cat]) {
        view?.showFavorites(cats)
    }
    
    func didClearFavorites() {
        view?.showFavorites([])
    }
}

// MARK: Favorites Interactor

class FavoritesInteractor: FavoritesInteractorInputProtocol {
    weak var presenter: FavoritesInteractorOutputProtocol?
    
    private let favoritesManager: FavoritesManager
    
    init(favoritesManager: FavoritesManager = .shared) {
        self.favoritesManager = favoritesManager
    }
    
    func fetchFavorites() {
        let favorites = favoritesManager.getFavorites()
        presenter?.didFetchFavorites(favorites)
    }
    
    func clearAllFavorites() {
        let favorites = favoritesManager.getFavorites()
        for cat in favorites {
            favoritesManager.removeFavorite(cat)
        }
        presenter?.didClearFavorites()
    }
    
    func removeFavorite(_ cat: Cat) {
        favoritesManager.removeFavorite(cat)
        fetchFavorites()
    }
}

// MARK: Favorites Router

class FavoritesRouter: FavoritesRouterProtocol {
    weak var viewController: UIViewController?
    
    static func createModule() -> UIViewController {
        let view = FavoritesView()
        let presenter = FavoritesPresenter()
        let interactor = FavoritesInteractor()
        let router = FavoritesRouter()
        
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.router = router
        interactor.presenter = presenter
        router.viewController = view
        
        return view
    }
    
    func navigateToCatDetail(from view: FavoritesViewProtocol?, with cat: Cat) {
        let detailVC = CatDetailRouter.createModule(with: cat)
        guard let sourceVC = viewController else { return }
        sourceVC.navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - VIPER Module: Settings

// MARK: Settings Protocols

protocol SettingsViewProtocol: AnyObject {
    func displaySettings(gridColumns: Int, useHighQuality: Bool)
    func showGridColumnsOptions(_ currentColumns: Int)
    func showClearCacheConfirmation()
    func showRestartRequiredAlert()
    func showCacheClearedAlert()
}

protocol SettingsPresenterProtocol: AnyObject {
    var view: SettingsViewProtocol? { get set }
    var interactor: SettingsInteractorInputProtocol? { get set }
    var router: SettingsRouterProtocol? { get set }
    
    func viewDidLoad()
    func gridColumnsSelected()
    func updateGridColumns(_ columns: Int)
    func highQualityToggled(_ isOn: Bool)
    func clearCacheSelected()
    func confirmClearCache()
}

protocol SettingsInteractorInputProtocol: AnyObject {
    var presenter: SettingsInteractorOutputProtocol? { get set }
    
    func loadSettings()
    func updateGridColumns(_ columns: Int)
    func updateHighQuality(_ isOn: Bool)
    func clearImageCache()
    func getGridColumns() -> Int
}

protocol SettingsInteractorOutputProtocol: AnyObject {
    func didLoadSettings(gridColumns: Int, useHighQuality: Bool)
    func didClearCache()
}

protocol SettingsRouterProtocol: AnyObject {
    static func createModule() -> UIViewController
}

// MARK: Settings View

class SettingsView: UIViewController {
    var presenter: SettingsPresenterProtocol?
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var gridColumns: Int = 2
    private var useHighQuality: Bool = false
    
    private enum Section: Int, CaseIterable {
        case display
        case cache
        
        var title: String {
            switch self {
            case .display: return "Display"
            case .cache: return "Cache"
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter?.viewDidLoad()
    }
    
    private func setupUI() {
        title = "Settings"
        view.backgroundColor = .systemBackground
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingsCell")
        tableView.register(SwitchTableViewCell.self, forCellReuseIdentifier: "SwitchCell")
        
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

extension SettingsView: SettingsViewProtocol {
    func displaySettings(gridColumns: Int, useHighQuality: Bool) {
        self.gridColumns = gridColumns
        self.useHighQuality = useHighQuality
        tableView.reloadData()
    }
    
    func showGridColumnsOptions(_ currentColumns: Int) {
        let alert = UIAlertController(title: "Grid Columns", message: "Select number of columns", preferredStyle: .actionSheet)
        
        for i in 2...4 {
            let action = UIAlertAction(title: "\(i) Columns", style: .default) { [weak self] _ in
                self?.presenter?.updateGridColumns(i)
            }
            if i == currentColumns {
                action.setValue(true, forKey: "checked")
            }
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    func showClearCacheConfirmation() {
        let alert = UIAlertController(title: "Clear Cache?", message: "This will free up storage space", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            self?.presenter?.confirmClearCache()
        })
        present(alert, animated: true)
    }
    
    func showRestartRequiredAlert() {
        let alert = UIAlertController(title: "Restart Required", message: "Please restart the app to apply changes", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    func showCacheClearedAlert() {
        let alert = UIAlertController(title: "Cache Cleared", message: "Image cache has been cleared successfully", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension SettingsView: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        switch section {
        case .display: return 2
        case .cache: return 1
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Section(rawValue: section)?.title
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }
        
        switch section {
        case .display:
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)
                cell.textLabel?.text = "Grid Columns"
                cell.accessoryType = .disclosureIndicator
                cell.detailTextLabel?.text = "\(gridColumns)"
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! SwitchTableViewCell
                cell.configure(title: "High Quality Images", isOn: useHighQuality) { [weak self] isOn in
                    self?.presenter?.highQualityToggled(isOn)
                }
                return cell
            }
        case .cache:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)
            cell.textLabel?.text = "Clear Image Cache"
            cell.textLabel?.textColor = .systemRed
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let section = Section(rawValue: indexPath.section) else { return }
        
        switch section {
        case .display:
            if indexPath.row == 0 {
                presenter?.gridColumnsSelected()
            }
        case .cache:
            presenter?.clearCacheSelected()
        }
    }
}

// MARK: Settings Presenter

class SettingsPresenter: SettingsPresenterProtocol {
    weak var view: SettingsViewProtocol?
    var interactor: SettingsInteractorInputProtocol?
    var router: SettingsRouterProtocol?
    
    func viewDidLoad() {
        interactor?.loadSettings()
    }
    
    func gridColumnsSelected() {
        guard let columns = interactor?.getGridColumns() else { return }
        view?.showGridColumnsOptions(columns)
    }
    
    func updateGridColumns(_ columns: Int) {
        interactor?.updateGridColumns(columns)
        view?.showRestartRequiredAlert()
    }
    
    func highQualityToggled(_ isOn: Bool) {
        interactor?.updateHighQuality(isOn)
    }
    
    func clearCacheSelected() {
        view?.showClearCacheConfirmation()
    }
    
    func confirmClearCache() {
        interactor?.clearImageCache()
    }
}

extension SettingsPresenter: SettingsInteractorOutputProtocol {
    func didLoadSettings(gridColumns: Int, useHighQuality: Bool) {
        view?.displaySettings(gridColumns: gridColumns, useHighQuality: useHighQuality)
    }
    
    func didClearCache() {
        view?.showCacheClearedAlert()
    }
}

// MARK: Settings Interactor

class SettingsInteractor: SettingsInteractorInputProtocol {
    weak var presenter: SettingsInteractorOutputProtocol?
    
    private let settingsManager: SettingsManager
    private let imageCache: ImageCache
    
    init(settingsManager: SettingsManager = .shared, imageCache: ImageCache = .shared) {
        self.settingsManager = settingsManager
        self.imageCache = imageCache
    }
    
    func loadSettings() {
        let gridColumns = settingsManager.gridColumns
        let useHighQuality = settingsManager.useHighQuality
        presenter?.didLoadSettings(gridColumns: gridColumns, useHighQuality: useHighQuality)
    }
    
    func updateGridColumns(_ columns: Int) {
        settingsManager.gridColumns = columns
        loadSettings()
    }
    
    func updateHighQuality(_ isOn: Bool) {
        settingsManager.useHighQuality = isOn
    }
    
    func clearImageCache() {
        imageCache.clearCache()
        presenter?.didClearCache()
    }
    
    func getGridColumns() -> Int {
        return settingsManager.gridColumns
    }
}

// MARK: Settings Router

class SettingsRouter: SettingsRouterProtocol {
    weak var viewController: UIViewController?
    
    static func createModule() -> UIViewController {
        let view = SettingsView()
        let presenter = SettingsPresenter()
        let interactor = SettingsInteractor()
        let router = SettingsRouter()
        
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.router = router
        interactor.presenter = presenter
        router.viewController = view
        
        return view
    }
}

// MARK: - UI Components (Mantidos da arquitetura original)

class CatCollectionViewCell: UICollectionViewCell {
    static let identifier = "CatCollectionViewCell"
    
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .systemGray6
        return iv
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    private let favoriteIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "heart.fill")
        iv.tintColor = .systemRed
        iv.isHidden = true
        return iv
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(imageView)
        contentView.addSubview(activityIndicator)
        contentView.addSubview(favoriteIcon)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        favoriteIcon.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            favoriteIcon.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            favoriteIcon.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            favoriteIcon.widthAnchor.constraint(equalToConstant: 24),
            favoriteIcon.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        contentView.layer.cornerRadius = 8
        contentView.clipsToBounds = true
    }
    
    func configure(with cat: Cat) {
        imageView.image = nil
        activityIndicator.startAnimating()
        favoriteIcon.isHidden = !cat.isFavorite
        
        Task {
            let targetSize = CGSize(width: bounds.width * 2, height: bounds.height * 2)
            if let image = await ImageCache.shared.downloadImage(from: cat.url, targetSize: targetSize) {
                await MainActor.run {
                    self.imageView.image = image
                    self.activityIndicator.stopAnimating()
                }
            } else {
                await MainActor.run {
                    self.activityIndicator.stopAnimating()
                }
            }
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        activityIndicator.stopAnimating()
        favoriteIcon.isHidden = true
    }
}

class SwitchTableViewCell: UITableViewCell {
    private let switchControl = UISwitch()
    private var switchAction: ((Bool) -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        switchControl.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
        accessoryView = switchControl
        selectionStyle = .none
    }
    
    func configure(title: String, isOn: Bool, action: @escaping (Bool) -> Void) {
        textLabel?.text = title
        switchControl.isOn = isOn
        switchAction = action
    }
    
    @objc private func switchValueChanged() {
        switchAction?(switchControl.isOn)
    }
}

// MARK: - UIImage Extension

extension UIImage {
    func resized(to targetSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

// MARK: - App Delegate & Scene Delegate

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        window = UIWindow(windowScene: windowScene)
        
        let catsListVC = CatsListRouter.createModule()
        let catsNav = UINavigationController(rootViewController: catsListVC)
        catsNav.tabBarItem = UITabBarItem(title: "Cats", image: UIImage(systemName: "cat.fill"), tag: 0)
        
        let favoritesVC = FavoritesRouter.createModule()
        let favoritesNav = UINavigationController(rootViewController: favoritesVC)
        favoritesNav.tabBarItem = UITabBarItem(title: "Favorites", image: UIImage(systemName: "heart.fill"), tag: 1)
        
        let settingsVC = SettingsRouter.createModule()
        let settingsNav = UINavigationController(rootViewController: settingsVC)
        settingsNav.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gear"), tag: 2)
        
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [catsNav, favoritesNav, settingsNav]
        
        window?.rootViewController = tabBarController
        window?.makeKeyAndVisible()
    }
}
