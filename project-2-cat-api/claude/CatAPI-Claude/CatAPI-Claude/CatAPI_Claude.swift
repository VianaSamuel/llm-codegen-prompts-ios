// MARK: - Models

import Foundation
import UIKit


// MARK: Cat Models
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

// MARK: - Network Layer

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

// MARK: NetworkManager
class NetworkManager {
    static let shared = NetworkManager()
    private init() {}
    
    private let baseURL = "https://api.thecatapi.com/v1"
    private let apiKey = "" // Add your API key here if needed
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
            
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw CatAPIError.decodingError(error)
            }
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

// MARK: - Services

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

// MARK: - Image Cache

class ImageCache {
    static let shared = ImageCache()
    private init() {}
    
    private let cache = NSCache<NSString, UIImage>()
    private var downloadTasks: [String: Task<UIImage?, Never>] = [:]
    
    func image(for url: String) -> UIImage? {
        return cache.object(forKey: url as NSString)
    }
    
    func setImage(_ image: UIImage, for url: String) {
        cache.object(forKey: url as NSString)
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

// MARK: - Favorites Manager

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

// MARK: - Settings Manager

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

// MARK: - ViewModels

class CatsListViewModel {
    @Published var cats: [Cat] = []
    @Published var loadingState: LoadingState = .idle
    
    private let catService: CatService
    private let favoritesManager: FavoritesManager
    private var currentPage = 0
    private let pageSize = 20
    
    var selectedBreed: Breed?
    var selectedCategory: Category?
    var breeds: [Breed] = []
    var categories: [Category] = []
    
    init(catService: CatService = CatService(), favoritesManager: FavoritesManager = .shared) {
        self.catService = catService
        self.favoritesManager = favoritesManager
    }
    
    @MainActor
    func loadInitialData() async {
        loadingState = .loading
        await loadBreeds()
        await loadCategories()
        await loadCats(refresh: true)
    }
    
    @MainActor
    private func loadBreeds() async {
        let result = await catService.getBreeds()
        if case .success(let breeds) = result {
            self.breeds = breeds
        }
    }
    
    @MainActor
    private func loadCategories() async {
        let result = await catService.getCategories()
        if case .success(let categories) = result {
            self.categories = categories
        }
    }
    
    @MainActor
    func loadCats(refresh: Bool = false) async {
        if refresh {
            currentPage = 0
            cats = []
        }
        
        loadingState = .loading
        
        let result = await catService.getRandomCats(
            limit: pageSize,
            breedId: selectedBreed?.id,
            categoryId: selectedCategory?.id
        )
        
        switch result {
        case .success(let newCats):
            var updatedCats = newCats
            for i in updatedCats.indices {
                updatedCats[i].isFavorite = favoritesManager.isFavorite(updatedCats[i])
            }
            cats.append(contentsOf: updatedCats)
            currentPage += 1
            loadingState = .loaded
        case .failure(let error):
            loadingState = .error(error)
        }
    }
    
    func toggleFavorite(_ cat: Cat) {
        if favoritesManager.isFavorite(cat) {
            favoritesManager.removeFavorite(cat)
        } else {
            favoritesManager.addFavorite(cat)
        }
        
        if let index = cats.firstIndex(where: { $0.id == cat.id }) {
            cats[index].isFavorite = favoritesManager.isFavorite(cat)
        }
    }
}

class CatDetailViewModel {
    let cat: Cat
    @Published var isFavorite: Bool
    
    private let favoritesManager: FavoritesManager
    
    init(cat: Cat, favoritesManager: FavoritesManager = .shared) {
        self.cat = cat
        self.favoritesManager = favoritesManager
        self.isFavorite = favoritesManager.isFavorite(cat)
    }
    
    func toggleFavorite() {
        if isFavorite {
            favoritesManager.removeFavorite(cat)
        } else {
            favoritesManager.addFavorite(cat)
        }
        isFavorite = favoritesManager.isFavorite(cat)
    }
    
    func shareImage(_ image: UIImage, from viewController: UIViewController) {
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        viewController.present(activityVC, animated: true)
    }
}

// MARK: - Extensions

extension UIImage {
    func resized(to targetSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

// MARK: - Views

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

// MARK: - CatsListViewController (Part 1)
class CatsListViewController: UIViewController {
    private let viewModel = CatsListViewModel()
    private var collectionView: UICollectionView!
    private let refreshControl = UIRefreshControl()
    private let searchController = UISearchController(searchResultsController: nil)
    
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
        loadData()
    }
    
    private func setupUI() {
        title = "Cats"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal.decrease.circle"), style: .plain, target: self, action: #selector(showFilters))
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
    
    private func loadData() {
        Task {
            await viewModel.loadInitialData()
            await MainActor.run {
                collectionView.reloadData()
                updateEmptyState()
            }
        }
    }
    
    @objc private func handleRefresh() {
        Task {
            await viewModel.loadCats(refresh: true)
            await MainActor.run {
                refreshControl.endRefreshing()
                collectionView.reloadData()
                updateEmptyState()
            }
        }
    }
    
    @objc private func showFilters() {
        let alert = UIAlertController(title: "Filters", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "All Cats", style: .default) { [weak self] _ in
            self?.applyFilter(breed: nil, category: nil)
        })
        
        for breed in viewModel.breeds.prefix(10) {
            alert.addAction(UIAlertAction(title: breed.name, style: .default) { [weak self] _ in
                self?.applyFilter(breed: breed, category: nil)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func applyFilter(breed: Breed?, category: Category?) {
        viewModel.selectedBreed = breed
        viewModel.selectedCategory = category
        Task {
            await viewModel.loadCats(refresh: true)
            await MainActor.run {
                collectionView.reloadData()
                updateEmptyState()
            }
        }
    }
    
    private func updateEmptyState() {
        emptyStateView.isHidden = !viewModel.cats.isEmpty
    }
}

extension CatsListViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.cats.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CatCollectionViewCell.identifier, for: indexPath) as! CatCollectionViewCell
        let cat = viewModel.cats[indexPath.item]
        cell.configure(with: cat)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cat = viewModel.cats[indexPath.item]
        let detailVC = CatDetailViewController(cat: cat)
        navigationController?.pushViewController(detailVC, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if indexPath.item == viewModel.cats.count - 5 {
            Task {
                await viewModel.loadCats(refresh: false)
                await MainActor.run {
                    collectionView.reloadData()
                }
            }
        }
    }
}

extension CatsListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard let text = searchController.searchBar.text?.lowercased(), !text.isEmpty else {
            return
        }
    }
}

// MARK: - CatDetailViewController
class CatDetailViewController: UIViewController {
    private let viewModel: CatDetailViewModel
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let imageView = UIImageView()
    private let detailsLabel = UILabel()
    private let favoriteButton = UIButton(type: .system)
    
    init(cat: Cat) {
        self.viewModel = CatDetailViewModel(cat: cat)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadImage()
        updateFavoriteButton()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = viewModel.cat.breeds?.first?.name ?? "Cat Details"
        
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
        
        if let breed = viewModel.cat.breeds?.first {
            var text = ""
            if let name = breed.name { text += "Breed: \(name)\n\n" }
            if let desc = breed.description { text += "\(desc)\n\n" }
            if let temperament = breed.temperament { text += "Temperament: \(temperament)\n\n" }
            if let origin = breed.origin { text += "Origin: \(origin)\n\n" }
            if let lifeSpan = breed.life_span { text += "Life Span: \(lifeSpan) years\n" }
            detailsLabel.text = text
        } else {
            detailsLabel.text = "No breed information available"
        }
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareImage))
    }
    
    private func loadImage() {
        Task {
            if let image = await ImageCache.shared.downloadImage(from: viewModel.cat.url) {
                await MainActor.run {
                    self.imageView.image = image
                }
            }
        }
    }
    
    @objc private func toggleFavorite() {
        viewModel.toggleFavorite()
        updateFavoriteButton()
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func updateFavoriteButton() {
        let icon = viewModel.isFavorite ? "heart.fill" : "heart"
        let title = viewModel.isFavorite ? "Remove from Favorites" : "Add to Favorites"
        favoriteButton.setImage(UIImage(systemName: icon), for: .normal)
        favoriteButton.setTitle(title, for: .normal)
        favoriteButton.tintColor = viewModel.isFavorite ? .systemRed : .systemBlue
    }
    
    @objc private func shareImage() {
        guard let image = imageView.image else { return }
        viewModel.shareImage(image, from: self)
    }
}

// MARK: - FavoritesViewController
class FavoritesViewController: UIViewController {
    private let favoritesManager = FavoritesManager.shared
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
        loadFavorites()
    }
    
    private func setupUI() {
        title = "Favorites"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Clear All", style: .plain, target: self, action: #selector(clearAllFavorites))
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
    
    private func loadFavorites() {
        favorites = favoritesManager.getFavorites()
        collectionView.reloadData()
        updateEmptyState()
    }
    
    private func updateEmptyState() {
        emptyStateView.isHidden = !favorites.isEmpty
        navigationItem.rightBarButtonItem?.isEnabled = !favorites.isEmpty
    }
    
    @objc private func clearAllFavorites() {
        let alert = UIAlertController(title: "Clear All Favorites?", message: "This action cannot be undone.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            for cat in self.favorites {
                self.favoritesManager.removeFavorite(cat)
            }
            self.loadFavorites()
        })
        present(alert, animated: true)
    }
}

extension FavoritesViewController: UICollectionViewDataSource, UICollectionViewDelegate {
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
        let detailVC = CatDetailViewController(cat: cat)
        navigationController?.pushViewController(detailVC, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let removeAction = UIAction(title: "Remove from Favorites", image: UIImage(systemName: "heart.slash"), attributes: .destructive) { _ in
                guard let self = self else { return }
                let cat = self.favorites[indexPath.item]
                self.favoritesManager.removeFavorite(cat)
                self.loadFavorites()
            }
            return UIMenu(children: [removeAction])
        }
    }
}

// MARK: - SettingsViewController
class SettingsViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let settings = SettingsManager.shared
    
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

extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {
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
                cell.detailTextLabel?.text = "\(settings.gridColumns)"
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! SwitchTableViewCell
                cell.configure(title: "High Quality Images", isOn: settings.useHighQuality) { [weak self] isOn in
                    self?.settings.useHighQuality = isOn
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
                showGridColumnsSelector()
            }
        case .cache:
            showClearCacheConfirmation()
        }
    }
    
    private func showGridColumnsSelector() {
        let alert = UIAlertController(title: "Grid Columns", message: "Select number of columns", preferredStyle: .actionSheet)
        
        for i in 2...4 {
            let action = UIAlertAction(title: "\(i) Columns", style: .default) { [weak self] _ in
                self?.settings.gridColumns = i
                self?.tableView.reloadData()
                
                let alert = UIAlertController(title: "Restart Required", message: "Please restart the app to apply changes", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(alert, animated: true)
            }
            if i == settings.gridColumns {
                action.setValue(true, forKey: "checked")
            }
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showClearCacheConfirmation() {
        let alert = UIAlertController(title: "Clear Cache?", message: "This will free up storage space", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { _ in
            ImageCache.shared.clearCache()
            
            let successAlert = UIAlertController(title: "Cache Cleared", message: "Image cache has been cleared successfully", preferredStyle: .alert)
            successAlert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(successAlert, animated: true)
        })
        present(alert, animated: true)
    }
}

// MARK: - Custom Cells
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
        
        let catsListVC = CatsListViewController()
        let catsNav = UINavigationController(rootViewController: catsListVC)
        catsNav.tabBarItem = UITabBarItem(title: "Cats", image: UIImage(systemName: "cat.fill"), tag: 0)
        
        let favoritesVC = FavoritesViewController()
        let favoritesNav = UINavigationController(rootViewController: favoritesVC)
        favoritesNav.tabBarItem = UITabBarItem(title: "Favorites", image: UIImage(systemName: "heart.fill"), tag: 1)
        
        let settingsVC = SettingsViewController()
        let settingsNav = UINavigationController(rootViewController: settingsVC)
        settingsNav.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gear"), tag: 2)
        
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [catsNav, favoritesNav, settingsNav]
        
        window?.rootViewController = tabBarController
        window?.makeKeyAndVisible()
    }
}

// MARK: - Info.plist Configuration (Add these keys)
/*
 Required Info.plist entries:
 
 <key>NSAppTransportSecurity</key>
 <dict>
     <key>NSAllowsArbitraryLoads</key>
     <true/>
 </dict>
 
 <key>UIApplicationSceneManifest</key>
 <dict>
     <key>UIApplicationSupportsMultipleScenes</key>
     <false/>
     <key>UISceneConfigurations</key>
     <dict>
         <key>UIWindowSceneSessionRoleApplication</key>
         <array>
             <dict>
                 <key>UISceneConfigurationName</key>
                 <string>Default Configuration</string>
                 <key>UISceneDelegateClassName</key>
                 <string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
             </dict>
         </array>
     </dict>
 </dict>
 
 <key>UILaunchScreen</key>
 <dict>
     <key>UIImageName</key>
     <string>LaunchImage</string>
     <key>UIColorName</key>
     <string>LaunchColor</string>
 </dict>
 
 <key>UIUserInterfaceStyle</key>
 <string>Automatic</string>
 */

// MARK: - Unit Tests
/*
 Para criar testes unitários, adicione um novo Test Target no Xcode:
 File > New > Target > Unit Testing Bundle
 
 Exemplo de testes:
 
 import XCTest
 @testable import YourAppName
 
 class NetworkManagerTests: XCTestCase {
     func testFetchRandomCats() async throws {
         let cats = try await NetworkManager.shared.fetchRandomCats(limit: 5)
         XCTAssertGreaterThan(cats.count, 0)
     }
 }
 
 class FavoritesManagerTests: XCTestCase {
     func testAddAndRemoveFavorite() {
         let cat = Cat(id: "test1", url: "https://test.com/cat.jpg",
                      width: 300, height: 300, breeds: nil, categories: nil)
         let manager = FavoritesManager.shared
         
         manager.addFavorite(cat)
         XCTAssertTrue(manager.isFavorite(cat))
         
         manager.removeFavorite(cat)
         XCTAssertFalse(manager.isFavorite(cat))
     }
 }
 */
