//
//  testApp.swift
//  test
//
//  Created by Isabella Benvenuto on 2/6/2025.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseCore
import Combine

class AuthManager: ObservableObject { // <-- This is the definition the compiler is looking for!
    @Published var isAuthenticated: Bool = false
    private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        setupAuthStateListener()
    }

    deinit {
        if let handle = authHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    private func setupAuthStateListener() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isAuthenticated = (user != nil)
                print("Auth state changed. User authenticated: \(self.isAuthenticated)")
                if self.isAuthenticated {
                    print("Current user: \(user?.email ?? "N/A")")
                }
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch let signOutError as NSError {
            print("Error signing out: %@", signOutError)
        }
    }
}

@main
struct LeaflyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject var authManager = AuthManager()

    class AppDelegate: NSObject, UIApplicationDelegate {
        func application(_ application: UIApplication,
                         didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
            FirebaseApp.configure()
            print("Firebase has been configured!")
            return true
        }
    }

    var body: some Scene {
        
        WindowGroup {
            if authManager.isAuthenticated {
                // If authenticated, show your main app content
                ContentView()
                    // ⭐ Ensure you provide the environment object to the entire view hierarchy
                    .environmentObject(authManager)
            } else {
                // If not authenticated, show the LoginView
                // ⭐ No argument needed here, as LoginView now uses @EnvironmentObject
                ContentView()
                    // ⭐ Also provide it here, so LoginView can access it
                    .environmentObject(authManager)
            }
        }
    }
}

