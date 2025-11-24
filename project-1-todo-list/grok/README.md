# ToDoApp - Grok

Este repositório contém o aplicativo de lista de tarefas gerado utilizando Grok como parte do trabalho de conclusão de curso (TCC).

## 1. App Inicial

### a) Prompt Utilizado:

Você é um especialista em desenvolvimento iOS. Crie um prompt que possa ser usado para gerar um aplicativo iOS em Swift que gerencie uma lista de tarefas simples, permitindo cadastro, listagem e exclusão de itens. O prompt deve instruir o modelo a produzir código funcional, legível e organizado, seguindo boas práticas de programação em Swift e utilizando armazenamento local em cache. Mantenha todo o prompt em uma única linha contínua, sem quebras de linha, e inclua todas as instruções necessárias para gerar o aplicativo corretamente.

### b) Prompt Gerado:

You are an AI code generator specialized in iOS development. Generate a complete, functional iOS app in Swift for managing a simple to-do list, allowing users to add new tasks, list existing tasks, and delete tasks. The app should use a single view controller with a UITableView to display the tasks, a text field and button to add new tasks, and swipe-to-delete functionality for removing tasks. Store the tasks persistently using UserDefaults for local caching, ensuring data is saved and loaded correctly. Structure the code following best practices: use MVC pattern, include proper error handling, make it readable with comments, use SwiftUI if possible but fall back to UIKit if needed for simplicity, organize into sections like imports, model, view controller, and extensions. Provide the full Xcode-compatible code, including AppDelegate if necessary, and ensure it's compilable and runs on iOS 15+. Do not include any explanations outside the code; output only the Swift code files.

### c) Evidências

<img src="docs/assets/ToDoApp-Grok%20-%201.PNG" width="300" alt="Evidência 1">

<img src="docs/assets/ToDoApp-Grok%20-%202.PNG" width="300" alt="Evidência 2">

<img src="docs/assets/ToDoApp-Grok%20-%203.PNG" width="300" alt="Evidência 3">

## 2. App Após Modificações

### a) Prompt Utilizado:

Você é um especialista em desenvolvimento iOS. Crie um prompt que possa ser usado para modificar um aplicativo iOS de lista de tarefas previamente gerado. O prompt deve instruir o modelo a substituir o armazenamento local por uma camada de abstração preparada para integração futura com armazenamento em nuvem, mantendo a consistência, clareza e funcionalidade do código existente, sem implementar o serviço remoto. Mantenha todo o prompt em uma única linha contínua, sem quebras de linha, e inclua todas as instruções necessárias para gerar o aplicativo corretamente.

### b) Prompt Gerado:

You are an AI code generator specialized in iOS development. Modify an existing iOS to-do list app in Swift, previously generated with UserDefaults for local storage, to replace the storage mechanism with an abstracted storage layer designed for future cloud integration. Create a protocol-based storage abstraction (e.g., TaskStorageProtocol) with methods for adding, listing, and deleting tasks, and implement a concrete local storage class (e.g., LocalTaskStorage) using UserDefaults to maintain current functionality. Ensure the abstraction is flexible for future cloud storage integration without implementing remote services. Update the existing view controller to use this new storage layer while preserving the app’s functionality (adding, listing, and deleting tasks via a UITableView with a text field, button, and swipe-to-delete). Maintain the MVC pattern, ensure code is readable with comments, use SwiftUI if the original app used it (otherwise UIKit), and keep all existing features intact. Provide the full Xcode-compatible code, including any necessary updates to AppDelegate or other files, ensuring it compiles and runs on iOS 15+. Do not include explanations outside the code; output only the modified Swift code files with the same artifact_id as the original app if provided, or a new UUID if not.

### c) Evidências

<img src="docs/assets/ToDoApp-Grok%20-%204.PNG" width="300" alt="Evidência 4">

<img src="docs/assets/ToDoApp-Grok%20-%205.PNG" width="300" alt="Evidência 5">

<img src="docs/assets/ToDoApp-Grok%20-%206.PNG" width="300" alt="Evidência 6">

