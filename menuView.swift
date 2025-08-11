import SwiftUI
import FirebaseAuth
import FirebaseDatabase

struct MenuView: View {
    @State private var username: String = "" // Stores the logged-in user's username
    @State private var email: String = "" // Stores the logged-in user's email
    @State private var profileImageUrl: String? = nil // Stores profile picture URL from Firebase
    @State private var isLoggedOut = false // Tracks logout status to show login screen

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                
                // MARK: - User Info Section
                VStack {
                    if let urlString = profileImageUrl, let url = URL(string: urlString) { // Loads the profile picture from a URL asynchronously
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView() // While image is loading
                                    .frame(width: 100, height: 100)
                            case .success(let image): // Successfully loaded image
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            case .failure: // If image fails to load, show placeholder
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 100, height: 100)
                                    .foregroundColor(.gray)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else { // If no profile image URL exists, show default icon
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.gray)
                    }

                    Text(username) // Username display
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(email) // Email display
                        .foregroundColor(.gray)
                        .font(.subheadline)
                }
                // MARK: - Log Out
                Button(action: {
                    logOut() // Calls logout function
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
                loadUserData() // Load user info from Firebase when view appears
            }
            .fullScreenCover(isPresented: $isLoggedOut) {
                ContentView() // Shows login screen when logged out
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
                self.profileImageUrl = value["profileImageUrl"] as? String  // NEW
            }
        }
    }

    // MARK: - Logout
    func logOut() {
        do {
            try Auth.auth().signOut()
            self.isLoggedOut = true // Triggers full screen cover to show login screen
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}

#Preview {
    MenuView()
}
