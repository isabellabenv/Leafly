//
//  homePage.swift
//  test
//
//  Created by Isabella Benvenuto on 19/6/2025.
//

import SwiftUI

struct forgotpassword: View {
    
    @State private var email = ""
    
    // State variable to hold any error message for display
    @State private var errorMessage: String?
    
    // State variable to indicate success (e.g., to trigger navigation)
    @State private var isRequestSuccessful = false
    
    var body: some View {
        ZStack {
            RadialGradient(colors: [Color.palegreen, Color.ggreen], center: .center, startRadius: 100, endRadius: 350)
                .ignoresSafeArea()
            VStack {
                Image("leafly")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 400, height: 150)
                VStack(spacing: 20) {
                    
                    Text("Forgot password")
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                    
                    TextField("Email", text: $email)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                    
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding(.top, 5)
                    }
                    
                    Button("Reset password") {
                        // Action to perform when the button is tapped
                        
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.ggreen)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .disabled(email.isEmpty) // Disable button if fields are empty
                    
                    // Optional: Navigate on success (example using a simple state check)
                    .fullScreenCover(isPresented: $isRequestSuccessful) {
                        // Present your next view here
                        Text("Request sent successfully!")
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(25)
                .navigationTitle("Forgot password")
                .padding(.horizontal)
            }
        }
    }
}
#Preview {
    forgotpassword()
}
