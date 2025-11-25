# CatAPI - Gemini

Este repositório contém o aplicativo CatAPI gerado utilizando Gemini como parte do trabalho de conclusão de curso (TCC).

## 1. App Inicial

### a) Prompt Utilizado:

Você é um especialista em desenvolvimento iOS. Crie um prompt que possa ser usado para gerar um aplicativo iOS em Swift que consuma dados da API pública The Cat API (https://thecatapi.com/), exibindo imagens e informações relacionadas a gatos. O prompt deve instruir o modelo a produzir código funcional, legível e organizado, seguindo boas práticas de programação em Swift e com arquitetura facilmente adaptável. Mantenha todo o prompt em uma única linha contínua, sem quebras de linha, e inclua todas as instruções necessárias para gerar o aplicativo corretamente.

### b) Prompt Gerado:

Crie um aplicativo iOS completo em Swift para consumir e exibir dados da API pública The Cat API. O aplicativo deve: 1) Realizar requisições assíncronas para a API (/v1/images/search) para buscar imagens de gatos. 2) Decodificar as respostas JSON em modelos de dados Swift (Codable). 3) Exibir as imagens e informações relevantes (ex: raça, se disponível) em uma UICollectionView ou UITableView. 4) Implementar uma arquitetura de código robusta e escalável, como MVVM, separando claramente a View (UI), o ViewModel (lógica de negócios) e o Model (dados). 5) Gerenciar o ciclo de vida das requisições e o carregamento de imagens de forma eficiente e segura, lidando com erros de rede. 6) O prompt deve instruir o modelo a gerar todo o código necessário em um único bloco, começando com a estrutura do projeto e seguindo com cada arquivo de código, com comentários claros explicando as partes principais e a interconexão entre as camadas da arquitetura. O código gerado deve ser auto-suficiente e pronto para ser compilado e executado em um projeto Xcode, após a configuração da chave da API, se necessário.

### c) Erros durante a compilação:

Nenhum erro de compilação foi registrado para esta versão.

### d) Evidências:

<img src="docs/assets/CatAPI-Gemini%20-%201.PNG" width="300" alt="Evidência 1 (App inicial)">

<img src="docs/assets/CatAPI-Gemini%20-%202.PNG" width="300" alt="Evidência 2 (App inicial)">

## 2. App Após Modificações

### a) Prompt Utilizado:

Você é um especialista em desenvolvimento iOS. Crie um prompt que possa ser usado para modificar um aplicativo iOS previamente gerado que consome dados da The Cat API (https://thecatapi.com/). O prompt deve instruir o modelo a alterar a arquitetura do projeto de MVVM para VIPER, mantendo a consistência, funcionalidade e clareza do código existente, sem alterar a lógica de negócios nem os dados da API. Mantenha todo o prompt em uma única linha contínua, sem quebras de linha, e inclua todas as instruções necessárias para gerar o aplicativo corretamente.

### b) Prompt Gerado:

Modifique um aplicativo iOS existente em Swift que consome a API The Cat API, alterando a arquitetura do projeto de MVVM para VIPER. O prompt deve instruir o modelo a: 1) Manter a funcionalidade e os dados da API inalterados. 2) Reestruturar o projeto criando os módulos VIPER (View, Interactor, Presenter, Entity, Router) para a tela principal (listagem de gatos). 3) Garantir que a View apenas exiba o que o Presenter determinar e informe ao Presenter as ações do usuário. 4) Fazer com que o Presenter concentre a lógica de apresentação e formate os dados recebidos do Interactor. 5) Definir o Interactor como responsável pela lógica de negócio, incluindo as requisições à API. 6) Manter as Entities representando os dados (por exemplo, CatImage). 7) Usar o Router para gerenciar a navegação. 8) Seguir boas práticas da arquitetura VIPER, com protocolos delineando a comunicação entre camadas. 9) Gerar todo o código atualizado em um único bloco, com comentários explicando as alterações e garantindo que o projeto permaneça pronto para compilação no Xcode.

### c) Erros durante a compilação:

Nenhum erro de compilação foi registrado para esta versão.

### d) Evidências:

<img src="docs/assets/CatAPI-Gemini%20-%203.PNG" width="300" alt="Evidência 3 (App modificado)">

<img src="docs/assets/CatAPI-Gemini%20-%204.PNG" width="300" alt="Evidência 4 (App modificado)">

