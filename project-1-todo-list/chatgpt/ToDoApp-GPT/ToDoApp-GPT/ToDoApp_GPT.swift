import SwiftUI

// MARK: - Modelo

/// Representa uma tarefa simples.
struct Task: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var createdAt: Date

    init(id: UUID = UUID(), title: String, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
    }
}

// MARK: - Persistência

/// Responsável por salvar/carregar a lista de tarefas localmente usando UserDefaults.
/// Usa JSONEncoder/Decoder para serializar o array de `Task`.
enum TaskPersistence {
    private static let storageKey = "com.example.ToDoApp.tasks"

    static func save(_ tasks: [Task]) {
        do {
            let data = try JSONEncoder().encode(tasks)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // Em produção, trate melhor os erros (logs, alertas, etc.)
            print("Erro ao salvar tasks: \(error)")
        }
    }

    static func load() -> [Task] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        do {
            let tasks = try JSONDecoder().decode([Task].self, from: data)
            return tasks
        } catch {
            print("Erro ao carregar tasks: \(error)")
            return []
        }
    }
}

// MARK: - ViewModel

/// Gerencia o estado das tarefas e fornece métodos para adicionar/remover/ordenar.
final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [Task] = [] {
        didSet { TaskPersistence.save(tasks) }
    }

    init() {
        self.tasks = TaskPersistence.load()
    }

    /// Adiciona uma nova tarefa. Retorna `true` se adicionada com sucesso, `false` se título inválido.
    @discardableResult
    func add(title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let task = Task(title: trimmed)
        tasks.insert(task, at: 0) // insere no topo da lista
        return true
    }

    /// Remove a tarefa com o id dado.
    func remove(id: UUID) {
        tasks.removeAll { $0.id == id }
    }

    /// Remove tarefas nos offsets (usado por List.onDelete)
    func remove(at offsets: IndexSet) {
        tasks.remove(atOffsets: offsets)
    }

    /// Move tarefas (opcional)
    func move(from source: IndexSet, to destination: Int) {
        tasks.move(fromOffsets: source, toOffset: destination)
    }

    /// Atualiza uma tarefa existente (ex: edição futura)
    func update(_ task: Task) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx] = task
    }
}

// MARK: - Views

/// View principal que mostra a lista de tarefas e controles para adicionar/excluir.
struct ContentView: View {
    @EnvironmentObject private var store: TaskStore
    @State private var showingAddSheet = false

    var body: some View {
        NavigationView {
            List {
                if store.tasks.isEmpty {
                    VStack(alignment: .center) {
                        Text("Nenhuma tarefa cadastrada")
                            .foregroundColor(.secondary)
                        Text("Use o botão + para adicionar uma tarefa")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(store.tasks) { task in
                        TaskRow(task: task)
                    }
                    .onDelete(perform: store.remove)
                    .onMove(perform: store.move)
                }
            }
            .navigationTitle("Tarefas")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Adicionar tarefa")
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddTaskView(isPresented: $showingAddSheet)
                    .environmentObject(store)
            }
        }
    }
}

/// Linha de célula que exibe título e data de criação.
struct TaskRow: View {
    let task: Task

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                Text(formattedDate(task.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func formattedDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }
}

/// View usada para adicionar uma nova tarefa. Faz validação básica (não permite vazio).
struct AddTaskView: View {
    @EnvironmentObject private var store: TaskStore
    @Binding var isPresented: Bool

    @State private var title: String = ""
    @State private var showEmptyAlert = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Nova tarefa")) {
                    TextField("O que precisa ser feito?", text: $title)
                        .autocapitalization(.sentences)
                }
            }
            .navigationTitle("Adicionar")
            .navigationBarItems(
                leading: Button("Cancelar") { isPresented = false },
                trailing: Button("Salvar") { save() }
            )
            .alert(isPresented: $showEmptyAlert) {
                Alert(title: Text("Título inválido"), message: Text("A tarefa não pode ficar vazia."), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func save() {
        if store.add(title: title) {
            isPresented = false
        } else {
            showEmptyAlert = true
        }
    }
}

// MARK: - App Entry

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

// MARK: - Observations / Boas práticas aplicadas

/*
 - Separação de responsabilidades:
   Model (Task), Persistência (TaskPersistence), ViewModel (TaskStore) e Views (ContentView, AddTaskView, TaskRow).
 - Persistência local simples e confiável via UserDefaults com serialização JSON.
 - Uso de ObservableObject + @Published para atualizações reativas da UI.
 - Validação básica: impede título vazio/whitespace.
 - Código comentado e organizado para facilitar manutenção.
 - Não depende de bibliotecas externas; pronto para compilar em Xcode 12+ com Swift 5 / SwiftUI.

 Sugestão de uso: crie um novo projeto SwiftUI no Xcode e substitua o conteúdo do arquivo principal (por exemplo ContentView.swift ou crie um novo arquivo ToDoApp.swift) pelo código acima. O app salva automaticamente ao adicionar/editar/excluir tarefas.
*/
