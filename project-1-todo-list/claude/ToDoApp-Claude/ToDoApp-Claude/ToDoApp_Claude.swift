import SwiftUI

// MARK: - Modelo de Dados
/// Representa uma tarefa individual com identificador único
struct Task: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    let createdAt: Date
    
    init(id: UUID = UUID(), title: String, isCompleted: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}

// MARK: - Gerenciador de Persistência
/// Responsável por salvar e carregar tarefas do UserDefaults
class TaskStorageManager {
    private let userDefaultsKey = "savedTasks"
    
    /// Salva a lista de tarefas no UserDefaults
    func saveTasks(_ tasks: [Task]) {
        if let encoded = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    /// Carrega a lista de tarefas do UserDefaults
    func loadTasks() -> [Task] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([Task].self, from: data) else {
            return []
        }
        
        return decoded
    }
    
    /// Remove todas as tarefas salvas
    func clearAllTasks() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}

// MARK: - ViewModel
/// Gerencia a lógica de negócio e o estado da lista de tarefas
class TaskViewModel: ObservableObject {
    @Published var tasks: [Task] = []
    private let storageManager = TaskStorageManager()
    
    init() {
        loadTasks()
    }
    
    /// Carrega as tarefas do armazenamento local
    func loadTasks() {
        tasks = storageManager.loadTasks()
    }
    
    /// Adiciona uma nova tarefa à lista
    /// - Parameter title: Título da tarefa
    /// - Returns: true se a tarefa foi adicionada, false se o título estiver vazio
    @discardableResult
    func addTask(title: String) -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validação: impede cadastro de tarefas vazias
        guard !trimmedTitle.isEmpty else {
            return false
        }
        
        let newTask = Task(title: trimmedTitle)
        tasks.insert(newTask, at: 0) // Adiciona no início da lista
        saveTasks()
        
        return true
    }
    
    /// Remove uma tarefa da lista
    /// - Parameter task: Tarefa a ser removida
    func deleteTask(_ task: Task) {
        tasks.removeAll { $0.id == task.id }
        saveTasks()
    }
    
    /// Remove tarefas nos índices especificados
    /// - Parameter offsets: IndexSet com os índices a serem removidos
    func deleteTasks(at offsets: IndexSet) {
        tasks.remove(atOffsets: offsets)
        saveTasks()
    }
    
    /// Alterna o estado de conclusão de uma tarefa
    /// - Parameter task: Tarefa a ter seu estado alternado
    func toggleTaskCompletion(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isCompleted.toggle()
            saveTasks()
        }
    }
    
    /// Salva as tarefas no armazenamento local
    private func saveTasks() {
        storageManager.saveTasks(tasks)
    }
    
    /// Remove todas as tarefas
    func clearAllTasks() {
        tasks.removeAll()
        storageManager.clearAllTasks()
    }
}

// MARK: - View Principal
struct ContentView: View {
    @StateObject private var viewModel = TaskViewModel()
    @State private var newTaskTitle = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Campo de entrada para nova tarefa
                HStack(spacing: 12) {
                    TextField("Digite uma nova tarefa", text: $newTaskTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            addNewTask()
                        }
                    
                    Button(action: addNewTask) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(Color(.systemBackground))
                
                Divider()
                
                // Lista de tarefas
                if viewModel.tasks.isEmpty {
                    emptyStateView
                } else {
                    taskListView
                }
            }
            .navigationTitle("Minhas Tarefas")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.tasks.isEmpty {
                        Button(action: {
                            alertMessage = "Deseja realmente excluir todas as tarefas?"
                            showingAlert = true
                        }) {
                            Text("Limpar Tudo")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .alert("Confirmar Ação", isPresented: $showingAlert) {
                Button("Cancelar", role: .cancel) { }
                Button("Excluir Tudo", role: .destructive) {
                    viewModel.clearAllTasks()
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Subviews
    /// View exibida quando não há tarefas
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checklist")
                .font(.system(size: 70))
                .foregroundColor(.gray.opacity(0.5))
            Text("Nenhuma tarefa ainda")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
            Text("Adicione uma nova tarefa acima para começar")
                .font(.body)
                .foregroundColor(.gray.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// View com a lista de tarefas
    private var taskListView: some View {
        List {
            ForEach(viewModel.tasks) { task in
                TaskRowView(task: task) {
                    viewModel.toggleTaskCompletion(task)
                }
            }
            .onDelete(perform: viewModel.deleteTasks)
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - Ações
    /// Adiciona uma nova tarefa à lista
    private func addNewTask() {
        let success = viewModel.addTask(title: newTaskTitle)
        if success {
            newTaskTitle = ""
            isTextFieldFocused = false
        } else {
            // Feedback visual se tentar adicionar tarefa vazia
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
}

// MARK: - View de Linha de Tarefa
/// Representa uma linha individual na lista de tarefas
struct TaskRowView: View {
    let task: Task
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Botão de conclusão
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(task.isCompleted ? .green : .gray)
            }
            .buttonStyle(BorderlessButtonStyle())
            
            // Conteúdo da tarefa
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .gray : .primary)
                
                Text(formatDate(task.createdAt))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    /// Formata a data de criação da tarefa
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - App Entry Point
@main
struct TodoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
