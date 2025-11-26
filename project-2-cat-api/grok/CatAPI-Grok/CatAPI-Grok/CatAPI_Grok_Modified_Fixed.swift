// Imports
import SwiftUI

// Entities
struct Breed: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let temperament: String
}

struct CatImage: Codable {
    let url: String
}

// MARK: - Breeds List Module

// Protocols
protocol BreedsListInteractorProtocol {
    func fetchBreeds()
}

protocol BreedsListInteractorOutput: AnyObject {
    func didFetchBreeds(_ breeds: [Breed])
    func didFailFetchingBreeds(with error: String)
}

protocol BreedsListRouterProtocol {
    func showBreedDetail(for breed: Breed) -> AnyView
}

protocol BreedDetailPresenterProtocol: ObservableObject {
    var breed: Breed { get }
    var imageUrl: URL? { get }
    var isLoadingImage: Bool { get }
    var error: String? { get }
    
    func fetchImage()
}

// Interactor
class BreedsListInteractor: BreedsListInteractorProtocol {
    weak var output: BreedsListInteractorOutput?
    
    func fetchBreeds() {
        Task {
            do {
                let url = URL(string: "https://api.thecatapi.com/v1/breeds")!
                let (data, _) = try await URLSession.shared.data(from: url)
                let decodedBreeds = try JSONDecoder().decode([Breed].self, from: data)
                
                await MainActor.run {
                    self.output?.didFetchBreeds(decodedBreeds)
                }
            } catch {
                await MainActor.run {
                    self.output?.didFailFetchingBreeds(with: error.localizedDescription)
                }
            }
        }
    }
}

// Presenter
class BreedsListPresenter: ObservableObject {
    @Published var breeds: [Breed] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    
    private let interactor: BreedsListInteractorProtocol
    
    init(interactor: BreedsListInteractorProtocol) {
        self.interactor = interactor
    }
    
    func fetchBreeds() {
        isLoading = true
        error = nil
        interactor.fetchBreeds()
    }
}

extension BreedsListPresenter: BreedsListInteractorOutput {
    func didFetchBreeds(_ breeds: [Breed]) {
        self.breeds = breeds
        isLoading = false
    }
    
    func didFailFetchingBreeds(with error: String) {
        self.error = error
        isLoading = false
    }
}

// Router
class BreedsListRouter: BreedsListRouterProtocol {
    func showBreedDetail(for breed: Breed) -> AnyView {
        let interactor = BreedDetailInteractor()
        let presenter = BreedDetailPresenter(breed: breed, interactor: interactor)
        interactor.output = presenter
        return AnyView(BreedDetailView(presenter: presenter))
    }
}

// View
struct BreedsListView: View {
    @ObservedObject var presenter: BreedsListPresenter
    let router: BreedsListRouterProtocol
    
    @State private var showingError: Bool = false
    
    var body: some View {
        NavigationView {
            if presenter.isLoading {
                ProgressView("Loading breeds...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(presenter.breeds) { breed in
                    NavigationLink(destination: router.showBreedDetail(for: breed)) {
                        Text(breed.name)
                    }
                }
                .navigationTitle("Cat Breeds")
            }
        }
        .task {
            presenter.fetchBreeds()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { showingError = false }
        } message: {
            Text(presenter.error ?? "An unknown error occurred.")
        }
        .onChange(of: presenter.error) { newError in
            if newError != nil {
                showingError = true
            }
        }
    }
}

// MARK: - Breed Detail Module

// Protocols
protocol BreedDetailInteractorProtocol {
    func fetchImage(for breedId: String)
}

protocol BreedDetailInteractorOutput: AnyObject {
    func didFetchImage(_ url: URL)
    func didFailFetchingImage(with error: String)
}

// Interactor
class BreedDetailInteractor: BreedDetailInteractorProtocol {
    weak var output: BreedDetailInteractorOutput?
    
    func fetchImage(for breedId: String) {
        Task {
            do {
                let urlString = "https://api.thecatapi.com/v1/images/search?breed_ids=\(breedId)&limit=1"
                let url = URL(string: urlString)!
                let (data, _) = try await URLSession.shared.data(from: url)
                let decodedImages = try JSONDecoder().decode([CatImage].self, from: data)
                
                if let firstImage = decodedImages.first,
                   let imageUrl = URL(string: firstImage.url) {
                    await MainActor.run {
                        self.output?.didFetchImage(imageUrl)
                    }
                } else {
                    await MainActor.run {
                        self.output?.didFailFetchingImage(with: "No image found for this breed.")
                    }
                }
            } catch {
                await MainActor.run {
                    self.output?.didFailFetchingImage(with: error.localizedDescription)
                }
            }
        }
    }
}

// Presenter
class BreedDetailPresenter: ObservableObject, BreedDetailPresenterProtocol {
    let breed: Breed
    
    @Published var imageUrl: URL? = nil
    @Published var isLoadingImage: Bool = false
    @Published var error: String? = nil
    
    private let interactor: BreedDetailInteractorProtocol
    
    init(breed: Breed, interactor: BreedDetailInteractorProtocol) {
        self.breed = breed
        self.interactor = interactor
    }
    
    func fetchImage() {
        isLoadingImage = true
        error = nil
        interactor.fetchImage(for: breed.id)
    }
}

extension BreedDetailPresenter: BreedDetailInteractorOutput {
    func didFetchImage(_ url: URL) {
        imageUrl = url
        isLoadingImage = false
    }
    
    func didFailFetchingImage(with error: String) {
        self.error = error
        isLoadingImage = false
    }
}

// View
struct BreedDetailView: View {
    @ObservedObject var presenter: BreedDetailPresenter
    
    @State private var showingError: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if presenter.isLoadingImage {
                    ProgressView("Loading image...")
                        .frame(maxWidth: .infinity)
                } else if let url = presenter.imageUrl {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Text("No image available")
                        .frame(maxWidth: .infinity)
                }
                
                Text(presenter.breed.name)
                    .font(.title)
                    .bold()
                
                Text("Description:")
                    .font(.headline)
                Text(presenter.breed.description)
                
                Text("Temperament:")
                    .font(.headline)
                Text(presenter.breed.temperament)
            }
            .padding()
        }
        .navigationTitle(presenter.breed.name)
        .task {
            presenter.fetchImage()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { showingError = false }
        } message: {
            Text(presenter.error ?? "An unknown error occurred.")
        }
        .onChange(of: presenter.error) { newError in
            if newError != nil {
                showingError = true
            }
        }
    }
}

// MARK: - Module Assembly
struct CatBreedsModule {
    static func build() -> some View {
        let interactor = BreedsListInteractor()
        let presenter = BreedsListPresenter(interactor: interactor)
        interactor.output = presenter
        let router = BreedsListRouter()
        return BreedsListView(presenter: presenter, router: router)
    }
}

// MARK: - App Entry Point
@main
struct CatApp: App {
    var body: some Scene {
        WindowGroup {
            CatBreedsModule.build()
        }
    }
}
