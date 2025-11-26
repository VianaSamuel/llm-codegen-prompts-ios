# CatAPI - Claude

Este repositório contém o aplicativo CatAPI gerado utilizando Claude como parte do trabalho de conclusão de curso (TCC).

## 1. App Inicial

### a) Prompt Utilizado:

Você é um especialista em desenvolvimento iOS. Crie um prompt que possa ser usado para gerar um aplicativo iOS em Swift que consuma dados da API pública The Cat API (https://thecatapi.com/), exibindo imagens e informações relacionadas a gatos. O prompt deve instruir o modelo a produzir código funcional, legível e organizado, seguindo boas práticas de programação em Swift e com arquitetura facilmente adaptável. Mantenha todo o prompt em uma única linha contínua, sem quebras de linha, e inclua todas as instruções necessárias para gerar o aplicativo corretamente.

### b) Prompt Gerado:

Crie um aplicativo iOS completo em Swift para consumir dados da API pública The Cat API (https://thecatapi.com/) exibindo imagens e informações sobre gatos com as seguintes especificações: desenvolva usando UIKit com arquitetura MVVM, implemente modelos de dados Cat com propriedades id (String), url (String), width (Int), height (Int), breeds (array opcional de Breed), categories (array opcional de Category) e Breed com propriedades id, name, description, temperament, origin, life_span, weight, energy_level, all_traits seguindo estrutura da API e conformidade com Codable, crie NetworkManager como singleton para gerenciar requisições HTTP usando URLSession com métodos fetchRandomCats, fetchCatsByBreed, fetchBreeds, fetchCategories implementando tratamento de erros customizado CatAPIError, cache de imagens básico e rate limiting, desenvolva CatService como camada de serviço que abstraia chamadas de rede e forneça interface limpa para ViewModels com operações assíncronas usando async/await e Result types, implemente CatsListViewModel para gerenciar estado da lista principal com propriedades observáveis usando @Published ou Observable pattern, LoadingState enum, paginação automática, filtros por raça/categoria e refresh functionality, crie CatsListViewController como tela principal com UICollectionView em grid layout exibindo imagens dos gatos, pull-to-refresh, infinite scroll, barra de busca com filtros por raça, loading indicators e tratamento de estados vazios/erro, desenvolva CatCollectionViewCell customizada com UIImageView para foto do gato, labels para informações básicas, indicador de loading durante carregamento da imagem e placeholder para erro de carregamento, implemente CatDetailViewModel e CatDetailViewController para tela de detalhes com imagem em tamanho maior, scroll view com informações completas sobre raças, características, origem, temperamento, botões para salvar favoritos e compartilhar imagem, crie ImageCache manager para otimizar carregamento e armazenamento de imagens usando NSCache com download assíncrono, redimensionamento automático e placeholder durante loading, desenvolva FavoritesManager usando UserDefaults para persistir gatos favoritos com funcionalidades de adicionar, remover, listar e verificar se é favorito, implemente FavoritesViewController com lista de gatos salvos e opção de remover favoritos, adicione SettingsViewController com opções para número de colunas na grid, qualidade de imagem (thumbnail/original), modo escuro e clear cache, configure navegação com UITabBarController contendo abas para Lista, Favoritos e Configurações ou UINavigationController com segues apropriados, implemente tratamento robusto de erros de rede com retry automático, timeouts configuráveis e alerts informativos para usuário, adicione suporte completo a modo escuro, Auto Layout responsivo para diferentes tamanhos de tela incluindo iPad, accessibility labels e VoiceOver, animações suaves para transições e carregamento de imagens, use dependency injection para facilitar testes unitários, implemente testes básicos para NetworkManager e ViewModels, configure Info.plist com permissões de rede e App Transport Security, adicione Launch Screen com tema de gatos e ícone do aplicativo apropriado, garanta performance otimizada com lazy loading de imagens, cell reuse adequado, background processing para downloads e memory warnings handling, implemente funcionalidades extras como busca por texto livre, filtros avançados por características da raça, galeria com zoom e pan gestures, compartilhamento de imagens via UIActivityViewController, e assegure que o código seja totalmente funcional, bem arquitetado, facilmente testável e extensível, seguindo melhores práticas de desenvolvimento iOS moderno com Swift incluindo proper error handling, async programming patterns, memory management, code organization e user experience intuitiva e responsiva.

### c) Erros durante a compilação:

<img src="docs/assets/CatAPI-Claude%20Erro-1.png" width="450" alt="Erro 1">

### d) Evidências:

<img src="docs/assets/CatAPI-Claude%20-%201.PNG" width="300" alt="Evidência 1">

<img src="docs/assets/CatAPI-Claude%20-%202.PNG" width="300" alt="Evidência 2">

<img src="docs/assets/CatAPI-Claude%20-%203.PNG" width="300" alt="Evidência 3">

<img src="docs/assets/CatAPI-Claude%20-%204.PNG" width="300" alt="Evidência 4">

## 2. App Após Modificações

### a) Prompt Utilizado:

Você é um especialista em desenvolvimento iOS. Crie um prompt que possa ser usado para modificar um aplicativo iOS previamente gerado que consome dados da The Cat API (https://thecatapi.com/). O prompt deve instruir o modelo a alterar a arquitetura do projeto de MVVM para VIPER, mantendo a consistência, funcionalidade e clareza do código existente, sem alterar a lógica de negócios nem os dados da API. Mantenha todo o prompt em uma única linha contínua, sem quebras de linha, e inclua todas as instruções necessárias para gerar o aplicativo corretamente.

### b) Prompt Gerado:

Modifique o aplicativo iOS existente que consome dados da The Cat API (https://thecatapi.com/) alterando a arquitetura de MVVM para VIPER mantendo toda funcionalidade e lógica de negócios existentes: preserve os modelos de dados Cat e Breed com suas propriedades e conformidade Codable, mantenha NetworkManager e CatService inalterados como camadas de infraestrutura, refatore cada módulo (CatsList, CatDetail, Favorites, Settings) seguindo padrão VIPER com View (UIViewController), Interactor (lógica de negócios), Presenter (mediador entre View e Interactor), Entity (modelos de dados), Router (navegação), implemente CatsListView (CatsListViewController) mantendo UICollectionView, pull-to-refresh, infinite scroll e interface existente mas removendo referências diretas a ViewModel, crie CatsListInteractor responsável por operações de negócio como fetchCats, applyFilters, handlePagination, manageFavorites usando CatService e NetworkManager existentes, desenvolva CatsListPresenter como mediador implementando protocolos CatsListViewProtocol e CatsListInteractorOutputProtocol, gerenciando formatação de dados para exibição, tratamento de estados (loading, loaded, error, empty) e comunicação bidirecional entre View e Interactor, implemente CatsListRouter para navegação entre módulos com métodos pushToCatDetail, presentSettings, showErrorAlert mantendo navegação existente, defina protocolos claros CatsListViewProtocol (showCats, showLoading, showError, refreshUI), CatsListInteractorInputProtocol (fetchRandomCats, searchCats, toggleFavorite), CatsListInteractorOutputProtocol (didFetchCats, didFailWithError, didUpdateFavoriteStatus) e CatsListRouterProtocol (navigateToDetail, presentSettings), aplique mesmo padrão VIPER para CatDetailModule preservando funcionalidades de zoom, compartilhamento, favoritos com CatDetailView, CatDetailInteractor, CatDetailPresenter, CatDetailRouter e protocolos correspondentes, refatore FavoritesModule mantendo lista de favoritos e remoção com FavoritesView, FavoritesInteractor, FavoritesPresenter, FavoritesRouter seguindo mesma estrutura, transforme SettingsModule preservando opções de configuração com SettingsView, SettingsInteractor, SettingsPresenter, SettingsRouter, implemente ModuleBuilder/Assembly pattern para criar e configurar cada módulo VIPER com dependency injection apropriado, mantenha ImageCache, FavoritesManager e todos os serviços de infraestrutura inalterados como dependências injetadas nos Interactors, preserve tratamento de erros existente adaptando para comunicação via protocolos entre camadas VIPER, mantenha funcionalidades como busca, filtros, paginação, cache de imagens, favoritos, configurações, modo escuro, accessibility adaptando apenas a comunicação entre componentes, implemente testes unitários para cada camada VIPER especialmente Presenters e Interactors usando mocks dos protocolos, mantenha Auto Layout, animações, performance otimizada e user experience existentes, preserve Launch Screen, ícones e configurações do projeto, garanta que a migração seja transparente para o usuário final mantendo toda funcionalidade, visual e comportamento idênticos, organize arquivos em pastas por módulo seguindo estrutura VIPER (Modules/CatsList/View, Modules/CatsList/Interactor, etc.), adicione documentação explicando arquitetura VIPER implementada e responsabilidades de cada camada, e assegure que o código permaneça totalmente funcional, bem estruturado, testável e siga melhores práticas de desenvolvimento iOS com Swift incluindo proper protocol-oriented programming, dependency injection, separation of concerns e clean architecture principles.

### c) Erros durante a compilação:

Nenhum erro foi encontrado durante a compilação após as modificações.

### d) Evidências:

<img src="docs/assets/CatAPI-Claude%20-%205.PNG" width="300" alt="Evidência 5">

<img src="docs/assets/CatAPI-Claude%20-%206.PNG" width="300" alt="Evidência 6">

<img src="docs/assets/CatAPI-Claude%20-%207.PNG" width="300" alt="Evidência 7">

