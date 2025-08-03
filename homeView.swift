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
                                PostCardView(postWithUser: postWithUser)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            await loadPosts()
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
}


struct PostCardView: View {
    let postWithUser: PostWithUser

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
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}
