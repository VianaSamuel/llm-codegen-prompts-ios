import UIKit
import Foundation

// MARK: - Models

/// Representa uma tarefa com todas suas propriedades
struct Task: Codable, Hashable, Identifiable {
    let id: UUID
    var title: String
    var description: String?
    var isCompleted: Bool
    let createdAt: Date
    
    init(id: UUID = UUID(), title: String, description: String? = nil, isCompleted: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.description = description
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}

// MARK: - Error Handling

/// Enum customizado para tratamento de erros específicos da aplicação
enum TaskError: LocalizedError {
    case networkError(Error)
    case storageError(String)
    case syncError(String)
    case validationError(String)
    case notFound
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Erro de rede: \(error.localizedDescription)"
        case .storageError(let message):
            return "Erro de armazenamento: \(message)"
        case .syncError(let message):
            return "Erro de sincronização: \(message)"
        case .validationError(let message):
            return "Erro de validação: \(message)"
        case .notFound:
            return "Tarefa não encontrada"
        case .unknown:
            return "Erro desconhecido"
        }
    }
}

// MARK: - Loading State

/// Enum para gerenciar estados de interface durante operações assíncronas
enum LoadingState<T> {
    case idle
    case loading
    case loaded(T)
    case error(TaskError)
    
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

// MARK: - Logging

/// Logger simples para debug de operações
class TaskLogger {
    static let shared = TaskLogger()
    private init() {}
    
    func log(_ message: String, level: LogLevel = .info) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(level.rawValue)] [\(timestamp)] \(message)")
    }
    
    enum LogLevel: String {
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case debug = "DEBUG"
    }
}

// MARK: - Network Reachability

/// Monitora conectividade de rede (preparado para sincronização futura)
class NetworkReachability {
    static let shared = NetworkReachability()
    private init() {}
    
    var isConnected: Bool {
        // Simulação simples - em produção usar Network framework
        return true
    }
    
    func startMonitoring() {
        TaskLogger.shared.log("Network monitoring iniciado", level: .info)
    }
    
    func stopMonitoring() {
        TaskLogger.shared.log("Network monitoring parado", level: .info)
    }
}

// MARK: - Storage Protocol

/// Protocolo que define operações de armazenamento com suporte async/await
protocol TaskStorageProtocol {
    func addTask(_ task: Task) async -> Result<Task, TaskError>
    func getTasks() async -> Result<[Task], TaskError>
    func updateTask(_ task: Task) async -> Result<Task, TaskError>
    func deleteTask(id: UUID) async -> Result<Void, TaskError>
    func toggleTaskCompletion(id: UUID) async -> Result<Task, TaskError>
    func clearAllTasks() async -> Result<Void, TaskError>
}

// MARK: - Local Storage Implementation

/// Implementação concreta do armazenamento local usando UserDefaults
class LocalTaskStorage: TaskStorageProtocol {
    private let userDefaultsKey = "savedTasks"
    private let queue = DispatchQueue(label: "com.todoapp.localstorage", attributes: .concurrent)
    
    // MARK: - TaskStorageProtocol Methods
    
    func addTask(_ task: Task) async -> Result<Task, TaskError> {
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                do {
                    var tasks = self.loadTasksSync()
                    tasks.insert(task, at: 0)
                    try self.saveTasksSync(tasks)
                    TaskLogger.shared.log("Tarefa adicionada: \(task.title)", level: .info)
                    continuation.resume(returning: .success(task))
                } catch {
                    TaskLogger.shared.log("Erro ao adicionar tarefa: \(error)", level: .error)
                    continuation.resume(returning: .failure(.storageError(error.localizedDescription)))
                }
            }
        }
    }
    
    func getTasks() async -> Result<[Task], TaskError> {
        return await withCheckedContinuation { continuation in
            queue.async {
                let tasks = self.loadTasksSync()
                TaskLogger.shared.log("Carregadas \(tasks.count) tarefas", level: .debug)
                continuation.resume(returning: .success(tasks))
            }
        }
    }
    
    func updateTask(_ task: Task) async -> Result<Task, TaskError> {
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                do {
                    var tasks = self.loadTasksSync()
                    guard let index = tasks.firstIndex(where: { $0.id == task.id }) else {
                        continuation.resume(returning: .failure(.notFound))
                        return
                    }
                    tasks[index] = task
                    try self.saveTasksSync(tasks)
                    TaskLogger.shared.log("Tarefa atualizada: \(task.title)", level: .info)
                    continuation.resume(returning: .success(task))
                } catch {
                    TaskLogger.shared.log("Erro ao atualizar tarefa: \(error)", level: .error)
                    continuation.resume(returning: .failure(.storageError(error.localizedDescription)))
                }
            }
        }
    }
    
    func deleteTask(id: UUID) async -> Result<Void, TaskError> {
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                do {
                    var tasks = self.loadTasksSync()
                    tasks.removeAll { $0.id == id }
                    try self.saveTasksSync(tasks)
                    TaskLogger.shared.log("Tarefa removida: \(id)", level: .info)
                    continuation.resume(returning: .success(()))
                } catch {
                    TaskLogger.shared.log("Erro ao remover tarefa: \(error)", level: .error)
                    continuation.resume(returning: .failure(.storageError(error.localizedDescription)))
                }
            }
        }
    }
    
    func toggleTaskCompletion(id: UUID) async -> Result<Task, TaskError> {
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                do {
                    var tasks = self.loadTasksSync()
                    guard let index = tasks.firstIndex(where: { $0.id == id }) else {
                        continuation.resume(returning: .failure(.notFound))
                        return
                    }
                    tasks[index].isCompleted.toggle()
                    let updatedTask = tasks[index]
                    try self.saveTasksSync(tasks)
                    TaskLogger.shared.log("Status alterado: \(updatedTask.title)", level: .info)
                    continuation.resume(returning: .success(updatedTask))
                } catch {
                    TaskLogger.shared.log("Erro ao alternar status: \(error)", level: .error)
                    continuation.resume(returning: .failure(.storageError(error.localizedDescription)))
                }
            }
        }
    }
    
    func clearAllTasks() async -> Result<Void, TaskError> {
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                UserDefaults.standard.removeObject(forKey: self.userDefaultsKey)
                TaskLogger.shared.log("Todas as tarefas removidas", level: .info)
                continuation.resume(returning: .success(()))
            }
        }
    }
    
    // MARK: - Private Sync Methods
    
    private func loadTasksSync() -> [Task] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([Task].self, from: data) else {
            return []
        }
        return decoded
    }
    
    private func saveTasksSync(_ tasks: [Task]) throws {
        let encoded = try JSONEncoder().encode(tasks)
        UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
    }
}

// MARK: - Data Sync Manager

/// Gerenciador preparado para sincronização futura com serviços em nuvem
class DataSyncManager {
    static let shared = DataSyncManager()
    private init() {}
    
    private var lastSyncTimestamp: Date?
    
    /// Stub para sincronização futura
    func sync() async -> Result<Void, TaskError> {
        TaskLogger.shared.log("Sincronização iniciada (stub)", level: .debug)
        // Futura implementação: sincronizar com backend
        lastSyncTimestamp = Date()
        return .success(())
    }
    
    /// Stub para resolução de conflitos
    func conflictResolution(localTask: Task, remoteTask: Task) -> Task {
        TaskLogger.shared.log("Resolvendo conflito (stub)", level: .debug)
        // Futura implementação: estratégia de resolução (last-write-wins, merge, etc)
        return localTask.createdAt > remoteTask.createdAt ? localTask : remoteTask
    }
    
    /// Estratégia de conflito de dados
    enum DataConflictStrategy {
        case localWins
        case remoteWins
        case mostRecent
        case manual
    }
}

// MARK: - Task Repository

/// Camada intermediária que gerencia cache e sincronização
class TaskRepository {
    static let shared = TaskRepository()
    private let storage: TaskStorageProtocol
    private var cachedTasks: [Task] = []
    private var cacheTimestamp: Date?
    private let cacheDuration: TimeInterval = 300 // 5 minutos
    
    init(storage: TaskStorageProtocol = LocalTaskStorage()) {
        self.storage = storage
        TaskLogger.shared.log("TaskRepository inicializado", level: .info)
    }
    
    // MARK: - Public Methods
    
    func addTask(_ task: Task) async -> Result<Task, TaskError> {
        let result = await storage.addTask(task)
        if case .success = result {
            invalidateCache()
        }
        return result
    }
    
    func getTasks(forceRefresh: Bool = false) async -> Result<[Task], TaskError> {
        if !forceRefresh, let cached = getCachedTasks() {
            TaskLogger.shared.log("Retornando tarefas do cache", level: .debug)
            return .success(cached)
        }
        
        let result = await storage.getTasks()
        if case .success(let tasks) = result {
            updateCache(tasks)
        }
        return result
    }
    
    func updateTask(_ task: Task) async -> Result<Task, TaskError> {
        let result = await storage.updateTask(task)
        if case .success = result {
            invalidateCache()
        }
        return result
    }
    
    func deleteTask(id: UUID) async -> Result<Void, TaskError> {
        let result = await storage.deleteTask(id: id)
        if case .success = result {
            invalidateCache()
        }
        return result
    }
    
    func toggleTaskCompletion(id: UUID) async -> Result<Task, TaskError> {
        let result = await storage.toggleTaskCompletion(id: id)
        if case .success = result {
            invalidateCache()
        }
        return result
    }
    
    func clearAllTasks() async -> Result<Void, TaskError> {
        let result = await storage.clearAllTasks()
        if case .success = result {
            invalidateCache()
        }
        return result
    }
    
    // MARK: - Cache Management
    
    private func getCachedTasks() -> [Task]? {
        guard let timestamp = cacheTimestamp,
              Date().timeIntervalSince(timestamp) < cacheDuration else {
            return nil
        }
        return cachedTasks
    }
    
    private func updateCache(_ tasks: [Task]) {
        cachedTasks = tasks
        cacheTimestamp = Date()
    }
    
    private func invalidateCache() {
        cacheTimestamp = nil
        cachedTasks = []
    }
}

// MARK: - Task Manager

/// Manager principal que expõe interface simplificada para ViewControllers
class TaskManager {
    static let shared = TaskManager()
    private let repository: TaskRepository
    
    init(repository: TaskRepository = .shared) {
        self.repository = repository
    }
    
    func addTask(title: String, description: String? = nil) async -> Result<Task, TaskError> {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return .failure(.validationError("Título não pode estar vazio"))
        }
        
        let task = Task(title: trimmedTitle, description: description)
        return await repository.addTask(task)
    }
    
    func getTasks(forceRefresh: Bool = false) async -> Result<[Task], TaskError> {
        return await repository.getTasks(forceRefresh: forceRefresh)
    }
    
    func updateTask(_ task: Task) async -> Result<Task, TaskError> {
        guard !task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.validationError("Título não pode estar vazio"))
        }
        return await repository.updateTask(task)
    }
    
    func deleteTask(id: UUID) async -> Result<Void, TaskError> {
        return await repository.deleteTask(id: id)
    }
    
    func toggleTaskCompletion(id: UUID) async -> Result<Task, TaskError> {
        return await repository.toggleTaskCompletion(id: id)
    }
    
    func clearAllTasks() async -> Result<Void, TaskError> {
        return await repository.clearAllTasks()
    }
    
    func searchTasks(query: String, in tasks: [Task]) -> [Task] {
        guard !query.isEmpty else { return tasks }
        let lowercasedQuery = query.lowercased()
        return tasks.filter {
            $0.title.lowercased().contains(lowercasedQuery) ||
            ($0.description?.lowercased().contains(lowercasedQuery) ?? false)
        }
    }
    
    func filterTasks(_ tasks: [Task], showCompleted: Bool, showPending: Bool) -> [Task] {
        tasks.filter { task in
            (showCompleted && task.isCompleted) || (showPending && !task.isCompleted)
        }
    }
    
    func sortTasks(_ tasks: [Task], by option: SortOption) -> [Task] {
        switch option {
        case .dateNewest:
            return tasks.sorted { $0.createdAt > $1.createdAt }
        case .dateOldest:
            return tasks.sorted { $0.createdAt < $1.createdAt }
        case .titleAZ:
            return tasks.sorted { $0.title.lowercased() < $1.title.lowercased() }
        case .titleZA:
            return tasks.sorted { $0.title.lowercased() > $1.title.lowercased() }
        case .completedFirst:
            return tasks.sorted { $0.isCompleted && !$1.isCompleted }
        case .pendingFirst:
            return tasks.sorted { !$0.isCompleted && $1.isCompleted }
        }
    }
    
    enum SortOption: String, CaseIterable {
        case dateNewest = "Mais Recentes"
        case dateOldest = "Mais Antigas"
        case titleAZ = "Título A-Z"
        case titleZA = "Título Z-A"
        case completedFirst = "Concluídas Primeiro"
        case pendingFirst = "Pendentes Primeiro"
    }
}

// MARK: - Custom TableView Cell

class TaskTableViewCell: UITableViewCell {
    static let identifier = "TaskTableViewCell"
    
    private let checkmarkButton: UIButton = {
        let btn = UIButton()
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    private let titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 16, weight: .medium)
        lbl.numberOfLines = 2
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()
    
    private let descriptionLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 14)
        lbl.textColor = .secondaryLabel
        lbl.numberOfLines = 1
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()
    
    private let dateLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 12)
        lbl.textColor = .tertiaryLabel
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()
    
    var onToggle: (() -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.addSubview(checkmarkButton)
        contentView.addSubview(titleLabel)
        contentView.addSubview(descriptionLabel)
        contentView.addSubview(dateLabel)
        
        checkmarkButton.addTarget(self, action: #selector(toggleTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            checkmarkButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            checkmarkButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkmarkButton.widthAnchor.constraint(equalToConstant: 30),
            checkmarkButton.heightAnchor.constraint(equalToConstant: 30),
            
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: checkmarkButton.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            dateLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 4),
            dateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            dateLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    @objc private func toggleTapped() {
        onToggle?()
    }
    
    func configure(with task: Task) {
        titleLabel.text = task.title
        descriptionLabel.text = task.description
        descriptionLabel.isHidden = task.description == nil || task.description?.isEmpty == true
        
        let config = UIImage.SymbolConfiguration(pointSize: 24)
        let imageName = task.isCompleted ? "checkmark.circle.fill" : "circle"
        checkmarkButton.setImage(UIImage(systemName: imageName, withConfiguration: config), for: .normal)
        checkmarkButton.tintColor = task.isCompleted ? .systemGreen : .systemGray
        
        if task.isCompleted {
            let attributedString = NSAttributedString(
                string: task.title,
                attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue]
            )
            titleLabel.attributedText = attributedString
            titleLabel.textColor = .secondaryLabel
        } else {
            titleLabel.attributedText = nil
            titleLabel.textColor = .label
        }
        
        dateLabel.text = formatDate(task.createdAt)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Task List View Controller

class TaskListViewController: UIViewController {
    
    private let tableView = UITableView()
    private let searchBar = UISearchBar()
    private let emptyStateLabel = UILabel()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private let refreshControl = UIRefreshControl()
    
    private var loadingState: LoadingState<[Task]> = .idle {
        didSet { updateUI() }
    }
    
    private var allTasks: [Task] = []
    private var filteredTasks: [Task] = []
    private var currentSortOption: TaskManager.SortOption = .dateNewest
    private var showCompleted = true
    private var showPending = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupViews()
        setupConstraints()
        loadTasks()
        NetworkReachability.shared.startMonitoring()
    }
    
    private func setupNavigationBar() {
        title = "Minhas Tarefas"
        navigationController?.navigationBar.prefersLargeTitles = true
        
        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addTaskTapped))
        let sortButton = UIBarButtonItem(image: UIImage(systemName: "arrow.up.arrow.down"), style: .plain, target: self, action: #selector(sortTapped))
        let filterButton = UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal.decrease.circle"), style: .plain, target: self, action: #selector(filterTapped))
        let moreButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), style: .plain, target: self, action: #selector(moreTapped))
        
        navigationItem.rightBarButtonItems = [addButton, sortButton, filterButton, moreButton]
    }
    
    private func setupViews() {
        view.backgroundColor = .systemBackground
        
        searchBar.delegate = self
        searchBar.placeholder = "Buscar tarefas..."
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(TaskTableViewCell.self, forCellReuseIdentifier: TaskTableViewCell.identifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(refreshTasks), for: .valueChanged)
        
        emptyStateLabel.text = "Nenhuma tarefa ainda\n\nToque em + para adicionar"
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.textColor = .secondaryLabel
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.isHidden = true
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        
        view.addSubview(searchBar)
        view.addSubview(tableView)
        view.addSubview(emptyStateLabel)
        view.addSubview(loadingIndicator)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyStateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func loadTasks(forceRefresh: Bool = false) {
        loadingState = .loading
        
        Task {
            let result = await TaskManager.shared.getTasks(forceRefresh: forceRefresh)
            
            await MainActor.run {
                switch result {
                case .success(let tasks):
                    self.allTasks = tasks
                    self.applyFiltersAndSort()
                    self.loadingState = .loaded(tasks)
                case .failure(let error):
                    self.loadingState = .error(error)
                    self.showError(error)
                }
            }
        }
    }
    
    @objc private func refreshTasks() {
        Task {
            // Stub para sincronização futura
            _ = await DataSyncManager.shared.sync()
            loadTasks(forceRefresh: true)
            
            await MainActor.run {
                self.refreshControl.endRefreshing()
            }
        }
    }
    
    private func applyFiltersAndSort() {
        var tasks = TaskManager.shared.filterTasks(allTasks, showCompleted: showCompleted, showPending: showPending)
        
        if let searchText = searchBar.text, !searchText.isEmpty {
            tasks = TaskManager.shared.searchTasks(query: searchText, in: tasks)
        }
        
        tasks = TaskManager.shared.sortTasks(tasks, by: currentSortOption)
        filteredTasks = tasks
        tableView.reloadData()
    }
    
    private func updateUI() {
        switch loadingState {
        case .idle:
            loadingIndicator.stopAnimating()
            emptyStateLabel.isHidden = true
        case .loading:
            loadingIndicator.startAnimating()
            emptyStateLabel.isHidden = true
        case .loaded(let tasks):
            loadingIndicator.stopAnimating()
            emptyStateLabel.isHidden = !tasks.isEmpty
            updateTitle()
        case .error:
            loadingIndicator.stopAnimating()
            emptyStateLabel.isHidden = false
            emptyStateLabel.text = "Erro ao carregar tarefas\n\nTente novamente"
        }
    }
    
    private func updateTitle() {
        let completed = allTasks.filter { $0.isCompleted }.count
        let total = allTasks.count
        title = "Tarefas (\(completed)/\(total))"
    }
    
    @objc private func addTaskTapped() {
        let vc = AddEditTaskViewController()
        vc.onSave = { [weak self] in
            self?.loadTasks()
        }
        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: true)
    }
    
    @objc private func sortTapped() {
        let alert = UIAlertController(title: "Ordenar Por", message: nil, preferredStyle: .actionSheet)
        
        for option in TaskManager.SortOption.allCases {
            let action = UIAlertAction(title: option.rawValue, style: .default) { [weak self] _ in
                self?.currentSortOption = option
                self?.applyFiltersAndSort()
            }
            if option == currentSortOption {
                action.setValue(true, forKey: "checked")
            }
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func filterTapped() {
        let alert = UIAlertController(title: "Filtrar Tarefas", message: nil, preferredStyle: .actionSheet)
        
        let completedAction = UIAlertAction(title: "Concluídas", style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.showCompleted.toggle()
            self.applyFiltersAndSort()
        }
        completedAction.setValue(showCompleted, forKey: "checked")
        
        let pendingAction = UIAlertAction(title: "Pendentes", style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.showPending.toggle()
            self.applyFiltersAndSort()
        }
        pendingAction.setValue(showPending, forKey: "checked")
        
        alert.addAction(completedAction)
        alert.addAction(pendingAction)
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func moreTapped() {
        let alert = UIAlertController(title: "Opções", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Limpar Todas as Tarefas", style: .destructive) { [weak self] _ in
            self?.confirmClearAll()
        })
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        present(alert, animated: true)
    }
    
    private func confirmClearAll() {
        let alert = UIAlertController(
            title: "Limpar Todas as Tarefas",
            message: "Tem certeza que deseja excluir todas as tarefas? Esta ação não pode ser desfeita.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Excluir Tudo", style: .destructive) { [weak self] _ in
            self?.clearAllTasks()
        })
        
        present(alert, animated: true)
    }
    
    private func clearAllTasks() {
        loadingState = .loading
        
        Task {
            let result = await TaskManager.shared.clearAllTasks()
            
            await MainActor.run {
                switch result {
                case .success:
                    self.loadTasks()
                case .failure(let error):
                    self.showError(error)
                }
            }
        }
    }
    
    private func showError(_ error: TaskError) {
        let alert = UIAlertController(
            title: "Erro",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDelegate & DataSource

extension TaskListViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredTasks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TaskTableViewCell.identifier, for: indexPath) as? TaskTableViewCell else {
            return UITableViewCell()
        }
        
        let task = filteredTasks[indexPath.row]
        cell.configure(with: task)
        cell.onToggle = { [weak self] in
            self?.toggleTask(task)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let task = filteredTasks[indexPath.row]
        let vc = TaskDetailViewController(task: task)
        vc.onUpdate = { [weak self] in
            self?.loadTasks()
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Excluir") { [weak self] _, _, completion in
            let task = self?.filteredTasks[indexPath.row]
            if let taskId = task?.id {
                self?.deleteTask(taskId)
            }
            completion(true)
        }
        deleteAction.image = UIImage(systemName: "trash.fill")
        
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
    
    private func toggleTask(_ task: Task) {
        Task {
            let result = await TaskManager.shared.toggleTaskCompletion(id: task.id)
            
            await MainActor.run {
                switch result {
                case .success:
                    self.loadTasks()
                case .failure(let error):
                    self.showError(error)
                }
            }
        }
    }
    
    private func deleteTask(_ id: UUID) {
        Task {
            let result = await TaskManager.shared.deleteTask(id: id)
            
            await MainActor.run {
                switch result {
                case .success:
                    self.loadTasks()
                case .failure(let error):
                    self.showError(error)
                }
            }
        }
    }
}

// MARK: - UISearchBarDelegate

extension TaskListViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        applyFiltersAndSort()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - Add/Edit Task View Controller

class AddEditTaskViewController: UIViewController {
    
    private let titleTextField = UITextField()
    private let descriptionTextView = UITextView()
    private let saveButton = UIButton(type: .system)
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    
    private var task: Task?
    var onSave: (() -> Void)?
    
    init(task: Task? = nil) {
        self.task = task
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupViews()
        setupConstraints()
        populateData()
    }
    
    private func setupNavigationBar() {
        title = task == nil ? "Nova Tarefa" : "Editar Tarefa"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
    }
    
    private func setupViews() {
        view.backgroundColor = .systemBackground
        
        titleTextField.placeholder = "Título da tarefa"
        titleTextField.borderStyle = .roundedRect
        titleTextField.font = .systemFont(ofSize: 16)
        titleTextField.translatesAutoresizingMaskIntoConstraints = false
        
        descriptionTextView.font = .systemFont(ofSize: 14)
        descriptionTextView.layer.borderWidth = 1
        descriptionTextView.layer.borderColor = UIColor.separator.cgColor
        descriptionTextView.layer.cornerRadius = 8
        descriptionTextView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        descriptionTextView.translatesAutoresizingMaskIntoConstraints = false
        
        saveButton.setTitle("Salvar", for: .normal)
        saveButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        saveButton.backgroundColor = .systemBlue
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 10
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        
        view.addSubview(titleTextField)
        view.addSubview(descriptionTextView)
        view.addSubview(saveButton)
        view.addSubview(loadingIndicator)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            titleTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            titleTextField.heightAnchor.constraint(equalToConstant: 44),
            
            descriptionTextView.topAnchor.constraint(equalTo: titleTextField.bottomAnchor, constant: 20),
            descriptionTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            descriptionTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            descriptionTextView.heightAnchor.constraint(equalToConstant: 120),
            
            saveButton.topAnchor.constraint(equalTo: descriptionTextView.bottomAnchor, constant: 30),
            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            saveButton.heightAnchor.constraint(equalToConstant: 50),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: saveButton.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: saveButton.centerYAnchor)
        ])
    }
    
    private func populateData() {
        guard let task = task else { return }
        titleTextField.text = task.title
        descriptionTextView.text = task.description
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func saveTapped() {
        guard let title = titleTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else {
            showAlert(message: "Por favor, insira um título para a tarefa")
            return
        }
        
        let description = descriptionTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalDescription = description?.isEmpty == true ? nil : description
        
        setLoading(true)
        
        Task {
            let result: Result<Task, TaskError>
            
            if var existingTask = self.task {
                existingTask.title = title
                existingTask.description = finalDescription
                result = await TaskManager.shared.updateTask(existingTask)
            } else {
                result = await TaskManager.shared.addTask(title: title, description: finalDescription)
            }
            
            await MainActor.run {
                self.setLoading(false)
                
                switch result {
                case .success:
                    self.onSave?()
                    self.dismiss(animated: true)
                case .failure(let error):
                    self.showAlert(message: error.localizedDescription)
                }
            }
        }
    }
    
    private func setLoading(_ isLoading: Bool) {
        saveButton.isEnabled = !isLoading
        saveButton.alpha = isLoading ? 0.5 : 1.0
        
        if isLoading {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
        }
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Atenção", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Task Detail View Controller

class TaskDetailViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let statusLabel = UILabel()
    private let dateLabel = UILabel()
    private let toggleButton = UIButton(type: .system)
    private let editButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    
    private var task: Task
    var onUpdate: (() -> Void)?
    
    init(task: Task) {
        self.task = task
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupConstraints()
        updateUI()
    }
    
    private func setupViews() {
        title = "Detalhes"
        view.backgroundColor = .systemBackground
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.font = .boldSystemFont(ofSize: 24)
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        descriptionLabel.font = .systemFont(ofSize: 16)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        statusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        dateLabel.font = .systemFont(ofSize: 14)
        dateLabel.textColor = .tertiaryLabel
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        
        toggleButton.setTitle("Marcar como Concluída", for: .normal)
        toggleButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        toggleButton.backgroundColor = .systemGreen
        toggleButton.setTitleColor(.white, for: .normal)
        toggleButton.layer.cornerRadius = 10
        toggleButton.addTarget(self, action: #selector(toggleTapped), for: .touchUpInside)
        toggleButton.translatesAutoresizingMaskIntoConstraints = false
        
        editButton.setTitle("Editar", for: .normal)
        editButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        editButton.backgroundColor = .systemBlue
        editButton.setTitleColor(.white, for: .normal)
        editButton.layer.cornerRadius = 10
        editButton.addTarget(self, action: #selector(editTapped), for: .touchUpInside)
        editButton.translatesAutoresizingMaskIntoConstraints = false
        
        deleteButton.setTitle("Excluir Tarefa", for: .normal)
        deleteButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        deleteButton.backgroundColor = .systemRed
        deleteButton.setTitleColor(.white, for: .normal)
        deleteButton.layer.cornerRadius = 10
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(statusLabel)
        contentView.addSubview(dateLabel)
        contentView.addSubview(descriptionLabel)
        contentView.addSubview(toggleButton)
        contentView.addSubview(editButton)
        contentView.addSubview(deleteButton)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            
            dateLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            dateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            
            descriptionLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 24),
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            toggleButton.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 40),
            toggleButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            toggleButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            toggleButton.heightAnchor.constraint(equalToConstant: 50),
            
            editButton.topAnchor.constraint(equalTo: toggleButton.bottomAnchor, constant: 16),
            editButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            editButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            editButton.heightAnchor.constraint(equalToConstant: 50),
            
            deleteButton.topAnchor.constraint(equalTo: editButton.bottomAnchor, constant: 16),
            deleteButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            deleteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            deleteButton.heightAnchor.constraint(equalToConstant: 50),
            deleteButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }
    
    private func updateUI() {
        titleLabel.text = task.title
        
        if let description = task.description, !description.isEmpty {
            descriptionLabel.text = description
            descriptionLabel.isHidden = false
        } else {
            descriptionLabel.text = "Sem descrição"
            descriptionLabel.isHidden = false
        }
        
        statusLabel.text = task.isCompleted ? "✓ Concluída" : "○ Pendente"
        statusLabel.textColor = task.isCompleted ? .systemGreen : .systemOrange
        
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "pt_BR")
        dateLabel.text = "Criada em: \(formatter.string(from: task.createdAt))"
        
        let toggleTitle = task.isCompleted ? "Marcar como Pendente" : "Marcar como Concluída"
        toggleButton.setTitle(toggleTitle, for: .normal)
        toggleButton.backgroundColor = task.isCompleted ? .systemOrange : .systemGreen
    }
    
    @objc private func toggleTapped() {
        Task {
            let result = await TaskManager.shared.toggleTaskCompletion(id: task.id)
            
            await MainActor.run {
                switch result {
                case .success(let updatedTask):
                    self.task = updatedTask
                    self.updateUI()
                    self.onUpdate?()
                case .failure(let error):
                    self.showAlert(message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func editTapped() {
        let vc = AddEditTaskViewController(task: task)
        vc.onSave = { [weak self] in
            self?.onUpdate?()
            self?.navigationController?.popViewController(animated: true)
        }
        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: true)
    }
    
    @objc private func deleteTapped() {
        let alert = UIAlertController(
            title: "Excluir Tarefa",
            message: "Tem certeza que deseja excluir esta tarefa?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Excluir", style: .destructive) { [weak self] _ in
            self?.confirmDelete()
        })
        
        present(alert, animated: true)
    }
    
    private func confirmDelete() {
        Task {
            let result = await TaskManager.shared.deleteTask(id: task.id)
            
            await MainActor.run {
                switch result {
                case .success:
                    self.onUpdate?()
                    self.navigationController?.popViewController(animated: true)
                case .failure(let error):
                    self.showAlert(message: error.localizedDescription)
                }
            }
        }
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Erro", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - App Delegate

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        window = UIWindow(frame: UIScreen.main.bounds)
        
        let taskListVC = TaskListViewController()
        let navigationController = UINavigationController(rootViewController: taskListVC)
        
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
        
        TaskLogger.shared.log("Aplicativo iniciado", level: .info)
        
        return true
    }
}
