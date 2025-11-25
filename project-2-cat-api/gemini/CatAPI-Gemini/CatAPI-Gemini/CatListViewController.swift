import UIKit

// MARK: - 1. Model: CatImage (Dados)

struct CatImage: Codable {
    let id: String
    let url: String
    let width: Int
    let height: Int
    let breeds: [Breed]?

    struct Breed: Codable {
        let id: String
        let name: String
        let temperament: String
        let origin: String
    }
}

// MARK: - 2. Network Service: APIService (Lógica de Rede)

class APIService {
    static let shared = APIService()
    
    // A chave da API não é estritamente necessária para a rota /v1/images/search.
    // Substitua se necessário:
    private let apiKey = "SUA_CHAVE_API_AQUI"
    private let baseURL = "https://api.thecatapi.com/v1"
    private let session = URLSession.shared
    
    enum APIError: Error {
        case invalidURL
        case requestFailed(Error)
        case invalidResponse
        case decodingFailed(Error)
    }
    
    func fetchCatImages(limit: Int = 15, completion: @escaping (Result<[CatImage], APIError>) -> Void) {
        let endpoint = "/images/search"
        guard var urlComponents = URLComponents(string: baseURL + endpoint) else {
            completion(.failure(.invalidURL))
            return
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "mime_types", value: "jpg,png")
        ]
        
        guard let url = urlComponents.url else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.requestFailed(error)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let catImages = try decoder.decode([CatImage].self, from: data)
                completion(.success(catImages))
            } catch {
                completion(.failure(.decodingFailed(error)))
            }
        }
        
        task.resume()
    }
}

// MARK: - Extensão UIImageView (Para Carregamento Simples)

extension UIImageView {
    func load(url: URL) {
        DispatchQueue.global().async { [weak self] in
            if let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self?.image = image
                }
            } else {
                 DispatchQueue.main.async {
                    self?.image = UIImage(systemName: "photo")
                }
            }
        }
    }
}

// MARK: - 3. ViewModel: CatListViewModel (Lógica de Negócios/Estado)

class CatListViewModel {
    
    private(set) var catImages: [CatImage] = [] {
        didSet { self.didUpdateImages?() }
    }
    
    private(set) var errorMessage: String? {
        didSet { self.didEncounterError?() }
    }
    
    private(set) var isLoading: Bool = false {
        didSet { self.didChangeLoadingState?() }
    }
    
    var didUpdateImages: (() -> Void)?
    var didEncounterError: (() -> Void)?
    var didChangeLoadingState: (() -> Void)?
    
    private let apiService: APIService
    
    init(apiService: APIService = .shared) {
        self.apiService = apiService
    }
    
    func fetchImages() {
        guard !isLoading else { return }
        
        self.isLoading = true
        self.errorMessage = nil
        
        apiService.fetchCatImages(limit: 15) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let images):
                    self?.catImages = images
                    
                case .failure(let error):
                    self?.errorMessage = "Falha ao carregar gatos: \(error.localizedDescription)"
                    print("API Error: \(error)")
                }
            }
        }
    }
    
    func cellViewModel(for index: Int) -> CatImageCellViewModel? {
        guard index < catImages.count else { return nil }
        let catImage = catImages[index]
        return CatImageCellViewModel(catImage: catImage)
    }
    
    func numberOfItems() -> Int {
        return catImages.count
    }
}

struct CatImageCellViewModel {
    private let catImage: CatImage
    
    init(catImage: CatImage) {
        self.catImage = catImage
    }
    
    var imageURL: URL? {
        return URL(string: catImage.url)
    }
    
    var breedName: String {
        guard let breeds = catImage.breeds, !breeds.isEmpty else {
            return "Sem Informação de Raça"
        }
        
        if breeds.count == 1 {
            return "Raça: \(breeds[0].name)"
        } else {
            let names = breeds.map { $0.name }
            return "Raças: \(names.joined(separator: ", "))"
        }
    }
}

// MARK: - 4. View: CatImageCell (Célula Programática)

class CatImageCell: UICollectionViewCell {
    
    static let reuseIdentifier = "CatImageCell"
    
    let catImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    let breedLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .label
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupLayout() {
        contentView.addSubview(catImageView)
        contentView.addSubview(breedLabel)
        
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.2
        layer.masksToBounds = false
        
        NSLayoutConstraint.activate([
            // Configuração da Imagem
            catImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            catImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            catImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            catImageView.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.8),

            // Configuração da Label
            breedLabel.topAnchor.constraint(equalTo: catImageView.bottomAnchor, constant: 4),
            breedLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            breedLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            breedLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4)
        ])
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        catImageView.image = nil
        breedLabel.text = nil
    }
    
    func configure(with viewModel: CatImageCellViewModel) {
        breedLabel.text = viewModel.breedName
        
        if let url = viewModel.imageURL {
            catImageView.load(url: url)
        } else {
            catImageView.image = UIImage(systemName: "photo")
        }
    }
}


// MARK: - 5. View: CatListViewController (Controller Programático)

class CatListViewController: UIViewController {

    private let viewModel = CatListViewModel()
    
    // UICollectionView (Criação programática)
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.backgroundColor = .systemBackground
        
        // Registro da célula
        cv.register(CatImageCell.self, forCellWithReuseIdentifier: CatImageCell.reuseIdentifier)
        
        return cv
    }()
    
    // Activity Indicator
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    // MARK: - Ciclo de Vida
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        viewModel.fetchImages()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Cat Finder 🐈"
        
        view.addSubview(collectionView)
        view.addSubview(activityIndicator)
        
        collectionView.dataSource = self
        collectionView.delegate = self
        
        // Configuração das Constraints
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupBindings() {
        
        viewModel.didUpdateImages = { [weak self] in
            DispatchQueue.main.async {
                self?.collectionView.reloadData()
            }
        }
        
        viewModel.didChangeLoadingState = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.viewModel.isLoading {
                    self.activityIndicator.startAnimating()
                    self.collectionView.isUserInteractionEnabled = false
                } else {
                    self.activityIndicator.stopAnimating()
                    self.collectionView.isUserInteractionEnabled = true
                }
            }
        }
        
        viewModel.didEncounterError = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self, let errorMessage = self.viewModel.errorMessage else { return }
                self.showAlert(message: errorMessage)
            }
        }
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Erro", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true)
    }

}

// MARK: - UICollectionViewDataSource

extension CatListViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.numberOfItems()
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CatImageCell.reuseIdentifier, for: indexPath) as? CatImageCell else {
            return UICollectionViewCell()
        }
        
        if let cellViewModel = viewModel.cellViewModel(for: indexPath.item) {
            cell.configure(with: cellViewModel)
        }
        
        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension CatListViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let padding: CGFloat = 10
        let columns: CGFloat = 2
        
        let totalPadding = padding * (columns + 1)
        let availableWidth = collectionView.bounds.width - totalPadding
        let widthPerItem = floor(availableWidth / columns)
        
        let heightPerItem = widthPerItem * 1.3
        
        return CGSize(width: widthPerItem, height: heightPerItem)
    }
}
