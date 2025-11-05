import SwiftUI
import Foundation
import Combine

// MARK: - 1. O Model (TodoItem)

/**
  Estrutura que representa uma única tarefa.
  - Identifiable: Necessário para usar em Listas do SwiftUI.
  - Codable: Necessário para serializar (salvar) e desserializar (carregar)
             o objeto usando o UserDefaults.
*/
struct TodoItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
}

// MARK: - 2. Protocolo de Repositório (TaskRepository)

/**
  Protocolo que define o contrato de gerenciamento de dados de tarefas.
  Isso abstrai a fonte de dados (UserDefaults, CoreData, Cloud, etc.)
  do ViewModel, permitindo fácil substituição.
*/
protocol TaskRepository {
    // Read: Obtém todas as tarefas.
    func fetchTasks() -> [TodoItem]
    
    // Create: Salva uma nova tarefa e retorna a lista atualizada.
    func saveTask(_ task: TodoItem)
    
    // Delete: Exclui tarefas com base em um conjunto de índices.
    func deleteTasks(at indexSet: IndexSet)
    
    // Update: Atualiza uma tarefa existente (ex: toggle completion).
    func updateTask(_ task: TodoItem)
}

// MARK: - 3. Implementação Local (LocalTaskRepository)

/**
  Implementação concreta do TaskRepository usando UserDefaults para persistência local.
*/
class LocalTaskRepository: TaskRepository {
    private let tasksKey = "todoTasks"
    private var tasks: [TodoItem] = [] // Cache interno para operações rápidas

    init() {
        // Carrega as tarefas salvas na inicialização
        loadTasks()
    }

    // MARK: - Helper de Persistência

    private func saveToUserDefaults() {
        do {
            let encodedData = try JSONEncoder().encode(tasks)
            UserDefaults.standard.set(encodedData, forKey: tasksKey)
        } catch {
            print("LocalTaskRepository: Erro ao salvar tarefas: \(error)")
        }
    }

    private func loadTasks() {
        guard
            let savedData = UserDefaults.standard.data(forKey: tasksKey),
            let loadedTasks = try? JSONDecoder().decode([TodoItem].self, from: savedData)
        else {
            return
        }
        self.tasks = loadedTasks
    }

    // MARK: - Implementação do Protocolo TaskRepository

    func fetchTasks() -> [TodoItem] {
        // Retorna o cache interno que foi carregado na inicialização
        return tasks
    }

    func saveTask(_ task: TodoItem) {
        // Adiciona ao cache (início da lista)
        tasks.insert(task, at: 0)
        // Salva a lista atualizada
        saveToUserDefaults()
    }

    func deleteTasks(at indexSet: IndexSet) {
        tasks.remove(atOffsets: indexSet)
        // Salva a lista após a exclusão
        saveToUserDefaults()
    }

    func updateTask(_ task: TodoItem) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            // Substitui a tarefa atualizada no cache
            tasks[index] = task
            // Salva a lista após a atualização
            saveToUserDefaults()
        }
    }
}

// MARK: - 4. O ViewModel Atualizado (TodoListViewModel)

/**
  A classe ViewModel que gerencia a lista de tarefas,
  usando o protocolo TaskRepository para acesso aos dados.
  Isso segue o Princípio de Inversão de Dependência.
*/
class TodoListViewModel: ObservableObject {
    // O ViewModel depende da abstração (TaskRepository), não da implementação concreta.
    private let repository: TaskRepository

    // @Published: Publica mudanças no array, notificando a View.
    @Published var todoItems: [TodoItem] = []

    /**
      Injeção de Dependência: O ViewModel recebe uma instância que
      conforma ao TaskRepository.
    */
    init(repository: TaskRepository) {
        self.repository = repository
        loadTasks()
    }

    // MARK: - Funções de Gerenciamento da Lista

    private func loadTasks() {
        // Usa o repositório para buscar as tarefas
        self.todoItems = repository.fetchTasks()
    }

    func addTask(title: String) {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let newItem = TodoItem(title: title)
        
        // Usa o repositório para salvar
        repository.saveTask(newItem)
        
        // Recarrega a lista para atualizar a View
        loadTasks()
    }

    func deleteTask(indexSet: IndexSet) {
        // Usa o repositório para excluir
        repository.deleteTasks(at: indexSet)
        
        // Recarrega a lista para atualizar a View
        loadTasks()
    }
    
    func toggleCompletion(item: TodoItem) {
        // Cria uma cópia mutável
        var updatedItem = item
        updatedItem.isCompleted.toggle()
        
        // Usa o repositório para atualizar
        repository.updateTask(updatedItem)
        
        // Recarrega a lista para atualizar a View
        loadTasks()
    }
}

// MARK: - 5. A View (ContentView) e Injeção no Ponto de Entrada

/**
  A View principal, agora instanciando e injetando a dependência.
*/
struct ContentView: View {
    // O ViewModel requer um TaskRepository no seu construtor.
    @StateObject var viewModel: TodoListViewModel

    @State private var newTaskTitle: String = ""

    var body: some View {
        NavigationView {
            VStack {
                // MARK: - Área de Adição de Nova Tarefa
                HStack {
                    TextField("Digite uma nova tarefa...", text: $newTaskTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Button(action: {
                        viewModel.addTask(title: newTaskTitle)
                        newTaskTitle = ""
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                    }
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()

                // MARK: - Lista de Tarefas
                List {
                    ForEach(viewModel.todoItems) { item in
                        HStack {
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(item.isCompleted ? .green : .gray)
                                .onTapGesture {
                                    viewModel.toggleCompletion(item: item)
                                }

                            Text(item.title)
                                .strikethrough(item.isCompleted, color: .gray)
                                .foregroundColor(item.isCompleted ? .gray : .primary)
                        }
                    }
                    // O método deleteTask do ViewModel é compatível com a assinatura de onDelete
                    .onDelete(perform: viewModel.deleteTask)
                }
                .navigationTitle("✅ Minhas Tarefas (Abstraídas)")
                .toolbar {
                    EditButton()
                }
            }
        }
    }
}

// Preview da View
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        // Cria e injeta a implementação LocalTaskRepository para o Preview
        ContentView(viewModel: TodoListViewModel(repository: LocalTaskRepository()))
    }
}

// MARK: - 6. App Entry Point com Injeção

@main
struct TodoApp: App {
    // Cria a implementação concreta (o repositório local)
    private let localRepository = LocalTaskRepository()

    var body: some Scene {
        WindowGroup {
            // Injeta a dependência no ViewModel, que é então passado para a View
            ContentView(viewModel: TodoListViewModel(repository: localRepository))
        }
    }
}
