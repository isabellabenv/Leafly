import SwiftUI
import PhotosUI
import FirebaseAuth
import FirebaseStorage
import FirebaseDatabase

enum SelectedTab {
    case home, addPost, profile
}

struct ProfileView: View {
    @State private var selectedTab: SelectedTab = .profile
    @State private var showMenu = false
    @State private var username: String = ""
    @State private var profileImage: UIImage? = nil
    @State private var profileImageUrl: URL? = nil
    @State private var selectedItem: PhotosPickerItem? {
        didSet {
            if let item = selectedItem {
                Task {
                    await loadImage(from: item)
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                switch selectedTab {
                case .home:
                    HomeView()
                case .addPost:
                    AddPostView()
                case .profile:
                    profileContent
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer(minLength: 20)

                    Button(action: { selectedTab = .home }) {
                        Image(systemName: "house")
                            .font(.system(size: 30))
                            .foregroundColor(selectedTab == .home ? .green : .gray)
                    }

                    Spacer()

                    Button(action: { selectedTab = .addPost }) {
                        ZStack {
                            Circle()
                                .foregroundColor(.darkgreen)
                                .frame(width: 60, height: 60)
                            Image(systemName: "plus")
                                .foregroundColor(.white)
                                .font(.system(size: 30))
                        }
                    }

                    Spacer()

                    Button(action: { selectedTab = .profile }) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 30))
                            .foregroundColor(selectedTab == .profile ? .green : .gray)
                    }

                    Spacer(minLength: 20)
                }
            }
        }
        .task {
            loadProfileImageURL()
            loadUserData()
        }
        .sheet(isPresented: $showMenu) {
            MenuView()
        }
    }

    var profileContent: some View {
        VStack(spacing: 0) {
            VStack {
                HStack {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        if let image = profileImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                        } else if let url = profileImageUrl {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(width: 80, height: 80)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                case .failure:
                                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 80, height: 80)
                                        .foregroundColor(.gray)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "person.crop.circle")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(username)
                            .font(.headline)
                        ProgressView(value: 0.75)
                            .progressViewStyle(LinearProgressViewStyle(tint: .green))
                            .frame(width: 100)
                        Text("level 27")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Button(action: openMenu) {
                        Label("", systemImage: "ellipsis")
                    }
                    .padding()
                }

                HStack {
                    Spacer()
                    VStack {
                        Text("232").bold()
                        Text("Followers").font(.caption)
                    }
                    Spacer()
                    VStack {
                        Text("2124").bold()
                        Text("Following").font(.caption)
                    }
                    Spacer()
                }
                .padding(.bottom, 10)
            }
            .background(Color.ggreen)

            HStack {
                Text("All Posts").bold()
                Spacer()
                Text("Photos")
                Spacer()
                Text("Awards")
            }
            .padding()
            .background(Color.palegreen)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Add posts here
                }
                .padding()
            }
        }
    }

    private func openMenu() {
        showMenu.toggle()
    }

    private func loadProfileImageURL() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let dbRef = Database.database().reference()
        dbRef.child("users/\(uid)/profileImageUrl").observeSingleEvent(of: .value) { snapshot in
            if let urlString = snapshot.value as? String, let url = URL(string: urlString) {
                self.profileImageUrl = url
            } else {
                print("No profile image URL found.")
            }
        }
    }

    private func loadImage(from item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                self.profileImage = uiImage
                await uploadProfileImage(uiImage)
            }
        } catch {
            print("Error loading image: \(error.localizedDescription)")
        }
    }

    private func uploadProfileImage(_ image: UIImage) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }

        let storageRef = Storage.storage().reference().child("profile_pictures/\(uid).jpg")
        do {
            _ = try await storageRef.putDataAsync(imageData)
            let downloadURL = try await storageRef.downloadURL()
            let dbRef = Database.database().reference()
            try await dbRef.child("users/\(uid)/profileImageUrl").setValue(downloadURL.absoluteString)
            profileImageUrl = downloadURL
        } catch {
            print("Upload failed: \(error.localizedDescription)")
        }
    }

    func loadUserData() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ref = Database.database().reference().child("users").child(uid)
        ref.observeSingleEvent(of: .value) { snapshot in
            if let value = snapshot.value as? [String: Any] {
                self.username = value["username"] as? String ?? "Unknown"
            }
        }
    }
    struct HomeView: View {
        var body: some View {
            Text("Home View")
                .font(.largeTitle)
                .foregroundColor(.gray)
        }
    }

    struct AddPostView: View {
        var body: some View {
            Text("Add Post View")
                .font(.largeTitle)
                .foregroundColor(.gray)
        }
    }
}

#Preview {
    ProfileView()
}
