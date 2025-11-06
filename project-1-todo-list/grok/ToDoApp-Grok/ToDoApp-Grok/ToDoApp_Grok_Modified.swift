//  TodoListApp.swift
//  TodoListApp
//
//  Enhanced with protocol-based storage abstraction for future cloud sync
//  iOS 15+ • SwiftUI • MVVM + Protocol-Oriented Design

import SwiftUI

// MARK: - Model
struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isCompleted: Bool = false
    
    init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }
}

// MARK: - Storage Protocol
protocol TaskStorageProtocol {
    func saveTasks(_ tasks: [TodoItem]) async throws
    func loadTasks() async throws -> [TodoItem]
    func deleteTask(with id: UUID) async throws
}

// MARK: - Local Storage Implementation (UserDefaults)
actor LocalTaskStorage: TaskStorageProtocol {
    private let storageKey = "com.todolistapp.savedtasks"
    
    func saveTasks(_ tasks: [TodoItem]) async throws {
        let data = try JSONEncoder().encode(tasks)
        UserDefaults.standard.set(data, forKey: storageKey)
    }
    
    func loadTasks() async throws -> [TodoItem] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return []
        }
        return try JSONDecoder().decode([TodoItem].self, from: data)
    }
    
    func deleteTask(with id: UUID) async throws {
        var tasks = try await loadTasks()
        tasks.removeAll { $0.id == id }
        try await saveTasks(tasks)
    }
}

// MARK: - ViewModel with Abstracted Storage
@MainActor
class TodoViewModel: ObservableObject {
    @Published var todos: [TodoItem] = []
    @Published var newTodoTitle: String = ""
    @Published var showingAlert: Bool = false
    @Published var alertMessage: String = ""
    
    private let storage: TaskStorageProtocol
    
    init(storage: TaskStorageProtocol = LocalTaskStorage()) {
        self.storage = storage
        Task {
            await loadTasks()
        }
    }
    
    func addTodo() {
        let trimmed = newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            alertMessage = "Please enter a task title."
            showingAlert = true
            return
        }
        
        let newTodo = TodoItem(title: trimmed)
        todos.append(newTodo)
        newTodoTitle = ""
        
        Task {
            do {
                try await storage.saveTasks(todos)
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to save task."
                    showingAlert = true
                }
            }
        }
    }
    
    func deleteTodo(at offsets: IndexSet) {
        let idsToDelete = offsets.map { todos[$0].id }
        todos.remove(atOffsets: offsets)
        
        Task {
            for id in idsToDelete {
                do {
                    try await storage.deleteTask(with: id)
                } catch {
                    await MainActor.run {
                        alertMessage = "Failed to delete task."
                        showingAlert = true
                    }
                }
            }
        }
    }
    
    func toggleCompleted(for todo: TodoItem) {
        guard let index = todos.firstIndex(of: todo) else { return }
        todos[index].isCompleted.toggle()
        
        Task {
            do {
                try await storage.saveTasks(todos)
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to update task."
                    showingAlert = true
                }
            }
        }
    }
    
    private func loadTasks() async {
        do {
            let loaded = try await storage.loadTasks()
            todos = loaded
        } catch {
            await MainActor.run {
                alertMessage = "Failed to load tasks."
                showingAlert = true
            }
        }
    }
}

// MARK: - Views
struct ContentView: View {
    @StateObject private var viewModel = TodoViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                // Add new task
                HStack {
                    TextField("New task...", text: $viewModel.newTodoTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .submitLabel(.done)
                        .onSubmit {
                            viewModel.addTodo()
                        }
                    
                    Button(action: viewModel.addTodo) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Task list
                List {
                    ForEach(viewModel.todos) { todo in
                        HStack {
                            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(todo.isCompleted ? .green : .gray)
                            
                            Text(todo.title)
                                .strikethrough(todo.isCompleted)
                                .foregroundColor(todo.isCompleted ? .gray : .primary)
                            
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.toggleCompleted(for: todo)
                        }
                    }
                    .onDelete(perform: viewModel.deleteTodo)
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Todo List")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .alert("Error", isPresented: $viewModel.showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.alertMessage)
            }
        }
    }
}

// MARK: - App Entry Point
@main
struct TodoListApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
