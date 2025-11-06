//  TodoListApp.swift
//  TodoListApp
//
//  Created for iOS 15+ using SwiftUI with UserDefaults persistence
//  MVC pattern adapted for SwiftUI (View-ViewModel-Model)

import SwiftUI

// MARK: - Model
struct TodoItem: Identifiable, Codable {
    let id = UUID()
    var title: String
    var isCompleted: Bool = false
    
    init(title: String) {
        self.title = title
    }
}

// MARK: - ViewModel
@MainActor
class TodoViewModel: ObservableObject {
    @Published var todos: [TodoItem] = []
    @Published var newTodoTitle: String = ""
    @Published var showingAlert: Bool = false
    @Published var alertMessage: String = ""
    
    private let storageKey = "SavedTodos"
    
    init() {
        loadTodos()
    }
    
    func addTodo() {
        guard !newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "Please enter a task title."
            showingAlert = true
            return
        }
        
        let trimmedTitle = newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let newTodo = TodoItem(title: trimmedTitle)
        todos.append(newTodo)
        newTodoTitle = ""
        saveTodos()
    }
    
    func deleteTodo(at offsets: IndexSet) {
        todos.remove(atOffsets: offsets)
        saveTodos()
    }
    
    func toggleCompleted(for todo: TodoItem) {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[index].isCompleted.toggle()
            saveTodos()
        }
    }
    
    private func saveTodos() {
        if let encoded = try? JSONEncoder().encode(todos) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadTodos() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([TodoItem].self, from: data)
        else {
            todos = []
            return
        }
        todos = decoded
    }
}

// MARK: - Views
struct ContentView: View {
    @StateObject private var viewModel = TodoViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                // Add new task section
                HStack {
                    TextField("New task...", text: $viewModel.newTodoTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: {
                        viewModel.addTodo()
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
                
                // Task list
                List {
                    ForEach(viewModel.todos) { todo in
                        HStack {
                            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(todo.isCompleted ? .green : .gray)
                                .onTapGesture {
                                    viewModel.toggleCompleted(for: todo)
                                }
                            
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
                EditButton()
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
