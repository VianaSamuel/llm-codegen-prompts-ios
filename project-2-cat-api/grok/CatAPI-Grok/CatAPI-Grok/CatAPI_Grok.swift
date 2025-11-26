// Imports
import SwiftUI

// Models
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

// View Models
class CatBreedsViewModel: ObservableObject {
    @Published var breeds: [Breed] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    
    func fetchBreeds() async {
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            let url = URL(string: "https://api.thecatapi.com/v1/breeds")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let decodedBreeds = try JSONDecoder().decode([Breed].self, from: data)
            
            DispatchQueue.main.async {
                self.breeds = decodedBreeds
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

class CatBreedDetailViewModel: ObservableObject {
    @Published var imageUrl: URL? = nil
    @Published var isLoadingImage: Bool = false
    @Published var error: String? = nil
    
    let breed: Breed
    
    init(breed: Breed) {
        self.breed = breed
    }
    
    func fetchImage() async {
        DispatchQueue.main.async {
            self.isLoadingImage = true
            self.error = nil
        }
        
        do {
            let urlString = "https://api.thecatapi.com/v1/images/search?breed_ids=\(breed.id)&limit=1"
            let url = URL(string: urlString)!
            let (data, _) = try await URLSession.shared.data(from: url)
            let decodedImages = try JSONDecoder().decode([CatImage].self, from: data)
            
            if let firstImage = decodedImages.first {
                DispatchQueue.main.async {
                    self.imageUrl = URL(string: firstImage.url)
                    self.isLoadingImage = false
                }
            } else {
                DispatchQueue.main.async {
                    self.error = "No image found for this breed."
                    self.isLoadingImage = false
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error.localizedDescription
                self.isLoadingImage = false
            }
        }
    }
}

// Views
struct ContentView: View {
    @StateObject private var viewModel = CatBreedsViewModel()
    @State private var showingError: Bool = false
    
    var body: some View {
        NavigationView {
            if viewModel.isLoading {
                ProgressView("Loading breeds...")
            } else {
                List(viewModel.breeds) { breed in
                    NavigationLink(destination: BreedDetailView(breed: breed)) {
                        Text(breed.name)
                    }
                }
                .navigationTitle("Cat Breeds")
            }
        }
        .task {
            await viewModel.fetchBreeds()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                showingError = false
            }
        } message: {
            Text(viewModel.error ?? "An unknown error occurred.")
        }
        .onReceive(viewModel.$error) { newError in
            if newError != nil {
                showingError = true
            }
        }
    }
}

struct BreedDetailView: View {
    let breed: Breed
    @StateObject private var viewModel: CatBreedDetailViewModel
    @State private var showingError: Bool = false
    
    init(breed: Breed) {
        self.breed = breed
        self._viewModel = StateObject(wrappedValue: CatBreedDetailViewModel(breed: breed))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isLoadingImage {
                    ProgressView("Loading image...")
                        .frame(maxWidth: .infinity)
                } else if let url = viewModel.imageUrl {
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
                
                Text(breed.name)
                    .font(.title)
                    .bold()
                
                Text("Description:")
                    .font(.headline)
                Text(breed.description)
                
                Text("Temperament:")
                    .font(.headline)
                Text(breed.temperament)
            }
            .padding()
        }
        .navigationTitle(breed.name)
        .task {
            await viewModel.fetchImage()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                showingError = false
            }
        } message: {
            Text(viewModel.error ?? "An unknown error occurred.")
        }
        .onReceive(viewModel.$error) { newError in
            if newError != nil {
                showingError = true
            }
        }
    }
}

// App Entry Point
@main
struct CatApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
