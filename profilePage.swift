import SwiftUI
import PhotosUI
import FirebaseAuth
import FirebaseStorage
import FirebaseDatabaseInternal

struct ProfileView: View {
    @State private var showMenu = false
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
        VStack(spacing: 0) {
            VStack {
                HStack {
                    // Tappable image picker
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        if let url = profileImageUrl {
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
                                        .frame(width: 80, height: 80)
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

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name")
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
                        Text("232")
                            .bold()
                        Text("Followers")
                            .font(.caption)
                    }
                    Spacer()
                    VStack {
                        Text("2124")
                            .bold()
                        Text("Following")
                            .font(.caption)
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
                    // PostView examples go here
                }
                .padding()
            }

            HStack {
                Spacer(minLength: 20)
                Image(systemName: "house")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                    .padding()
                Spacer()
                ZStack {
                    Circle()
                        .foregroundColor(.darkgreen)
                        .frame(width: 80, height: 80)
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                        .font(.system(size: 50))
                }
                .padding()
                Spacer()
                Image(systemName: "person.crop.circle")
                    .foregroundColor(.white)
                    .font(.system(size: 40))
                    .padding()
                Spacer(minLength: 20)
            }
            .padding()
            .frame(height: 100)
            .background(Color.ggreen)
        }
        .sheet(isPresented: $showMenu) {
            MenuView()
        }
        .task {
            loadProfileImageURL()
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
                profileImageUrl = url
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
}

struct PostView: View {
    var profileImage: String
    var name: String
    var time: String
    var action: String
    var quote: String
    var points: String
    var postImage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(profileImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(name)
                            .bold()
                        Spacer()
                        Text(time)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Text(action)
                    Text("“\(quote)”")
                        .italic()
                        .font(.caption)

                    Text("\(points) points")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }

            if let postImage = postImage {
                Image(postImage)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(10)
                    .padding(.leading, 44) // aligned with text
            }
        }
    }
}

#Preview {
    ProfileView()
}
