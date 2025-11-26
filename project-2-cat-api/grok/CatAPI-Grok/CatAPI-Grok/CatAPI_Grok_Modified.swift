// Imports
import SwiftUI

// Entities
struct Breed: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let temperament: String
    // Additional fields can be added if needed, but these are the required ones
}

struct CatImage: Codable {
    let url: String
}

// BreedsList Module Protocols
protocol BreedsListPresenterProtocol: ObservableObject {
    var breeds: [Breed] { get }
    var isLoading: Bool { get }
    var error: String? { get }
    
    func fetchBreeds()
}

protocol BreedsListInteractorProtocol {
    func fetchBreeds()
}

protocol BreedsListRouterProtocol {
    func showBreedDetail(for breed: Breed) -> some View
}

// BreedDetail Module Protocols
protocol BreedDetailPresenterProtocol: ObservableObject {
    var breed: Breed { get }
    var imageUrl: URL? { get }
    var isLoadingImage: Bool { get }
    var error: String? { get }
    
    func fetchImage()
}

protocol BreedDetailInteractorProtocol {
    func fetchImage(for breedId: String)
}

// BreedsList Module Implementations
class BreedsListInteractor: BreedsListInteractorProtocol {
    weak var presenter: BreedsListPresenterProtocol?
    
    func fetchBreeds() {
        Task {
            do {
                let url = URL(string: "https://api.thecatapi.com/v1/breeds")!
                let (data, _) = try await URLSession.shared.data(from: url)
                let decodedBreeds = try JSONDecoder().decode([Breed].self, from: data)
                
                await MainActor.run {
                    self.presenter?.breeds = decodedBreeds
                    self.presenter?.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.presenter?.error = error.localizedDescription
                    self.presenter?.isLoading = false
                }
            }
        }
    }
}

class BreedsListPresenter: BreedsListPresenterProtocol {
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

class BreedsListRouter: BreedsListRouterProtocol {
    func showBreedDetail(for breed: Breed) -> some View {
        let interactor = BreedDetailInteractor()
        let presenter = BreedDetailPresenter(breed: breed, interactor: interactor)
        interactor.presenter = presenter
        return BreedDetailView(presenter: presenter)
    }
}

struct BreedsListView: View {
    @ObservedObject var presenter: BreedsListPresenterProtocol
    let router: BreedsListRouterProtocol
    
    @State private var showingError: Bool = false
    
    var body: some View {
        NavigationStack {
            if presenter.isLoading {
                ProgressView("Loading breeds...")
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
            Button("OK") {
                showingError = false
            }
        } message: {
            Text(presenter.error ?? "An unknown error occurred.")
        }
        .onReceive(presenter.$error) { newError in
            if newError != nil {
                showingError = true
            }
        }
    }
}

// BreedDetail Module Implementations
class BreedDetailInteractor: BreedDetailInteractorProtocol {
    weak var presenter: BreedDetailPresenterProtocol?
    
    func fetchImage(for breedId: String) {
        Task {
            do {
                let urlString = "https://api.thecatapi.com/v1/images/search?breed_ids=\(breedId)&limit=1"
                let url = URL(string: urlString)!
                let (data, _) = try await URLSession.shared.data(from: url)
                let decodedImages = try JSONDecoder().decode([CatImage].self, from: data)
                
                if let firstImage = decodedImages.first, let imageUrl = URL(string: firstImage.url) {
                    await MainActor.run {
                        self.presenter?.imageUrl = imageUrl
                        self.presenter?.isLoadingImage = false
                    }
                } else {
                    await MainActor.run {
                        self.presenter?.error = "No image found for this breed."
                        self.presenter?.isLoadingImage = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.presenter?.error = error.localizedDescription
                    self.presenter?.isLoadingImage = false
                }
            }
        }
    }
}

class BreedDetailPresenter: BreedDetailPresenterProtocol {
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

struct BreedDetailView: View {
    @ObservedObject var presenter: BreedDetailPresenterProtocol
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
            Button("OK") {
                showingError = false
            }
        } message: {
            Text(presenter.error ?? "An unknown error occurred.")
        }
        .onReceive(presenter.$error) { newError in
            if newError != nil {
                showingError = true
            }
        }
    }
}

// Module Assembly
struct CatBreedsModule {
    static func build() -> some View {
        let interactor = BreedsListInteractor()
        let presenter = BreedsListPresenter(interactor: interactor)
        interactor.presenter = presenter
        let router = BreedsListRouter()
        return BreedsListView(presenter: presenter, router: router)
    }
}

// App Entry Point
@main
struct CatApp: App {
    var body: some Scene {
        WindowGroup {
            CatBreedsModule.build()
        }
    }
}
