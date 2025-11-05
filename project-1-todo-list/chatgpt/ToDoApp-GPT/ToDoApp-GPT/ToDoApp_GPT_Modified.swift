//
//  ToDoApp_GPT_Modified.swift
//  ToDoApp-GPT
//
//  Created by Samuel Viana on 29/10/25.
//

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

// MARK: - Persistência (Abstração)
// Protocolo que descreve operações de leitura/escrita para tarefas.
// Projetado para permitir trocas futuras (UserDefaults, arquivo local, CoreData, ou nuvem).
protocol TaskRepository {
    /// Carrega todas as tasks. Implementações podem ser assíncronas (I/O, rede...).
    func fetchAll() async -> Result<[Task], Error>

    /// Persiste a lista completa de tasks.
    func saveAll(_ tasks: [Task]) async -> Result<Void, Error>

    /// Adiciona uma task (opcional para implementações que possam otimizar).
    func add(_ task: Task) async -> Result<Void, Error>

    /// Remove uma task por id.
    func remove(id: UUID) async -> Result<Void, Error>
}

/// Erros simples para repositório local.
enum LocalRepositoryError: Error {
    case encodingFailed
    case decodingFailed
    case unknown
}

// MARK: - Repositório local (UserDefaults) — implementação concreta
/// Implementação simples usando UserDefaults + JSONEncoder/Decoder.
/// Opera assincronamente (simula latência) para permitir transição futura para rede/DB.
actor LocalTaskRepository: TaskRepository {
    private let storageKey = "com.example.ToDoApp.tasks"
    private let simulatedLatencyNanos: UInt64 = 100 * 1_000_000 // 100ms

    func fetchAll() async -> Result<[Task], Error> {
        // Simula I/O
        try? await Task.sleep(nanoseconds: simulatedLatencyNanos)

        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return .success([])
        }
        do {
            let tasks = try JSONDecoder().decode([Task].self, from: data)
            return .success(tasks)
        } catch {
            return .failure(LocalRepositoryError.decodingFailed)
        }
    }

    func saveAll(_ tasks: [Task]) async -> Result<Void, Error> {
        try? await Task.sleep(nanoseconds: simulatedLatencyNanos)
        do {
            let data = try JSONEncoder().encode(tasks)
            UserDefaults.standard.set(data, forKey: storageKey)
            return .success(())
        } catch {
            return .failure(LocalRepositoryError.encodingFailed)
        }
    }

    func add(_ task: Task) async -> Result<Void, Error> {
        // Implementação simples: carrega, anexa e salva.
        switch await fetchAll() {
        case .success(var tasks):
            tasks.insert(task, at: 0)
            return await saveAll(tasks)
        case .failure(let err):
            return .failure(err)
        }
    }

    func remove(id: UUID) async -> Result<Void, Error> {
        switch await fetchAll() {
        case .success(let tasks):
            let filtered = tasks.filter { $0.id != id }
            return await saveAll(filtered)
        case .failure(let err):
            return .failure(err)
        }
    }
}

// MARK: - ViewModel
/// Gerencia o estado das tarefas e fornece métodos para adicionar/remover/ordenar.
/// Usa um repositório injetado para persistência — fácil trocar por um repositório de nuvem.
@MainActor
final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [Task] = []

    private let repository: TaskRepository

    /// Construa com injeção de dependência. Por padrão, use LocalTaskRepository.
    init(repository: TaskRepository = LocalTaskRepository()) {
        self.repository = repository
        // carregamento assíncrono inicial
        Task { await self.loadFromRepository() }
    }

    // MARK: - Carregamento / Salvamento

    /// Carrega as tasks do repositório.
    private func loadFromRepository() async {
        let result = await repository.fetchAll()
        switch result {
        case .success(let loaded):
            // Atualiza o published — UI será atualizada.
            self.tasks = loaded
        case .failure:
            // Em produção, expor erro ao usuário ou log.
            self.tasks = []
        }
    }

    /// Persiste as tasks atuais no repositório de forma assíncrona.
    private func persistCurrent() {
        let current = tasks
        Task {
            _ = await repository.saveAll(current)
            // opcional: trate resultado (log / retry) se necessário
        }
    }

    // MARK: - Operações públicas (mantendo a API existente quando possível)

    /// Adiciona uma nova tarefa. Retorna `true` se adicionada com sucesso localmente.
    /// Persistência é feita assincronamente; caso queira aguardar, use `addAsync`.
    @discardableResult
    func add(title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let task = Task(title: trimmed)
        // Atualiza UI imediatamente
        tasks.insert(task, at: 0)
        // Persiste em background
        persistCurrent()
        return true
    }

    /// Versão assíncrona que aguarda confirmação do repositório.
    @discardableResult
    func addAsync(title: String) async -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let task = Task(title: trimmed)
        // Tenta adicionar via repositório (útil para repositórios remotos)
        switch await repository.add(task) {
        case .success:
            // Carrega novamente para garantir consistência com repositório
            await loadFromRepository()
            return true
        case .failure:
            // fallback local para manter responsividade
            await MainActor.run {
                tasks.insert(task, at: 0)
            }
            return true
        }
    }

    /// Remove a tarefa com o id dado.
    func remove(id: UUID) {
        tasks.removeAll { $0.id == id }
        persistCurrent()
    }

    /// Remove tarefas nos offsets (usado por List.onDelete).
    func remove(at offsets: IndexSet) {
        tasks.remove(atOffsets: offsets)
        persistCurrent()
    }

    /// Move tarefas (opcional).
    func move(from source: IndexSet, to destination: Int) {
        tasks.move(fromOffsets: source, toOffset: destination)
        persistCurrent()
    }

    /// Atualiza uma tarefa existente (ex: edição futura)
    func update(_ task: Task) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx] = task
        persistCurrent()
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
                    .onDelete { offsets in
                        // onDelete fornece IndexSet; use o método do store que persiste
                        store.remove(at: offsets)
                    }
                    .onMove { source, destination in
                        store.move(from: source, to: destination)
                    }
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
    @State private var isSaving = false

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
                    .disabled(isSaving)
            )
            .alert(isPresented: $showEmptyAlert) {
                Alert(title: Text("Título inválido"), message: Text("A tarefa não pode ficar vazia."), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showEmptyAlert = true
            return
        }

        // Mantém a mesma UX de antes: atualiza UI imediatamente e fecha a sheet.
        // A persistência acontece em background pelo TaskStore.persistCurrent().
        if store.add(title: trimmed) {
            isPresented = false
        } else {
            showEmptyAlert = true
        }
    }
}

// MARK: - App Entry

@main
struct ToDoApp: App {
    // Injeção de dependência: aqui podemos trocar por um repo remoto no futuro.
    @StateObject private var store = TaskStore(repository: LocalTaskRepository())

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}

// MARK: - Observações / Boas práticas aplicadas
/*
 - Substituí TaskPersistence por TaskRepository (protocolo) e LocalTaskRepository (actor).
 - As operações de I/O são assíncronas (async/await) e a implementação local simula latência.
 - TaskStore é @MainActor e publica mudanças via @Published; a UI continua reativa.
 - A API pública do TaskStore preserva a experiência prévia (add(title:) continua síncrono
   em termos de UX para fechar a tela imediatamente). Há também addAsync para casos em que
   se deseje aguardar confirmação da persistência remota.
 - A arquitetura facilita trocar LocalTaskRepository por uma implementação de nuvem
   (ex: Firebase, CloudKit) sem alterar as Views.
 - Comentários explicativos e separação de responsabilidades foram mantidos.
*/
