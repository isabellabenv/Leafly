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
    @State private var selectedItem: PhotosPickerItem?
    @State private var points: Int = 0
    @State private var level: Int = 1
    @State private var followers: Int = 0
    @State private var following: Int = 0
    @State private var userPosts: [Post] = []

    // Progress value
    private var progressValue: Double {
        let pointsForCurrentLevel = (level - 1) * 100
        let pointsForNextLevel = level * 100
        let progressInLevel = Double(points - pointsForCurrentLevel) / Double(pointsForNextLevel - pointsForCurrentLevel)
        return min(max(progressInLevel, 0), 1)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                switch selectedTab {
                case .home:
                    HomeView()
                case .addPost:
                    CreatePostView()
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
                                .foregroundColor(.green)
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
            await loadProfileData()
            observeUserPosts()
        }
        .sheet(isPresented: $showMenu) { MenuView() }
    }

    var profileContent: some View {
        VStack(spacing: 0) {
            // --- Header ---
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
                                case .empty: ProgressView().frame(width: 80, height: 80)
                                case .success(let image): image.resizable().scaledToFill().frame(width: 80, height: 80).clipShape(Circle())
                                case .failure: Image(systemName: "person.crop.circle.badge.exclamationmark").resizable().scaledToFit().frame(width: 80, height: 80).foregroundColor(.gray)
                                @unknown default: EmptyView()
                                }
                            }
                        } else {
                            Circle().fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 80)
                                .overlay(Image(systemName: "person.crop.circle").font(.system(size: 40)).foregroundColor(.white))
                        }
                    }
                    .onChange(of: selectedItem) { newItem in
                        if let item = newItem { Task { await loadImage(from: item) } }
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(username).font(.headline)
                        ProgressView(value: progressValue)
                            .progressViewStyle(LinearProgressViewStyle(tint: .green))
                            .frame(width: 120)
                            .animation(.easeInOut, value: progressValue)
                        HStack(spacing: 8) {
                            Text("Level \(level)").font(.caption).foregroundColor(.gray)
                            Text("·").font(.caption).foregroundColor(.gray)
                            Text("\(points) Green Points").font(.caption).foregroundColor(.green)
                        }
                    }
                    Spacer()
                    Button(action: { showMenu.toggle() }) { Label("", systemImage: "ellipsis") }.padding()
                }

                HStack {
                    Spacer()
                    VStack {
                        Text("\(followers)").bold()
                        Text("Followers").font(.caption)
                    }
                    Spacer()
                    VStack {
                        Text("\(following)").bold()
                        Text("Following").font(.caption)
                    }
                    Spacer()
                }
                .padding(.bottom, 10)
            }
            .background(Color.green.opacity(0.1))

            // --- Posts Section ---
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(userPosts) { post in
                        VStack(alignment: .leading, spacing: 8) {
                            if let urlString = post.imageUrl, let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty: ProgressView()
                                    case .success(let image): image.resizable().scaledToFill().frame(height: 200).cornerRadius(10)
                                    case .failure: Image(systemName: "photo")
                                    @unknown default: EmptyView()
                                    }
                                }
                            }

                            Text(post.text).font(.body)

                            HStack {
                                Text(post.category).font(.caption).foregroundColor(.secondary)
                                Spacer()
                                Text("+\(post.points) pts").font(.caption).foregroundColor(.green)
                            }

                            HStack {
                                Button(action: { toggleLike(for: post) }) {
                                    HStack {
                                        Image(systemName: post.isLikedByCurrentUser ? "hand.thumbsup.fill" : "hand.thumbsup")
                                        Text("\(post.likes)")
                                    }
                                }
                                NavigationLink(destination: CommentsView(postID: post.id)) {
                                    HStack {
                                        Image(systemName: "bubble.left")
                                        Text("\(post.commentsCount)")
                                    }
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.blue)

                            Text(Date(timeIntervalSince1970: post.timestamp), style: .date)
                                .font(.caption2).foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 1)
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Like Toggle
    private func toggleLike(for post: Post) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let postRef = Database.database().reference().child("posts/\(post.id)")
        postRef.runTransactionBlock { currentData in
            if var postData = currentData.value as? [String: Any] {
                var likes = postData["likes"] as? Int ?? 0
                var likedBy = postData["likedBy"] as? [String: Bool] ?? [:]
                if likedBy[uid] == true {
                    likes -= 1
                    likedBy.removeValue(forKey: uid)
                } else {
                    likes += 1
                    likedBy[uid] = true
                }
                postData["likes"] = max(likes, 0)
                postData["likedBy"] = likedBy
                currentData.value = postData
            }
            return TransactionResult.success(withValue: currentData)
        }
    }

    // MARK: - Load Profile Data
    private func calculateLevel(from points: Int) -> Int {
        return max(1, (points / 100) + 1)
    }

    private func loadProfileData() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ref = Database.database().reference().child("users/\(uid)")
        do {
            let snapshot = try await ref.getData()
            if let userData = snapshot.value as? [String: Any] {
                await MainActor.run {
                    username = userData["username"] as? String ?? "Unknown"
                    points = userData["points"] as? Int ?? 0
                    level = calculateLevel(from: points)
                    followers = userData["followers"] as? Int ?? 0
                    following = userData["following"] as? Int ?? 0
                }
            }
            await loadProfileImageUrl()
        } catch {
            print("Failed to load profile data: \(error.localizedDescription)")
        }
    }

    private func loadProfileImageUrl() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let dbRef = Database.database().reference().child("users/\(uid)/profileImageUrl")
        do {
            let snapshot = try await dbRef.getData()
            if let urlString = snapshot.value as? String, let url = URL(string: urlString) {
                await MainActor.run { profileImageUrl = url }
            }
        } catch {
            print("Failed to load profile image URL: \(error.localizedDescription)")
        }
    }

    // MARK: - Observe User Posts
    private func observeUserPosts() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        let ref = Database.database().reference().child("posts")
        ref.observe(.value) { snapshot in
            var posts: [Post] = []
            for child in snapshot.children {
                guard let snap = child as? DataSnapshot,
                      let data = snap.value as? [String: Any],
                      let userId = data["userId"] as? String,
                      userId == currentUserID else { continue }

                let post = Post(
                    id: snap.key,
                    userId: userId,
                    text: data["text"] as? String ?? "",
                    imageUrl: data["imageUrl"] as? String,
                    timestamp: data["timestamp"] as? Double ?? 0,
                    category: data["category"] as? String ?? "Unknown",
                    points: data["points"] as? Int ?? 0,
                    likes: data["likes"] as? Int ?? 0,
                    commentsCount: data["commentsCount"] as? Int ?? 0,
                    isLikedByCurrentUser: (data["likedBy"] as? [String: Bool])?[currentUserID] ?? false
                )
                posts.append(post)
            }
            DispatchQueue.main.async {
                self.userPosts = posts.sorted { $0.timestamp > $1.timestamp }
            }
        }
    }

    // MARK: - Image Handling
    private func loadImage(from item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run { profileImage = uiImage }
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
            let dbRef = Database.database().reference().child("users/\(uid)/profileImageUrl")
            try await dbRef.setValue(downloadURL.absoluteString)
            await MainActor.run { profileImageUrl = downloadURL }
        } catch {
            print("Upload failed: \(error.localizedDescription)")
        }
    }
}
#Preview {
    ProfileView()
}
