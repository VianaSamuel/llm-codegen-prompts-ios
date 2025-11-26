# CatAPI - Grok

Este repositório contém o aplicativo CatAPI gerado utilizando Grok como parte do trabalho de conclusão de curso (TCC).

## 1. App Inicial

### a) Prompt Utilizado:

Você é um especialista em desenvolvimento iOS. Crie um prompt que possa ser usado para gerar um aplicativo iOS em Swift que consuma dados da API pública The Cat API (https://thecatapi.com/), exibindo imagens e informações relacionadas a gatos. O prompt deve instruir o modelo a produzir código funcional, legível e organizado, seguindo boas práticas de programação em Swift e com arquitetura facilmente adaptável. Mantenha todo o prompt em uma única linha contínua, sem quebras de linha, e inclua todas as instruções necessárias para gerar o aplicativo corretamente.

### b) Prompt Gerado:

You are an AI code generator specialized in iOS development. Generate a complete, functional iOS app in Swift that consumes data from The Cat API, specifically fetching a list of cat breeds and displaying them in a list view, allowing users to select a breed to view detailed information including name, description, temperament, and a random image for that breed. Use SwiftUI for the user interface, async/await for networking with URLSession, proper JSON decoding with Codable structs for breeds and images, implement error handling with alerts for network failures, ensure the architecture follows MVVM pattern for adaptability (with a ViewModel managing data fetching and state), make the code readable with comments, organized into sections like imports, models, view models, views, and app entry point, support light/dark mode, and ensure it's compatible with iOS 15+. Provide the full Xcode-compatible code in a single Swift file if possible, or multiple if necessary, but output only the Swift code without any explanations outside the code.

### c) Erros durante a compilação:

Nenhum erro foi encontrado durante a compilação do aplicativo inicial.

### d) Evidências:

<img src="docs/assets/CatAPI-Grok%20-%201.PNG" width="300" alt="Evidência 1">

<img src="docs/assets/CatAPI-Grok%20-%202.PNG" width="300" alt="Evidência 2">

## 2. App Após Modificações

### a) Prompt Utilizado:

Você é um especialista em desenvolvimento iOS. Crie um prompt que possa ser usado para modificar um aplicativo iOS previamente gerado que consome dados da The Cat API (https://thecatapi.com/). O prompt deve instruir o modelo a alterar a arquitetura do projeto de MVVM para VIPER, mantendo a consistência, funcionalidade e clareza do código existente, sem alterar a lógica de negócios nem os dados da API. Mantenha todo o prompt em uma única linha contínua, sem quebras de linha, e inclua todas as instruções necessárias para gerar o aplicativo corretamente.

### b) Prompt Gerado:

You are an AI code generator specialized in iOS development. Modify an existing iOS app in Swift that consumes data from The Cat API, previously built with MVVM architecture, to use the VIPER architecture instead, while preserving all existing functionality (fetching and displaying a list of cat breeds with name, description, temperament, and a random image per breed, using SwiftUI, async/await with URLSession, Codable for JSON decoding, and error handling with alerts). Restructure the codebase to follow VIPER principles: create distinct modules for View (SwiftUI views), Interactor (business logic and API calls), Presenter (view logic and data formatting), Entity (data models), and Router (navigation). Ensure the code remains readable with comments, organized into separate files for each VIPER component, maintains light/dark mode support, and is compatible with iOS 15+. Update all necessary files, including the app entry point, to reflect the new architecture without altering the business logic or API data handling. Use the same artifact_id as the original app if provided, or assign a new UUID if not. Output only the Swift code files without explanations outside the code.

### c) Erros durante a compilação:

<img src="docs/assets/CatAPI-Grok%20Modified-Erro-1.png" width="450" alt="Erro 1">

### d) Evidências:

<img src="docs/assets/CatAPI-Grok%20-%203.PNG" width="300" alt="Evidência 3">

<img src="docs/assets/CatAPI-Grok%20-%204.PNG" width="300" alt="Evidência 4">


