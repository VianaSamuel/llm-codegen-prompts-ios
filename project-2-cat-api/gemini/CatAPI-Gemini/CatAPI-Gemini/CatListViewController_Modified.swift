import UIKit

// MARK: - 0. Protocols (Contratos VIPER)

// V -> P
protocol CatListViewProtocol: AnyObject {
    var presenter: CatListPresenterProtocol? { get set }
    
    func showLoading()
    func hideLoading()
    func displayCatImages(viewModels: [CatImageCellViewModel])
    func displayError(message: String)
}

// P -> V / I / R
protocol CatListPresenterProtocol: AnyObject {
    var view: CatListViewProtocol? { get set }
    var interactor: CatListInteractorInputProtocol? { get set }
    var router: CatListRouterProtocol? { get set }
    
    func viewDidLoad()
    func interactorDidFetchCats(with result: Result<[CatImage], Error>)
}

// I -> P
protocol CatListInteractorOutputProtocol: AnyObject {
    func interactorDidFetchCats(with result: Result<[CatImage], Error>)
}

// P -> I
protocol CatListInteractorInputProtocol: AnyObject {
    var presenter: CatListInteractorOutputProtocol? { get set }
    var apiService: APIService { get }
    
    func fetchCatImages()
}

// P -> R
protocol CatListRouterProtocol: AnyObject {
    static func createCatListModule() -> UIViewController
}

// MARK: - 1. Entity & Service (Dados)

// Entity: Estrutura de dados
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

// Service: Lógica de Rede
class APIService {
    static let shared = APIService()
    
    private let apiKey = "SUA_CHAVE_API_AQUI"
    private let baseURL = "https://api.thecatapi.com/v1"
    private let session = URLSession.shared
    
    enum APIError: Error {
        case invalidURL
        case requestFailed(Error)
        case invalidResponse
        case decodingFailed(Error)
    }
    
    func fetchCatImages(limit: Int = 15, completion: @escaping (Result<[CatImage], Error>) -> Void) {
        let endpoint = "/images/search"
        guard var urlComponents = URLComponents(string: baseURL + endpoint) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "mime_types", value: "jpg,png")
        ]
        
        guard let url = urlComponents.url else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(APIError.requestFailed(error)))
                return
            }
            guard let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let catImages = try decoder.decode([CatImage].self, from: data)
                completion(.success(catImages))
            } catch {
                completion(.failure(APIError.decodingFailed(error)))
            }
        }
        task.resume()
    }
}

// MARK: - 2. Interactor (Lógica de Negócios)

class CatListInteractor: CatListInteractorInputProtocol {
    
    weak var presenter: CatListInteractorOutputProtocol?
    let apiService: APIService
    
    init(apiService: APIService = .shared) {
        self.apiService = apiService
    }
    
    func fetchCatImages() {
        apiService.fetchCatImages { [weak self] result in
            DispatchQueue.main.async {
                self?.presenter?.interactorDidFetchCats(with: result)
            }
        }
    }
}

// MARK: - 3. Presenter (Lógica de Apresentação)

class CatListPresenter: CatListPresenterProtocol, CatListInteractorOutputProtocol {
    
    weak var view: CatListViewProtocol?
    var interactor: CatListInteractorInputProtocol?
    var router: CatListRouterProtocol?
    
    func viewDidLoad() {
        view?.showLoading()
        interactor?.fetchCatImages()
    }
    
    func interactorDidFetchCats(with result: Result<[CatImage], Error>) {
        view?.hideLoading()
        
        switch result {
        case .success(let catImages):
            // Converte Entity (CatImage) em ViewModel
            let viewModels = catImages.map { CatImageCellViewModel(catImage: $0) }
            view?.displayCatImages(viewModels: viewModels)
            
        case .failure(let error):
            let message = "Falha ao carregar gatos: \(error.localizedDescription)"
            view?.displayError(message: message)
        }
    }
}

// ViewModel Específico para a Célula (Formatação de dados)
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

// MARK: - 4. Router (Montagem do Módulo)

class CatListRouter: CatListRouterProtocol {
    
    static func createCatListModule() -> UIViewController {
        
        let view = CatListViewController()
        let interactor = CatListInteractor()
        let presenter = CatListPresenter()
        let router = CatListRouter()
        
        // Conexão VIPER
        view.presenter = presenter
        
        presenter.view = view
        presenter.interactor = interactor
        presenter.router = router
        
        interactor.presenter = presenter
        
        return view
    }
}

// MARK: - 5. View (ViewController e Componentes de UI)

// Extensão de UIImageView (Utilitário de Imagem)
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

// Célula da UICollectionView
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
            catImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            catImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            catImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            catImageView.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.8),

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


// O Controller Principal (View no VIPER)
class CatListViewController: UIViewController, CatListViewProtocol {

    // Referência ao Presenter (ponto de saída da View)
    var presenter: CatListPresenterProtocol?
    private var catCellViewModels: [CatImageCellViewModel] = [] // Dados formatados para exibição

    // UI Elements (programáticos)
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.backgroundColor = .systemBackground
        cv.register(CatImageCell.self, forCellWithReuseIdentifier: CatImageCell.reuseIdentifier)
        
        return cv
    }()
    
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
        // NOTIFICAÇÃO: A View notifica o Presenter
        presenter?.viewDidLoad()
    }
    
    // MARK: - CatListViewProtocol (Métodos de Display)
    
    func showLoading() {
        DispatchQueue.main.async {
            self.activityIndicator.startAnimating()
            self.collectionView.isUserInteractionEnabled = false
        }
    }
    
    func hideLoading() {
        DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
            self.collectionView.isUserInteractionEnabled = true
        }
    }
    
    // O Presenter instrui a View a exibir estes dados
    func displayCatImages(viewModels: [CatImageCellViewModel]) {
        DispatchQueue.main.async {
            self.catCellViewModels = viewModels
            self.collectionView.reloadData()
        }
    }
    
    func displayError(message: String) {
        DispatchQueue.main.async {
            self.showAlert(message: message)
        }
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Cat Finder 🐈 (VIPER Unificado)"
        
        view.addSubview(collectionView)
        view.addSubview(activityIndicator)
        
        collectionView.dataSource = self
        collectionView.delegate = self
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
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
        return catCellViewModels.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CatImageCell.reuseIdentifier, for: indexPath) as? CatImageCell else {
            return UICollectionViewCell()
        }
        
        let cellViewModel = catCellViewModels[indexPath.item]
        cell.configure(with: cellViewModel)
        
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
