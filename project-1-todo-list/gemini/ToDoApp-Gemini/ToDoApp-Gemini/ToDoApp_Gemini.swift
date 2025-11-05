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
    // A ID é necessária e será gerada automaticamente.
    var id = UUID()
    // O título da tarefa.
    var title: String
    // Estado de conclusão (opcional, mas útil para uma lista de tarefas).
    var isCompleted: Bool = false
}

// MARK: - 2. O ViewModel (TodoListViewModel)

/**
  A classe ViewModel que gerencia a lista de tarefas e a persistência.
  - ObservableObject: Permite que a View seja notificada automaticamente
    sobre mudanças nos dados.
*/
class TodoListViewModel: ObservableObject {
    // Chave para salvar/carregar dados do UserDefaults.
    private let tasksKey = "todoTasks"

    // @Published: Publica mudanças no array, notificando a View.
    @Published var todoItems: [TodoItem] = [] {
        // didSet é chamado toda vez que 'todoItems' é modificado.
        didSet {
            saveTasks()
        }
    }

    // Inicializador: Carrega as tarefas salvas quando o ViewModel é criado.
    init() {
        loadTasks()
    }

    // MARK: - Persistência de Dados (UserDefaults)

    /**
      Salva a lista atual de tarefas no UserDefaults.
    */
    private func saveTasks() {
        do {
            // Usa JSONEncoder para transformar o array de structs em Data.
            let encodedData = try JSONEncoder().encode(todoItems)
            UserDefaults.standard.set(encodedData, forKey: tasksKey)
        } catch {
            print("Erro ao salvar tarefas: \(error)")
        }
    }

    /**
      Carrega as tarefas salvas do UserDefaults.
    */
    private func loadTasks() {
        guard
            let savedData = UserDefaults.standard.data(forKey: tasksKey),
            // Usa JSONDecoder para transformar Data em um array de structs.
            let loadedTasks = try? JSONDecoder().decode([TodoItem].self, from: savedData)
        else {
            return // Retorna se não houver dados salvos
        }

        self.todoItems = loadedTasks
    }

    // MARK: - Funções de Gerenciamento da Lista

    /**
      Adiciona uma nova tarefa à lista.
      - Parameter title: O título da nova tarefa.
    */
    func addTask(title: String) {
        // Garante que o título não é vazio ou apenas espaços em branco.
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let newItem = TodoItem(title: title)
        // Adiciona a tarefa ao início da lista (opcional, mas útil).
        todoItems.insert(newItem, at: 0)
    }

    /**
      Exclui tarefas com base em um conjunto de índices de uma lista.
      - Parameter indexSet: Conjunto de índices a serem excluídos.
    */
    func deleteTask(indexSet: IndexSet) {
        todoItems.remove(atOffsets: indexSet)
    }
    
    /**
      Função para alternar o estado de conclusão de uma tarefa (Opcional).
      - Parameter item: A tarefa a ser atualizada.
    */
    func toggleCompletion(item: TodoItem) {
        if let index = todoItems.firstIndex(where: { $0.id == item.id }) {
            // Cria uma cópia mutável, alterna o estado e substitui.
            todoItems[index].isCompleted.toggle()
        }
    }
}

// MARK: - 3. A View (ContentView)

/**
  A View principal que exibe a lista de tarefas e a interface de entrada.
*/
struct ContentView: View {
    // @StateObject: Cria uma instância do ViewModel e a mantém viva
    // enquanto a View estiver ativa, permitindo a persistência do estado.
    @StateObject var viewModel = TodoListViewModel()

    // @State: Variável local para armazenar o texto digitado pelo usuário.
    @State private var newTaskTitle: String = ""

    var body: some View {
        NavigationView {
            VStack {
                // MARK: - Área de Adição de Nova Tarefa
                HStack {
                    // Campo de texto para o título da nova tarefa.
                    TextField("Digite uma nova tarefa...", text: $newTaskTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    // Botão para adicionar a tarefa.
                    Button(action: {
                        viewModel.addTask(title: newTaskTitle)
                        newTaskTitle = "" // Limpa o campo após adicionar
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                    }
                    // Desabilita o botão se o campo de texto estiver vazio
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()

                // MARK: - Lista de Tarefas
                // List é um container otimizado para exibir linhas de dados.
                List {
                    // Itera sobre o array de tarefas do ViewModel.
                    // O `$` em $viewModel.todoItems permite data binding bidirecional,
                    // mas não é estritamente necessário aqui, pois a lista é observada
                    // via @Published no ViewModel.
                    ForEach(viewModel.todoItems) { item in
                        // A linha da tarefa.
                        HStack {
                            // Botão/ícone de conclusão.
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(item.isCompleted ? .green : .gray)
                                .onTapGesture {
                                    // Chama a função do ViewModel para alternar o estado.
                                    viewModel.toggleCompletion(item: item)
                                }

                            // Título da tarefa.
                            Text(item.title)
                                .strikethrough(item.isCompleted, color: .gray)
                                .foregroundColor(item.isCompleted ? .gray : .primary)
                        }
                    }
                    // Adiciona o modificador onDelete para habilitar a exclusão por swipe.
                    .onDelete(perform: viewModel.deleteTask)
                }
                // Define o título da Navigation View.
                .navigationTitle("✅ Minhas Tarefas")
                // Adiciona um botão de edição (opcional)
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
        ContentView()
    }
}

// MARK: - 4. App Entry Point

@main
struct TodoApp: App {
    var body: some Scene {
        WindowGroup {
            // A View inicial do aplicativo.
            ContentView()
        }
    }
}
