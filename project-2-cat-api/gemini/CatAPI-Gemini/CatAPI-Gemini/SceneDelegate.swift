import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        // 1. Garantir que a cena é uma UIWindowScene
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // 2. Cria a janela principal usando a cena
        let window = UIWindow(windowScene: windowScene)
        
        // 3. Cria o ViewController raiz (CatListViewController)
        // Certifique-se de que este arquivo também está no seu projeto.
        let rootVC = CatListViewController()
        
        // 4. Empacota o VC em um UINavigationController para gerenciar a barra de título
        let navigationController = UINavigationController(rootViewController: rootVC)
        
        // 5. Define o NavigationController como o controlador raiz da janela
        window.rootViewController = navigationController
        
        // 6. Define a janela e a torna visível
        self.window = window
        window.makeKeyAndVisible()
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Deixe o restante das funções como estão, pois são métodos de ciclo de vida.
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        
    }
    
}
