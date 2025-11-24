# ToDoApp - ChatGPT

Este repositório contém o aplicativo de lista de tarefas gerado utilizando ChatGPT como parte do trabalho de conclusão de curso (TCC).

## 1. App Inicial

### a) Prompt Utilizado:

Você é um especialista em desenvolvimento iOS. Crie um prompt que possa ser usado para gerar um aplicativo iOS em Swift que gerencie uma lista de tarefas simples, permitindo cadastro, listagem e exclusão de itens. O prompt deve instruir o modelo a produzir código funcional, legível e organizado, seguindo boas práticas de programação em Swift e utilizando armazenamento local em cache. Mantenha todo o prompt em uma única linha contínua, sem quebras de linha, e inclua todas as instruções necessárias para gerar o aplicativo corretamente.

### b) Prompt Gerado:

Crie um aplicativo iOS completo em Swift que gerencie uma lista de tarefas simples. O aplicativo deve permitir ao usuário cadastrar novas tarefas, listar todas as tarefas existentes e excluir tarefas individuais. O código deve ser funcional, organizado, legível e seguir boas práticas de programação em Swift, incluindo separação de responsabilidades, uso de structs ou classes apropriadas, e comentários claros explicando as partes principais. Utilize armazenamento local em cache (UserDefaults ou similar) para persistir os dados entre execuções do app. A interface pode ser construída com SwiftUI ou UIKit, mas deve ser simples e intuitiva, mostrando a lista de tarefas e oferecendo botões ou gestos para adicionar e remover tarefas. Inclua validações básicas, como impedir o cadastro de tarefas vazias, e assegure que a lista atualize dinamicamente após inclusão ou exclusão de itens. Gere todo o código necessário para que o aplicativo funcione ao ser compilado, incluindo modelos de dados, view models, views e lógica de persistência, sem depender de bibliotecas externas.

### c) Evidências:

<img src="docs/assets/ToDoApp-GPT%20-%201.PNG" width="300" alt="Evidência 1">

<img src="docs/assets/ToDoApp-GPT%20-%202.PNG" width="300" alt="Evidência 2">

<img src="docs/assets/ToDoApp-GPT%20-%203.PNG" width="300" alt="Evidência 3">

<img src="docs/assets/ToDoApp-GPT%20-%204.PNG" width="300" alt="Evidência 4">

## 2. App Após Modificações

### a) Prompt Utilizado:

Você é um especialista em desenvolvimento iOS. Crie um prompt que possa ser usado para modificar um aplicativo iOS de lista de tarefas previamente gerado. O prompt deve instruir o modelo a substituir o armazenamento local por uma camada de abstração preparada para integração futura com armazenamento em nuvem, mantendo a consistência, clareza e funcionalidade do código existente, sem implementar o serviço remoto. Mantenha todo o prompt em uma única linha contínua, sem quebras de linha, e inclua todas as instruções necessárias para gerar o aplicativo corretamente.

### b) Prompt Gerado:

Crie uma versão modificada de um aplicativo iOS de lista de tarefas previamente gerado em Swift, substituindo o armazenamento local atual por uma camada de abstração que gerencie a persistência de dados, de forma que a aplicação continue funcionando corretamente com cadastro, listagem e exclusão de tarefas, mantendo toda a lógica, clareza e organização do código existente, sem implementar integração com serviço remoto, mas estruturando a camada de persistência de modo que futuras integrações com armazenamento em nuvem possam ser feitas facilmente, incluindo protocolos ou classes de repositório, métodos assíncronos simulando operações de leitura e escrita, garantindo que a interface continue atualizando dinamicamente após alterações nos dados, preservando boas práticas de Swift, separação de responsabilidades, comentários claros explicativos e mantendo a funcionalidade completa do aplicativo ao ser compilado.

### c) Evidências

<img src="docs/assets/ToDoApp-GPT%20-%205.PNG" width="300" alt="Evidência 5">

<img src="docs/assets/ToDoApp-GPT%20-%206.PNG" width="300" alt="Evidência 6">

<img src="docs/assets/ToDoApp-GPT%20-%207.PNG" width="300" alt="Evidência 7">
