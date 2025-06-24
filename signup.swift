//
//  homePage.swift
//  test
//
//  Created by Isabella Benvenuto on 19/6/2025.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseCore


struct signupView: View {
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
                            ContentView() // Replace with your actual success view/dashboard
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(25)
                    .navigationTitle("Sign Up")
                    .padding(.horizontal)
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
struct signupView_Previews: PreviewProvider {
    static var previews: some View {
        // Important: Make sure FirebaseApp.configure() has been called elsewhere
        // before this view is actually used in your app lifecycle (e.g., in your App struct).
        signupView()
    }
}


#Preview {
    signupView()
}
