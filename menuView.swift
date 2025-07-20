import SwiftUI
import FirebaseAuth
import FirebaseDatabase
import FirebaseFirestore
import FirebaseDatabaseInternal

struct MenuView: View {
    @State private var username: String = ""
        @State private var email: String = ""
        @State private var showSettings = false
        @State private var isLoggedOut = false

        var body: some View {
            NavigationView {
                VStack(spacing: 30) {
                    
                    // MARK: - User Info Section
                    VStack {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.ggreen)

                        Text(username)
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(email)
                            .foregroundColor(.gray)
                            .font(.subheadline)
                    }

                    // MARK: - Settings Navigation
                    Button {
                        showSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "gearshape.fill")
                            Text("Settings")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 3)
                    }
                    .padding(.horizontal)
                    .sheet(isPresented: $showSettings) {
                        //settings
                    }

                    // MARK: - Log Out
                    Button(action: {
                        logOut()
                    }) {
                        HStack {
                            Image(systemName: "arrow.backward.circle.fill")
                            Text("Log Out")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.9))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)

                    Spacer()
                }
                .padding()
                .onAppear {
                    loadUserData()
                }
                .fullScreenCover(isPresented: $isLoggedOut) {
                    ContentView() // Your login screen
                }
                .navigationTitle("Menu")
                .navigationBarTitleDisplayMode(.inline)
            }
        }

        // MARK: - Load User Info from Firebase
        func loadUserData() {
            guard let uid = Auth.auth().currentUser?.uid else { return }
            let ref = Database.database().reference().child("users").child(uid)

            ref.observeSingleEvent(of: .value) { snapshot in
                if let value = snapshot.value as? [String: Any] {
                    self.username = value["username"] as? String ?? "Unknown"
                    self.email = value["email"] as? String ?? "No Email"
                }
            }
        }

        // MARK: - Logout
        func logOut() {
            do {
                try Auth.auth().signOut()
                self.isLoggedOut = true
            } catch {
                print("Error signing out: \(error.localizedDescription)")
            }
        }
    }
#Preview {
    MenuView()
}
