import SwiftUI
import FirebaseDatabase
import FirebaseAuth

struct PostWithUser: Identifiable {
    let id: String
    let post: Post
    let username: String
    let userProfileUrl: String?
}

struct HomeView: View {
    @State private var posts: [PostWithUser] = []
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Leafly")
                            .font(.title)
                            .bold()
                    }
                    Spacer()
                    Image(systemName: "leaf.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.darkgreen)
                }
                .padding()
                .background(Color.ggreen)


                // Posts Feed
                if isLoading {
                    ProgressView("Loading posts...")
                        .padding()
                } else if posts.isEmpty {
                    Text("No posts available.")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(posts) { postWithUser in
                                PostCardView(postWithUser: postWithUser) {
                                    toggleLike(for: postWithUser.post.id)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            observePosts()
        }
        .refreshable {
            await loadPosts()
        }
    }

    // MARK: - Load Posts
    private func loadPosts() async {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        let postsRef = Database.database().reference().child("posts")

        do {
            let snapshot = try await postsRef.getData()
            var fetchedPosts: [PostWithUser] = []

            for case let child as DataSnapshot in snapshot.children {
                guard let data = child.value as? [String: Any],
                      let userId = data["userID"] as? String else { continue }

                // Fetch user data
                let userRef = Database.database().reference().child("users").child(userId)
                let userSnapshot = try await userRef.getData()
                let userData = userSnapshot.value as? [String: Any]

                // Explicitly annotate types
                let username: String = userData?["username"] as? String ?? "Unknown"
                let profileImageUrl: String? = userData?["profileImageUrl"] as? String

                // Build Post
                let post = Post(
                    id: child.key,
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

                fetchedPosts.append(PostWithUser(
                    id: child.key,
                    post: post,
                    username: username,
                    userProfileUrl: profileImageUrl
                ))
            }

            fetchedPosts.shuffle() // random order
            await MainActor.run {
                self.posts = fetchedPosts
                self.isLoading = false
            }

        } catch {
            print("Failed to load posts: \(error.localizedDescription)")
            await MainActor.run { self.isLoading = false }
        }
    }
    private func observePosts() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        let postsRef = Database.database().reference().child("posts")
        
        // Clear existing posts before observing
        self.posts.removeAll()
        self.isLoading = true
        
        postsRef.observe(.childAdded) { snapshot in
            guard let data = snapshot.value as? [String: Any],
                  let userId = data["userID"] as? String else { return }

            Database.database().reference().child("users").child(userId)
                .observeSingleEvent(of: .value) { userSnapshot in
                    let userData = userSnapshot.value as? [String: Any]
                    let username = userData?["username"] as? String ?? "Unknown"
                    let profileImageUrl = userData?["profileImageUrl"] as? String

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

                    let postWithUser = PostWithUser(
                        id: snapshot.key,
                        post: post,
                        username: username,
                        userProfileUrl: profileImageUrl
                    )

                    DispatchQueue.main.async {
                        if !self.posts.contains(where: { $0.id == postWithUser.id }) {
                            self.posts.insert(postWithUser, at: 0)
                            self.posts.sort { $0.post.timestamp > $1.post.timestamp }
                        }
                        self.isLoading = false   // <-- mark as loaded
                    }
                }
        }

        // Live update for likes/comments
        postsRef.observe(.childChanged) { snapshot in
            guard let updatedData = snapshot.value as? [String: Any] else { return }
            DispatchQueue.main.async {
                if let index = self.posts.firstIndex(where: { $0.id == snapshot.key }) {
                    var updatedPost = self.posts[index].post
                    updatedPost.likes = updatedData["likes"] as? Int ?? updatedPost.likes
                    updatedPost.commentsCount = updatedData["commentsCount"] as? Int ?? updatedPost.commentsCount
                    updatedPost.isLikedByCurrentUser = (updatedData["likedBy"] as? [String: Bool])?[currentUserID] ?? updatedPost.isLikedByCurrentUser
                    self.posts[index] = PostWithUser(
                        id: snapshot.key,
                        post: updatedPost,
                        username: self.posts[index].username,
                        userProfileUrl: self.posts[index].userProfileUrl
                    )
                }
            }
        }
    }
    private func toggleLike(for postID: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let postRef = Database.database().reference().child("posts/\(postID)")
        
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


struct PostCardView: View {
    let postWithUser: PostWithUser
    var onLike: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // User info
            HStack {
                if let urlString = postWithUser.userProfileUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty: ProgressView().frame(width: 40, height: 40)
                        case .success(let image): image.resizable().scaledToFill().frame(width: 40, height: 40).clipShape(Circle())
                        case .failure: Circle().fill(Color.green.opacity(0.3)).frame(width: 40, height: 40).overlay(Image(systemName: "person.fill").foregroundColor(.white))
                        @unknown default: EmptyView()
                        }
                    }
                } else {
                    Circle()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .overlay(Image(systemName: "person.fill").foregroundColor(.white))
                }

                VStack(alignment: .leading) {
                    Text(postWithUser.username)
                        .font(.headline)
                    Text(Date(timeIntervalSince1970: postWithUser.post.timestamp)
                        .formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
            }

            // Post text
            Text(postWithUser.post.text)
                .font(.body)

            // Post image
            if let urlString = postWithUser.post.imageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty: ProgressView()
                    case .success(let image): image.resizable().scaledToFill().frame(height: 200).cornerRadius(10)
                    case .failure: Image(systemName: "photo")
                    @unknown default: EmptyView()
                    }
                }
                .clipped()
            }

            // Points
            HStack {
                Image(systemName: "leaf.circle")
                Text("+\(postWithUser.post.points) Green Points")
                    .font(.caption)
                    .foregroundColor(.green)
                Spacer()
            }
            
            // Likes & Comments
            HStack(spacing: 16) {
                Button(action: { onLike?() }) {
                    Label("\(postWithUser.post.likes)", systemImage: postWithUser.post.isLikedByCurrentUser ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.caption)
                        .foregroundColor(postWithUser.post.isLikedByCurrentUser ? .blue : .gray)
                }
                
                NavigationLink(destination: CommentsView(postId: postWithUser.post.id)) {
                    Label("\(postWithUser.post.commentsCount)", systemImage: "bubble.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}
