# ToDoApp - Claude

Este repositório contém o aplicativo de lista de tarefas gerado utilizando Claude como parte do trabalho de conclusão de curso (TCC).

## 1. App Inicial

### a) Prompt Utilizado:

Você é um especialista em desenvolvimento iOS. Crie um prompt que possa ser usado para gerar um aplicativo iOS em Swift que gerencie uma lista de tarefas simples, permitindo cadastro, listagem e exclusão de itens. O prompt deve instruir o modelo a produzir código funcional, legível e organizado, seguindo boas práticas de programação em Swift e utilizando armazenamento local em cache. Mantenha todo o prompt em uma única linha contínua, sem quebras de linha, e inclua todas as instruções necessárias para gerar o aplicativo corretamente.

### b) Prompt Gerado:

Crie um aplicativo iOS completo em Swift para gerenciamento de lista de tarefas com as seguintes especificações: desenvolva usando UIKit com arquitetura MVC, implemente uma estrutura Task com propriedades id (UUID), title (String), description (String opcional), isCompleted (Bool) e createdAt (Date), crie um TaskManager como classe singleton para gerenciar operações CRUD usando UserDefaults para persistência local com métodos addTask, getTasks, updateTask, deleteTask e toggleTaskCompletion, desenvolva uma TaskTableViewCell customizada com labels para título e descrição, checkbox para status de conclusão e botão de exclusão, implemente TaskListViewController como controller principal com UITableView, barra de navegação com botão "+" para adicionar tarefas, funcionalidade de swipe-to-delete, pull-to-refresh e segues para tela de detalhes, crie AddEditTaskViewController para cadastro e edição com UITextField para título, UITextView para descrição, UISwitch para status de conclusão, validação de campos obrigatórios e botões salvar/cancelar, implemente TaskDetailViewController para visualização completa da tarefa com opções de editar e excluir, configure Auto Layout programaticamente ou via Storyboard para suportar diferentes tamanhos de tela, adicione tratamento de erros com alerts informativos, implemente animações suaves para transições entre telas e atualizações da lista, use delegates e protocols adequadamente para comunicação entre view controllers, aplique princípios de Clean Code com nomes descritivos, comentários explicativos e separação de responsabilidades, configure o AppDelegate e SceneDelegate corretamente, adicione ícone de aplicativo e Launch Screen básicos, implemente funcionalidades extras como busca de tarefas, filtros por status (todas/pendentes/concluídas), ordenação por data de criação, contador de tarefas pendentes na navigation bar, suporte a modo escuro, e garanta que o código seja totalmente funcional, bem estruturado, comentado e siga as melhores práticas de desenvolvimento iOS com Swift, incluindo tratamento adequado de memory management, thread safety para operações de persistência e experiência de usuário fluida e intuitiva.

### c) Evidências

<img src="docs/assets/ToDoApp-Claude%20-%201.PNG" width="300" alt="Evidência 1">

<img src="docs/assets/ToDoApp-Claude%20-%202.PNG" width="300" alt="Evidência 2">

<img src="docs/assets/ToDoApp-Claude%20-%203.PNG" width="300" alt="Evidência 3">

<img src="docs/assets/ToDoApp-Claude%20-%204.PNG" width="300" alt="Evidência 4">

## 2. App Após Modificações

### a) Prompt Utilizado:

Você é um especialista em desenvolvimento iOS. Crie um prompt que possa ser usado para modificar um aplicativo iOS de lista de tarefas previamente gerado. O prompt deve instruir o modelo a substituir o armazenamento local por uma camada de abstração preparada para integração futura com armazenamento em nuvem, mantendo a consistência, clareza e funcionalidade do código existente, sem implementar o serviço remoto. Mantenha todo o prompt em uma única linha contínua, sem quebras de linha, e inclua todas as instruções necessárias para gerar o aplicativo corretamente.

### b) Prompt Gerado:

Modifique o aplicativo iOS de lista de tarefas existente em Swift substituindo o sistema de armazenamento local por uma arquitetura em camadas preparada para integração futura com serviços em nuvem: refatore a estrutura mantendo UIKit com arquitetura MVC, preserve a estrutura Task existente com propriedades id (UUID), title (String), description (String opcional), isCompleted (Bool) e createdAt (Date) adicionando conformidade aos protocolos Codable e Hashable, crie um protocolo TaskStorageProtocol com métodos assíncronos usando completion handlers ou async/await para operações CRUD (addTask, getTasks, updateTask, deleteTask, toggleTaskCompletion) que retornem Result<T, Error> para tratamento consistente de erros, implemente LocalTaskStorage como classe concreta que conforma ao protocolo TaskStorageProtocol mantendo UserDefaults internamente mas com interface assíncrona, desenvolva TaskRepository como camada intermediária singleton que utilize TaskStorageProtocol e gerencie cache local, sincronização futura e estratégias de fallback, refatore TaskManager para usar TaskRepository em vez de acessar UserDefaults diretamente, mantendo a mesma interface pública mas com suporte a operações assíncronas, atualize todos os ViewControllers (TaskListViewController, AddEditTaskViewController, TaskDetailViewController) para trabalhar com operações assíncronas usando completion handlers ou async/await, implemente LoadingState enum com casos loading, loaded, error para gerenciar estados de interface durante operações assíncronas, adicione NetworkReachability para detectar conectividade (sem implementar serviço remoto), crie DataSyncManager preparado para sincronização futura com métodos stub para sync, conflictResolution e dataConflictStrategy, implemente error handling robusto com TaskError enum customizado incluindo casos para networkError, storageError, syncError e validationError, adicione logging básico com TaskLogger para debug de operações de dados, mantenha funcionalidades existentes (busca, filtros, ordenação, contador, modo escuro) adaptando-as para arquitetura assíncrona, preserve TaskTableViewCell customizada e Auto Layout, implemente indicadores visuais de loading e estados de erro na interface, adicione pull-to-refresh preparado para sincronização futura, configure dependency injection básico para facilitar testes unitários futuros, garanta backward compatibility mantendo dados existentes do UserDefaults durante migração, implemente cache inteligente com timestamp para otimizar performance, adicione documentação detalhada sobre a arquitetura em camadas e pontos de extensão para integração cloud, e assegure que o código permaneça totalmente funcional, bem estruturado, testável e siga melhores práticas de desenvolvimento iOS moderno com Swift incluindo proper error propagation, thread safety, memory management e experiência de usuário consistente mesmo durante transições assíncronas.

### c) Erros durante a compilação:

<img src="docs/assets/ToDoApp-Claude%20Modified-Erro-1.png" width="450" alt="Erro 1">

<img src="docs/assets/ToDoApp-Claude%20Modified-Erro-2.png" width="450" alt="Erro 2">

### d) Evidências

<img src="docs/assets/ToDoApp-Claude%20-%205.PNG" width="300" alt="Evidência 5">
