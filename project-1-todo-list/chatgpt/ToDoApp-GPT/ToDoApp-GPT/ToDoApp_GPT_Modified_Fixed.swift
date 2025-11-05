import SwiftUI
import Foundation

// MARK: - Modelo

/// Representa uma tarefa simples.
struct TodoItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var isDone: Bool

    init(id: UUID = UUID(), title: String, isDone: Bool = false) {
        self.id = id
        self.title = title
        self.isDone = isDone
    }
}

// MARK: - Protocolo de Repositório

protocol TaskRepositoryProtocol {
    func loadAll() async -> [TodoItem]
    func saveAll(_ tasks: [TodoItem]) async -> Bool
}

// MARK: - Implementação Local (UserDefaults)

final class LocalTaskRepository: TaskRepositoryProtocol {
    private let key = "storedTasks"

    func loadAll() async -> [TodoItem] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([TodoItem].self, from: data)) ?? []
    }

    func saveAll(_ tasks: [TodoItem]) async -> Bool {
        guard let data = try? JSONEncoder().encode(tasks) else { return false }
        UserDefaults.standard.set(data, forKey: key)
        return true
    }
}

// MARK: - ViewModel

@MainActor
final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [TodoItem] = []

    private let repository: TaskRepositoryProtocol

    init(repository: TaskRepositoryProtocol = LocalTaskRepository()) {
        self.repository = repository
        Task {
            await self.loadFromRepository()
        }
    }

    func add(_ title: String) {
        let newTask = TodoItem(title: title)
        tasks.append(newTask)
        persistCurrent()
    }

    func delete(at offsets: IndexSet) {
        tasks.remove(atOffsets: offsets)
        persistCurrent()
    }

    func toggleDone(_ task: TodoItem) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isDone.toggle()
        persistCurrent()
    }

    private func persistCurrent() {
        let current = tasks
        Task {
            _ = await repository.saveAll(current)
        }
    }

    private func loadFromRepository() async {
        let loaded = await repository.loadAll()
        await MainActor.run {
            self.tasks = loaded
        }
    }
}

// MARK: - Views

struct ContentView: View {
    @EnvironmentObject private var store: TaskStore
    @State private var newTitle: String = ""

    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("Nova tarefa...", text: $newTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Button(action: {
                        guard !newTitle.isEmpty else { return }
                        store.add(newTitle)
                        newTitle = ""
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.borderless)
                }
                .padding()

                List {
                    ForEach(store.tasks) { task in
                        HStack {
                            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                .onTapGesture {
                                    store.toggleDone(task)
                                }
                            Text(task.title)
                                .strikethrough(task.isDone, color: .gray)
                                .foregroundColor(task.isDone ? .gray : .primary)
                        }
                    }
                    .onDelete(perform: store.delete)
                }
            }
            .navigationTitle("Minhas Tarefas")
        }
    }
}

// MARK: - App Entry Point

@main
struct ToDoApp: App {
    @StateObject private var store = TaskStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
