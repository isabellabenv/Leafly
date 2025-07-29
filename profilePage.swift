import SwiftUI
import PhotosUI
import FirebaseAuth
import FirebaseStorage
import FirebaseDatabase
import FirebaseDatabaseInternal

enum SelectedTab {
    case home, addPost, profile
}

struct Post: Identifiable {
    let id: String
    let userId: String
    let text: String
    let imageUrl: String?
    let timestamp: Double
    let category: String
    let points: Int
    var likes: Int                    // var
    var commentsCount: Int            // var
    var isLikedByCurrentUser: Bool    // var
}

struct ProfileView: View {
    @State private var userPosts: [Post] = []
    @State private var selectedTab: SelectedTab = .profile
    @State private var showMenu = false
    @State private var username: String = "Loading..."
    @State private var profileImage: UIImage? = nil
    @State private var profileImageUrl: URL? = nil
    @State private var points: Int = 0
    @State private var level: Int = 1
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedPostForComments: Post? = nil
    @State private var showComments = false


    // Progress bar
    private var progressValue: Double {
        let currentLevelPoints = (level - 1) * 100
        let nextLevelPoints = level * 100
        let progress = Double(points - currentLevelPoints) / Double(nextLevelPoints - currentLevelPoints)
        return min(max(progress, 0), 1)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                switch selectedTab {
                case .home: HomeView()
                case .addPost: CreatePostView()
                case .profile: profileContent
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
                            Circle().foregroundColor(.darkgreen).frame(width: 60, height: 60)
                            Image(systemName: "plus").foregroundColor(.white).font(.system(size: 30))
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
            await loadUserPosts()       // Initial load
            observeUserPosts()          // Live updates
        }
        .refreshable {
            await loadProfileData()
            await loadUserPosts()
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
                            Image(uiImage: image).resizable().scaledToFill().frame(width: 80, height: 80).clipShape(Circle())
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
                            Circle().fill(Color.gray.opacity(0.3)).frame(width: 80, height: 80)
                                .overlay(Image(systemName: "person.crop.circle").font(.system(size: 40)).foregroundColor(.white))
                        }
                    }
                    .onChange(of: selectedItem) { newItem in
                        if let item = newItem { Task { await loadImage(from: item) } }
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(username).font(.headline)
                        ProgressView(value: progressValue).progressViewStyle(LinearProgressViewStyle(tint: .green)).frame(width: 120)
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
                    VStack { Text("232").bold(); Text("Followers").font(.caption) }
                    Spacer()
                    VStack { Text("2124").bold(); Text("Following").font(.caption) }
                    Spacer()
                }
                .padding(.bottom, 10)
            }
            .background(Color.ggreen)

            // --- Posts ---
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
                            // --- NEW: Likes & Comments row ---
                            HStack(spacing: 16) {
                                Label("\(post.likes)", systemImage: post.isLikedByCurrentUser ? "hand.thumbsup.fill" : "hand.thumbsup")
                                    .font(.caption)
                                    .foregroundColor(post.isLikedByCurrentUser ? .blue : .gray)
                                    .onTapGesture {
                                        toggleLike(for: post)
                                    }
                                
                                NavigationLink(destination: CommentsView(postId: post.id)
                                    .onDisappear {
                                        Task { await loadUserPosts() } // refresh post counts when returning
                                    }
                                ) {
                                    Label("\(post.commentsCount)", systemImage: "bubble.right")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            // ---
                            Text(Date(timeIntervalSince1970: post.timestamp).formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2).foregroundColor(.gray)
                        }
                        .padding().background(Color.white).cornerRadius(10).shadow(radius: 1)
                    }
                }
                .padding()
                .sheet(isPresented: $showComments) {
                    if let post = selectedPostForComments {
                        CommentsView(postId: post.id)
                    }
                }
            }
        }
    }

    // MARK: - Load Profile
    private func loadProfileData() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ref = Database.database().reference().child("users").child(uid)
        do {
            let snapshot = try await ref.getData()
            if let userData = snapshot.value as? [String: Any] {
                await MainActor.run {
                    username = userData["username"] as? String ?? "Unknown"
                    points = userData["points"] as? Int ?? 0
                    level = calculateLevel(for: points) // 🔥 Dynamically calculate
                }
            }
            await loadProfileImageURL()
        } catch { print("Failed to load profile data: \(error.localizedDescription)") }
    }
    private func calculateLevel(for points: Int) -> Int {
        return (points / 100) + 1  // Every 100 points = +1 level
    }

    private func loadProfileImageURL() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let dbRef = Database.database().reference().child("users/\(uid)/profileImageUrl")
        do {
            let snapshot = try await dbRef.getData()
            if let urlString = snapshot.value as? String, let url = URL(string: urlString) {
                await MainActor.run { profileImageUrl = url }
            }
        } catch { print("Failed to load profile image URL: \(error.localizedDescription)") }
    }

    // MARK: - Initial Posts Load
    private func loadUserPosts() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ref = Database.database().reference().child("posts")
        do {
            let snapshot = try await ref.getData()
            var posts: [Post] = []
            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let data = snap.value as? [String: Any],
                   let userId = data["userID"] as? String, userId == uid {
                    posts.append(Post(
                        id: snap.key,
                        userId: userId,
                        text: data["text"] as? String ?? "",
                        imageUrl: data["imageUrl"] as? String,
                        timestamp: data["timestamp"] as? Double ?? 0,
                        category: data["category"] as? String ?? "Unknown",
                        points: data["points"] as? Int ?? 0,
                        likes: data["likes"] as? Int ?? 0,
                        commentsCount: data["commentsCount"] as? Int ?? 0,
                        isLikedByCurrentUser: (data["likedBy"] as? [String: Bool])?[uid] ?? false
                    ))
                }
            }
            await MainActor.run { self.userPosts = posts.sorted { $0.timestamp > $1.timestamp } }
        } catch {
            print("Failed to load posts: \(error.localizedDescription)")
        }
    }

    // MARK: - Observe for Live Updates
    private func observeUserPosts() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        let ref = Database.database().reference().child("posts")
        ref.removeAllObservers()
        ref.queryOrdered(byChild: "timestamp").observe(FirebaseDatabase.DataEventType.childAdded) { snapshot in
            guard let data = snapshot.value as? [String: Any],
                  let userId = data["userID"] as? String,
                  userId == currentUserID else { return }
            
            let post = Post(
                id: snapshot.key,
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
            
            DispatchQueue.main.async {
                if !self.userPosts.contains(where: { $0.id == post.id }) {
                    self.userPosts.insert(post, at: 0)
                    self.userPosts.sort { $0.timestamp > $1.timestamp }
                }
            }
        }
    }

    // MARK: - Upload Profile Image
    private func loadImage(from item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run { profileImage = uiImage }
                await uploadProfileImage(uiImage)
            }
        } catch { print("Error loading image: \(error.localizedDescription)") }
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
        } catch { print("Upload failed: \(error.localizedDescription)") }
    }
    // MARK: - Toggle Like
    private func toggleLike(for post: Post) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let postRef = Database.database().reference().child("posts/\(post.id)")
        
        var updatedPost = post
        if post.isLikedByCurrentUser {
            updatedPost.likes -= 1
        } else {
            updatedPost.likes += 1
        }
        updatedPost.isLikedByCurrentUser.toggle()
        
        // Optimistically update UI
        if let index = userPosts.firstIndex(where: { $0.id == post.id }) {
            userPosts[index] = updatedPost
        }
        
        // Update in Firebase
        postRef.runTransactionBlock { currentData in
            if var postData = currentData.value as? [String: Any] {
                var likes = postData["likes"] as? Int ?? 0
                var likedBy = postData["likedBy"] as? [String: Bool] ?? [:]
                if likedBy[uid] == true {
                    likes -= 1
                    likedBy[uid] = nil
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
}
struct CommentsView: View {
    let postId: String
    @State private var comments: [Comment] = []
    @State private var newComment: String = ""
    
    struct Comment: Identifiable {
        let id: String
        let userId: String
        let username: String
        let text: String
        let timestamp: Double
    }
    
    var body: some View {
        VStack {
            List(comments) { comment in
                VStack(alignment: .leading) {
                    Text(comment.username).font(.caption).bold()
                    Text(comment.text).font(.body)
                    Text(Date(timeIntervalSince1970: comment.timestamp)
                        .formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2).foregroundColor(.gray)
                }
            }
            
            HStack {
                TextField("Add a comment...", text: $newComment)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Send") {
                    Task { await addComment() }
                }
                .disabled(newComment.isEmpty)
            }
            .padding()
        }
        .onAppear {
            Task { await loadComments() }
        }
    }
    
    private func loadComments() async {
        let ref = Database.database().reference().child("posts/\(postId)/comments")
        do {
            let snapshot = try await ref.getData()
            var loaded: [Comment] = []
            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let data = snap.value as? [String: Any] {
                    loaded.append(Comment(
                        id: snap.key,
                        userId: data["userId"] as? String ?? "",
                        username: data["username"] as? String ?? "Unknown",
                        text: data["text"] as? String ?? "",
                        timestamp: data["timestamp"] as? Double ?? 0
                    ))
                }
            }
            await MainActor.run {
                comments = loaded.sorted { $0.timestamp < $1.timestamp }
            }
        } catch {
            print("Failed to load comments: \(error.localizedDescription)")
        }
    }
    
    private func addComment() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let userRef = Database.database().reference().child("users/\(uid)/username")
        let usernameSnapshot = try? await userRef.getData()
        let username = usernameSnapshot?.value as? String ?? "User"
        
        let postRef = Database.database().reference().child("posts/\(postId)")
        let commentRef = postRef.child("comments").childByAutoId()
        
        let commentData: [String: Any] = [
            "userId": uid,
            "username": username,
            "text": newComment,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        do {
            // Add comment
            try await commentRef.setValue(commentData)
            
            // Increment commentsCount
            try await postRef.runTransactionBlock { currentData in
                if var postData = currentData.value as? [String: Any] {
                    var commentsCount = postData["commentsCount"] as? Int ?? 0
                    commentsCount += 1
                    postData["commentsCount"] = commentsCount
                    currentData.value = postData
                }
                return TransactionResult.success(withValue: currentData)
            }
            
            await MainActor.run { newComment = "" } // Clear input
        } catch {
            print("Failed to add comment: \(error.localizedDescription)")
        }
    }
}


#Preview {
    ProfileView()
}
