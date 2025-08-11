import SwiftUI
import Firebase
import FirebaseAuth

struct OtherUserProfileView: View {
    let userId: String
    
    @State private var username: String = "Loading..."
    @State private var profileImageUrl: URL? = nil
    @State private var points: Int = 0
    @State private var level: Int = 1
    @State private var posts: [Post] = []
    @State private var isFollowing: Bool = false
    @State private var followersCount: Int = 0
    @State private var followingCount: Int = 0
    @State private var showFollowersList = false
    @State private var showFollowingList = false
    private var currentUserId: String? { Auth.auth().currentUser?.uid }
    @StateObject private var followService = FollowService.shared
    @StateObject private var postService = PostService.shared
    
    private var progressValue: Double {
        let currentLevelPoints = (level - 1) * 100
        let nextLevelPoints = level * 100
        let progress = Double(points - currentLevelPoints) / Double(nextLevelPoints - currentLevelPoints)
        return min(max(progress, 0), 1)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // --- Header ---
            VStack {
                HStack {
                    if let url = profileImageUrl {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty: ProgressView().frame(width: 80, height: 80).padding(.leading)
                            case .success(let image): image.resizable().scaledToFill().frame(width: 80, height: 80).clipShape(Circle()).padding(.leading)
                            case .failure: Image(systemName: "person.crop.circle.badge.exclamationmark").resizable().scaledToFit().frame(width: 80, height: 80).foregroundColor(.gray).padding(.leading)
                            @unknown default: EmptyView()
                            }
                            
                        }
                    } else {
                        Circle().fill(Color.gray.opacity(0.3)).frame(width: 80, height: 80)
                            .overlay(Image(systemName: "person.crop.circle").font(.system(size: 40)).foregroundColor(.white))
                            .padding(.horizontal)
                    }
                    
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
                    // Follow button
                    Button(action: {
                        followService.toggleFollow(userId: userId)
                    }) {
                        Text(followService.isFollowing(userId) ? "Unfollow" : "Follow")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(followService.isFollowing(userId) ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding()
                }
                
                // Dynamic followers/following (tap to open lists)
                HStack {
                    Spacer()
                    Button(action: { showFollowersList.toggle() }) {
                        VStack { Text("\(followersCount)").bold().foregroundStyle(.black); Text("Followers").font(.caption).foregroundStyle(.black) }
                    }
                    Spacer()
                    Button(action: { showFollowingList.toggle() }) {
                        VStack { Text("\(followingCount)").bold().foregroundStyle(.black); Text("Following").font(.caption).foregroundStyle(.black) }
                    }
                    Spacer()
                }
                .padding()
            }
            .background(Color.ggreen)
            
            // --- Posts ---
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(posts) { post in
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
                            HStack(spacing: 16) {
                                Label("\(post.likes)", systemImage: post.isLikedByCurrentUser ? "hand.thumbsup.fill" : "hand.thumbsup")
                                    .font(.caption)
                                    .foregroundColor(post.isLikedByCurrentUser ? .blue : .gray)
                                    .onTapGesture {
                                        toggleLike(for: post)
                                    }
                                NavigationLink(destination: CommentsView(postId: post.id)) {
                                    Label("\(post.commentsCount)", systemImage: "bubble.right")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            Text(Date(timeIntervalSince1970: post.timestamp).formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2).foregroundColor(.gray)
                        }
                        .padding().background(Color.white).cornerRadius(10).shadow(radius: 1)
                    }
                }
                .padding()
            }
            .onAppear {
                observePostChanges(for: userId)  // pass the other user's ID
            }
        }
        .navigationTitle(username)
        .sheet(isPresented: $showFollowersList) {
            UserListView(userIdsPath: "users/\(userId)/followers", title: "Followers")
        }
        .sheet(isPresented: $showFollowingList) {
            UserListView(userIdsPath: "users/\(userId)/following", title: "Following")
        }
        .onAppear {
            Task {
                await loadUserProfile()
                await loadUserPosts()
                await checkIfFollowing()
                observeFollowerCounts()
            }
        }
    }
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
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index] = updatedPost
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
    
    // MARK: - Load Profile
    private func loadUserProfile() async {
        let ref = Database.database().reference().child("users").child(userId)
        do {
            let snapshot = try await ref.getData()
            if let userData = snapshot.value as? [String: Any] {
                await MainActor.run {
                    username = userData["username"] as? String ?? "Unknown"
                    points = userData["points"] as? Int ?? 0
                    level = (points / 100) + 1
                    if let urlString = userData["profileImageUrl"] as? String, let url = URL(string: urlString) {
                        profileImageUrl = url
                    }
                }
            }
        } catch { print("Failed to load user profile: \(error.localizedDescription)") }
    }
    
    private func loadUserPosts() async {
        let ref = Database.database().reference().child("posts")
        do {
            let snapshot = try await ref.getData()
            var loadedPosts: [Post] = []
            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let data = snap.value as? [String: Any],
                   let uid = data["userID"] as? String, uid == userId {
                    loadedPosts.append(Post(
                        id: snap.key,
                        userId: uid,
                        text: data["text"] as? String ?? "",
                        imageUrl: data["imageUrl"] as? String,
                        timestamp: data["timestamp"] as? Double ?? 0,
                        category: data["category"] as? String ?? "Unknown",
                        points: data["points"] as? Int ?? 0,
                        likes: data["likes"] as? Int ?? 0,
                        commentsCount: data["commentsCount"] as? Int ?? 0,
                        isLikedByCurrentUser: false
                    ))
                }
            }
            await MainActor.run { self.posts = loadedPosts.sorted { $0.timestamp > $1.timestamp } }
        } catch { print("Failed to load posts: \(error.localizedDescription)") }
    }
    
    // MARK: - Follow/Unfollow
    private func checkIfFollowing() async {
        guard let currentUserId = currentUserId else { return }
        let ref = Database.database().reference().child("users").child(currentUserId).child("following").child(userId)
        do {
            let snapshot = try await ref.getData()
            await MainActor.run { self.isFollowing = snapshot.exists() }
        } catch { print("Failed to check follow status: \(error.localizedDescription)") }
    }
    
    private func toggleFollow() {
        guard let currentUserId = currentUserId else { return }
        let ref = Database.database().reference().child("users")
        let currentUserFollowingRef = ref.child(currentUserId).child("following").child(userId)
        let targetUserFollowersRef = ref.child(userId).child("followers").child(currentUserId)
        
        currentUserFollowingRef.observeSingleEvent(of: .value) { snapshot in
            if snapshot.exists() {
                // Unfollow
                currentUserFollowingRef.removeValue()
                targetUserFollowersRef.removeValue()
                self.isFollowing = false
            } else {
                // Follow
                currentUserFollowingRef.setValue(true)
                targetUserFollowersRef.setValue(true)
                self.isFollowing = true
            }
        }
    }
    
    // MARK: - Observe Followers/Following
    private func observeFollowerCounts() {
        let ref = Database.database().reference().child("users").child(userId)
        ref.child("followers").observe(.value) { snapshot in
            self.followersCount = Int(snapshot.childrenCount)
        }
        ref.child("following").observe(.value) { snapshot in
            self.followingCount = Int(snapshot.childrenCount)
        }
    }
    private func observePostChanges(for userId: String) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        let postsRef = Database.database().reference().child("posts")
        
        postsRef.observe(.childChanged) { snapshot in
            guard let updatedData = snapshot.value as? [String: Any],
                  let postUserId = updatedData["userID"] as? String,
                  postUserId == userId else { return }

            DispatchQueue.main.async {
                if let index = self.posts.firstIndex(where: { $0.id == snapshot.key }) {
                    var updatedPost = self.posts[index]
                    updatedPost.likes = updatedData["likes"] as? Int ?? updatedPost.likes
                    updatedPost.commentsCount = updatedData["commentsCount"] as? Int ?? updatedPost.commentsCount
                    updatedPost.isLikedByCurrentUser =
                        (updatedData["likedBy"] as? [String: Bool])?[currentUserID] ?? false
                    self.posts[index] = updatedPost
                }
            }
        }
    }
}

struct UserListView: View {
    let userIdsPath: String
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var users: [(id: String, username: String, profileUrl: String?)] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading \(title)...")
                        .padding()
                } else if users.isEmpty {
                    Text("No \(title.lowercased()) yet.")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    List(users, id: \.id) { user in
                        NavigationLink(destination: OtherUserProfileView(userId: user.id)) {
                            HStack(spacing: 12) {
                                if let urlString = user.profileUrl, let url = URL(string: urlString) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty: Circle().fill(Color.gray.opacity(0.3))
                                        case .success(let image): image.resizable()
                                        case .failure: Circle().fill(Color.gray.opacity(0.3))
                                        @unknown default: EmptyView()
                                        }
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 40, height: 40)
                                        .overlay(Image(systemName: "person.fill").foregroundColor(.white))
                                }
                                Text(user.username)
                                    .font(.body)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear { loadUsers() }
    }
    
    // MARK: - Load Users
    private func loadUsers() {
        let ref = Database.database().reference().child(userIdsPath)
        ref.observeSingleEvent(of: .value) { snapshot in
            var loaded: [(id: String, username: String, profileUrl: String?)] = []
            let group = DispatchGroup()
            
            for child in snapshot.children {
                if let snap = child as? DataSnapshot {
                    let userId = snap.key
                    group.enter()
                    Database.database().reference().child("users").child(userId)
                        .observeSingleEvent(of: .value) { userSnap in
                            if let userData = userSnap.value as? [String: Any] {
                                let username = userData["username"] as? String ?? "Unknown"
                                let profileUrl = userData["profileImageUrl"] as? String
                                loaded.append((id: userId, username: username, profileUrl: profileUrl))
                            }
                            group.leave()
                        }
                }
            }
            
            group.notify(queue: .main) {
                self.users = loaded.sorted { $0.username.lowercased() < $1.username.lowercased() }
                self.isLoading = false
            }
        }
    }
}

