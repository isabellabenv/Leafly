import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseCore
import FirebaseDatabase
import FirebaseFirestore
import FirebaseStorage
import Combine

class AuthManager: ObservableObject { // ObservableObject that manages Firebase authentication state
    @Published var isAuthenticated: Bool = false // Published property that updates the UI when authentication state changes
    private var authHandle: AuthStateDidChangeListenerHandle?  // Handle for the Firebase auth state listener so it can be removed later

    init() {
        setupAuthStateListener()
    } // Initializer sets up the auth state listener

    deinit {
        if let handle = authHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }  // Clean up the listener when the object is deallocated

    private func setupAuthStateListener() {  // Sets up a listener that triggers whenever authentication state changes
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            guard let self = self else { return }
            DispatchQueue.main.async {  // Ensure updates happen on the main thread (UI updates)
                self.isAuthenticated = (user != nil) // User is authenticated if 'user' is not nil
                print("Auth state changed. User authenticated: \(self.isAuthenticated)")
                if self.isAuthenticated {  // Log current user’s email if authenticated
                    print("Current user: \(user?.email ?? "N/A")")
                }
            }
        }
    }

    func signOut() { // Logs out the current user
        do {
            try Auth.auth().signOut()
        } catch let signOutError as NSError {
            print("Error signing out: %@", signOutError)
        }
    }
}

@main
struct LeaflyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate  // App delegate for Firebase configuration
    @StateObject var authManager = AuthManager()  // Authentication manager stored as a StateObject to persist across view updates

    class AppDelegate: NSObject, UIApplicationDelegate {  // AppDelegate handles app lifecycle events
        func application(_ application: UIApplication,
                         didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
            FirebaseApp.configure()  // Configure Firebase
            Database.database().isPersistenceEnabled = true  // Enable offline persistence for Firebase Realtime Database
            print("Firebase has been configured!")
            return true
        }
    }

    var body: some Scene {
        
        WindowGroup {
            if authManager.isAuthenticated {
                // If authenticated, show profileView
                ProfileView()
                    .environmentObject(authManager) // Inject authManager into environment
            } else {
                // If not authenticated, show ContentView (login screen)
                ContentView()
                    .environmentObject(authManager) // Inject authManager into environment
            }
        }
    }
}
