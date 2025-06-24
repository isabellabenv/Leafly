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

@main
struct testApp: App {
    init() {
        FirebaseApp.configure()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
