//
//  ContentView.swift
//  test
//
//  Created by Isabella Benvenuto on 2/6/2025.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseCore

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    FirebaseApp.configure()
    return true
}




struct ContentView: View {
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        NavigationView {
            ZStack {
                // Gradient background
                RadialGradient(colors: [Color.palegreen, Color.ggreen], center: .center, startRadius: 100, endRadius: 350)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Logo
                    Image("leafly")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 400, height: 150)
                    
                    // Form Container
                    VStack(spacing: 20) {
                        
                        // TextFields
                        TextField("Username…", text: $email)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                        
                        SecureField("Password…", text: $password)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                        
                        // Log in button
                        Button(action: {
                            signInUser()
                        }) {
                            Text("Log in")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.ggreen)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        
                        // Forgot password and Sign up links
                        VStack(spacing: 10) {
                            NavigationLink(destination: forgotpassword()) {
                                Text("Forgot your password?")
                                    .foregroundColor(.gray)
                                    .underline()
                            }
                            NavigationLink(destination: SignupView()) {
                                Text("Don’t have an account yet?")
                                    .foregroundColor(.gray)
                                    .underline()
                            }
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(25)
                    .padding(.horizontal)
                }
            }
        }
    }
    private func signInUser() {
            guard !email.isEmpty, !password.isEmpty else {
                alertMessage = "Please enter both email and password."
                showingAlert = true
                return
            }

            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                if let error = error {
                    print("Error signing in: \(error.localizedDescription)")
                    alertMessage = error.localizedDescription
                    showingAlert = true
                } else {
                    print("User successfully logged in! AuthManager's listener will update.")
                    // No need to directly set authManager.isAuthenticated here;
                    // the `AuthManager`'s internal listener (in its init) will detect
                    // the sign-in and automatically update its @Published isAuthenticated.
                }
            }
    }
}

struct SignupView: View {
    // State variables to hold the text field input
    @State private var email = ""
    @State private var password = ""

    // State variable to hold any error message for display
    @State private var errorMessage: String?

    // State variable to indicate success (e.g., to trigger navigation)
    @State private var isSignupSuccessful = false
    
    var body: some View {
        NavigationView{
            ZStack {
                RadialGradient(colors: [Color.palegreen, Color.ggreen], center: .center, startRadius: 100, endRadius: 350)
                    .ignoresSafeArea()
                VStack {
                    Image("leafly")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 400, height: 150)
                    VStack(spacing: 20) {
                        
                        Text("Create Account")
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                        
                        TextField("Email", text: $email)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                        
                        SecureField("Password", text: $password) // Use SecureField for passwords
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                        
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .padding(.top, 5)
                        }
                        
                        Button("Sign Up") {
                            // Action to perform when the button is tapped
                            signupUser()
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.ggreen)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .disabled(email.isEmpty || password.isEmpty) // Disable button if fields are empty
                        
                        // Optional: Navigate on success (example using a simple state check)
                        .fullScreenCover(isPresented: $isSignupSuccessful) {
                            // Present your next view here
                            successView() // Replace with your actual success view/dashboard
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(25)
                    .padding(.horizontal)
                }
            }
        }
    }
    
    struct successView: View {
        @State private var returntologin = false
        var body: some View {
                ZStack{
                RadialGradient(colors: [Color.palegreen, Color.ggreen], center: .center, startRadius: 100, endRadius: 350)
                            .ignoresSafeArea()

                    VStack{
                        Button("Return to login") {
                            returntologin.toggle()
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.ggreen)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .fullScreenCover(isPresented: $returntologin) {
                            ContentView()
                        }
                        }
                    }
                }
        }

    // Function to handle the signup process using Firebase Auth
    private func signupUser() {
        // Clear previous error message
        errorMessage = nil

        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            // This block runs when the signup attempt is complete

            if let error = error {
                // Handle the error. Update the state to show the error message.
                print("Error signing up: \(error.localizedDescription)")
                self.errorMessage = error.localizedDescription // Update the UI state

                // You can check specific AuthError codes here too, like in the UIKit example
                // let authError = error as NSError
                // if authError.code == AuthErrorCode.emailAlreadyInUse.rawValue { ... }

            } else {
                // Signup was successful!
                print("Successfully signed up user!")

                // Update the state to trigger success UI or navigation
                self.isSignupSuccessful = true

                // The user is automatically signed in upon successful creation
                // You can access the user via Auth.auth().currentUser if needed
                if let user = result?.user {
                    print("New user UID: \(user.uid)")
                     // Potentially save more user data to Firestore here
                }
            }
        }
    }
}



// How you might preview this view
struct SignupView_Previews: PreviewProvider {
    static var previews: some View {
        SignupView()
    }
}

#Preview {
    ContentView()
}
