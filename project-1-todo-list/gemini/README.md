# ToDoApp - Gemini

Este repositório contém o aplicativo de lista de tarefas gerado utilizando Gemini como parte do trabalho de conclusão de curso (TCC).

## 1. App Inicial

### a) Prompt Utilizado:

Você é um especialista em desenvolvimento iOS. Crie um prompt que possa ser usado para gerar um aplicativo iOS em Swift que gerencie uma lista de tarefas simples, permitindo cadastro, listagem e exclusão de itens. O prompt deve instruir o modelo a produzir código funcional, legível e organizado, seguindo boas práticas de programação em Swift e utilizando armazenamento local em cache. Mantenha todo o prompt em uma única linha contínua, sem quebras de linha, e inclua todas as instruções necessárias para gerar o aplicativo corretamente.

### b) Prompt Gerado:

Crie um aplicativo iOS completo em Swift para gerenciamento de lista de tarefas. O aplicativo deve permitir ao usuário: adicionar novas tarefas (com um título), visualizar a lista de todas as tarefas cadastradas e excluir tarefas individualmente. O código deve ser funcional e legível, aderindo às boas práticas de programação em Swift, como a utilização de arquitetura de código clara (ex: MVC, MVVM) e nomes de variáveis e funções descritivos. Para persistência de dados, utilize armazenamento local em cache (como UserDefaults ou um arquivo local) em vez de um banco de dados. O projeto deve incluir uma interface de usuário simples e funcional para interagir com a lista. O prompt deve instruir o modelo a gerar todo o código necessário em um único bloco, começando com a estrutura do projeto e seguindo com cada arquivo de código, com comentários claros explicando as partes principais. O código gerado deve ser auto-suficiente e pronto para ser compilado e executado em um projeto Xcode.

### c) Erros durante a compilação:

Nenhum erro de compilação foi registrado para esta versão.

### d) Evidências:

<img src="docs/assets/ToDoApp-Gemini%20-%201.PNG" width="300" alt="Evidência 1">

<img src="docs/assets/ToDoApp-Gemini%20-%202.PNG" width="300" alt="Evidência 2">

<img src="docs/assets/ToDoApp-Gemini%20-%203.PNG" width="300" alt="Evidência 3">

## 2. App Após Modificações

### a) Prompt Utilizado:

Você é um especialista em desenvolvimento iOS. Crie um prompt que possa ser usado para modificar um aplicativo iOS de lista de tarefas previamente gerado. O prompt deve instruir o modelo a substituir o armazenamento local por uma camada de abstração preparada para integração futura com armazenamento em nuvem, mantendo a consistência, clareza e funcionalidade do código existente, sem implementar o serviço remoto. Mantenha todo o prompt em uma única linha contínua, sem quebras de linha, e inclua todas as instruções necessárias para gerar o aplicativo corretamente.

### b) Prompt Gerado:

Modifique um aplicativo iOS de lista de tarefas em Swift existente para substituir o armazenamento local por uma camada de abstração de dados. O objetivo é preparar a arquitetura para uma futura integração com armazenamento em nuvem, sem implementar o serviço remoto neste momento. O prompt deve instruir o modelo a: 1) Criar um novo protocolo, como TaskRepository, que defina as operações de CRUD (create, read, update, delete). 2) Criar uma classe de implementação para este protocolo, como LocalTaskRepository, que encapsule a lógica de armazenamento local (UserDefaults ou arquivo). 3) Atualizar a camada de ViewModel (ou a camada de lógica de negócios equivalente) para usar o novo protocolo em vez de interagir diretamente com o armazenamento local, injetando a dependência de LocalTaskRepository. 4) Garantir que o código continue funcional e legível, seguindo as boas práticas de programação em Swift (ex: Injeção de Dependência, Princípio de Inversão de Dependência) e mantendo a interface de usuário existente inalterada. 5) O prompt deve instruir o modelo a gerar todo o código modificado em um único bloco, com comentários claros explicando as mudanças e a nova arquitetura, tornando o código auto-suficiente e pronto para ser compilado e executado em um projeto Xcode.

### c) Erros durante a compilação:

Nenhum erro de compilação foi registrado para esta versão.

### d) Evidências:

<img src="docs/assets/ToDoApp-Gemini%20-%204.PNG" width="300" alt="Evidência 4">

<img src="docs/assets/ToDoApp-Gemini%20-%205.PNG" width="300" alt="Evidência 5">

<img src="docs/assets/ToDoApp-Gemini%20-%206.PNG" width="300" alt="Evidência 6">

