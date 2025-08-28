import SwiftUI
import Firebase
import FirebaseAuth

// View for displaying another user's profile page
struct OtherUserProfileView: View {
    let userId: String // The user ID of the profiled being viewed
    
    // User data state
    @State private var username: String = "Loading..."
    @State private var profileImageUrl: URL? = nil
    @State private var points: Int = 0
    @State private var level: Int = 1
    @State private var posts: [Post] = []
    
    // Follower/Following state
    @State private var isFollowing: Bool = false
    @State private var followersCount: Int = 0
    @State private var followingCount: Int = 0
    @State private var showFollowersList = false
    @State private var showFollowingList = false
    
    //Helpers
    private var currentUserId: String? { Auth.auth().currentUser?.uid }
    @StateObject private var followService = FollowService.shared
    @StateObject private var postService = PostService.shared
    
    //Calculates the progress towards next level
    private var progressValue: Double {
        let currentLevelPoints = (level - 1) * 100
        let nextLevelPoints = level * 100
        let progress = Double(points - currentLevelPoints) / Double(nextLevelPoints - currentLevelPoints)
        return min(max(progress, 0), 1) // Restricts progress between 0 and 1
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // --- Header ---
            VStack {
                HStack {
                    
                    //Profile image
                    if let url = profileImageUrl {
                        AsyncImage(url: url) { phase in // If user has a profile image, loaded in with Asynch Image
                            switch phase {
                            case .empty: ProgressView().frame(width: 80, height: 80).padding(.leading)
                            case .success(let image): image.resizable().scaledToFill().frame(width: 80, height: 80).clipShape(Circle()).padding(.leading)
                            case .failure: Image(systemName: "person.crop.circle.badge.exclamationmark").resizable().scaledToFit().frame(width: 80, height: 80).foregroundColor(.gray).padding(.leading) // Placeholder if the profile image was unable to be retrieved
                            @unknown default: EmptyView()
                            }
                            
                        }
                    } else {
                        Circle().fill(Color.gray.opacity(0.3)).frame(width: 80, height: 80)
                            .overlay(Image(systemName: "person.crop.circle").font(.system(size: 40)).foregroundColor(.white))
                            .padding(.horizontal)
                    } // Placeholder image if the user has not uploaded a profile image
                    
                    VStack(alignment: .leading, spacing: 6) { // Username, level and points display
                        Text(username).font(.headline)
                        ProgressView(value: progressValue).progressViewStyle(LinearProgressViewStyle(tint: .green)).frame(width: 120)
                        HStack(spacing: 8) {
                            Text("Level \(level)").font(.caption).foregroundColor(.gray)
                            Text("·").font(.caption).foregroundColor(.gray)
                            Text("\(points) Green Points").font(.caption).foregroundColor(.green)
                        }
                    }
                    
                    Spacer()
                    // Follow/unfollow button
                    Button(action: {
                        followService.toggleFollow(userId: userId) // Toggles follow/unfollow function when pressed
                    }) {
                        Text(followService.isFollowing(userId) ? "Unfollow" : "Follow") // Displays relevant text whether the user is already following the current profile or not
                            .fontWeight(.semibold)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(followService.isFollowing(userId) ? Color.gray : Color.blue) // Determines the background colour of the button based on whether they are following the user or not
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding()
                }
                
                // Dynamic followers/following, allows users to open lists of all users followed or following the target profile being viewed
                HStack {
                    Spacer()
                    Button(action: { showFollowersList.toggle() }) {
                        VStack { Text("\(followersCount)").bold().foregroundStyle(.black); Text("Followers").font(.caption).foregroundStyle(.black) }
                    } // Toggles the followers list of the current profile
                    Spacer()
                    Button(action: { showFollowingList.toggle() }) {
                        VStack { Text("\(followingCount)").bold().foregroundStyle(.black); Text("Following").font(.caption).foregroundStyle(.black) }
                    } // Toggles the following list of the current user profile
                    Spacer()
                }
                .padding()
            }
            .background(Color.ggreen)
            
            //  Posts
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(posts) { post in // Retrieves every post relevant to the selected user's profile, and the relevant data attached
                        VStack(alignment: .leading, spacing: 8) {
                            if let urlString = post.imageUrl, let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in // Retrieves image if present in post
                                    switch phase {
                                    case .empty: ProgressView()
                                    case .success(let image): image.resizable().scaledToFill().frame(height: 200).cornerRadius(10)
                                    case .failure: Image(systemName: "photo")
                                    @unknown default: EmptyView()
                                    }
                                }
                            }
                            Text(post.text).font(.body) // Post text
                            HStack { // Displays post category and points awarded
                                Text(post.category).font(.caption).foregroundColor(.secondary)
                                Spacer()
                                Text("+\(post.points) pts").font(.caption).foregroundColor(.green)
                            }
                            HStack(spacing: 16) { // Likes and commeents
                                Label("\(post.likes)", systemImage: post.isLikedByCurrentUser ? "hand.thumbsup.fill" : "hand.thumbsup") // Determines whether the icon will be filled or outlined whether the user has or hasn't liked the psot
                                    .font(.caption)
                                    .foregroundColor(post.isLikedByCurrentUser ? .blue : .gray) // Determines colour whether the post has been liked or not by the current user
                                    .onTapGesture {
                                        toggleLike(for: post) // Toggles the like function when tapped
                                    }
                                NavigationLink(destination: CommentsView(postId: post.id)) { // Navigates users to the comment view for the relevant postID
                                    Label("\(post.commentsCount)", systemImage: "bubble.right")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            Text(Date(timeIntervalSince1970: post.timestamp).formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2).foregroundColor(.gray)
                        } // Displays post timestamp determined when initially uploaded
                        .padding().background(Color.white).cornerRadius(10).shadow(radius: 1)
                    }
                }
                .padding()
            }
            .onAppear {
                observePostChanges(for: userId)  // Keeps posts updated live for the current userID
            }
        }
        .navigationTitle(username)
        
        .sheet(isPresented: $showFollowersList) { // Displays the followers list when toggled
            UserListView(userIdsPath: "users/\(userId)/followers", title: "Followers")
        }
        .sheet(isPresented: $showFollowingList) { // Displays the following list when toggled
            UserListView(userIdsPath: "users/\(userId)/following", title: "Following")
        }
        .onAppear {
            Task { // Initial and updated loading of details relevant to the target users profile
                await loadUserProfile()
                await loadUserPosts()
                await checkIfFollowing()
                observeFollowerCounts()
            }
        }
    }
    private func toggleLike(for post: Post) { // Toggles likes/unlikes of target post
        guard let uid = Auth.auth().currentUser?.uid else { return } // Ensures current user is authenticated before proceeding
        let postRef = Database.database().reference().child("posts/\(post.id)") // Sets the target post ID

        var updatedPost = post // Updates UI based on the determined action
        if post.isLikedByCurrentUser {
            updatedPost.likes -= 1
        } else {
            updatedPost.likes += 1
        }
        updatedPost.isLikedByCurrentUser.toggle() // Updates the state isLikedByCurrentUser

        // Updates post UI
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index] = updatedPost
        }

        // Update like data stored within Firebase for the target post
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
            return TransactionResult.success(withValue: currentData) // Determines the success of function
        }
    }
    
    // MARK: - Load Profile
    private func loadUserProfile() async {
        let ref = Database.database().reference().child("users").child(userId) // Sets the target userID of selected profile
        do {
            let snapshot = try await ref.getData()
            if let userData = snapshot.value as? [String: Any] {
                await MainActor.run {
                    username = userData["username"] as? String ?? "Unknown"
                    points = userData["points"] as? Int ?? 0
                    level = (points / 100) + 1
                    if let urlString = userData["profileImageUrl"] as? String, let url = URL(string: urlString) {
                        profileImageUrl = url
                    } // Retrieves targed UserID's stored username, points and image URL if available
                }
            }
        } catch { print("Failed to load user profile: \(error.localizedDescription)") } // If retrieval is not successful, error will be printed
    }
    // MARK: - Load User posts
    private func loadUserPosts() async {
        let ref = Database.database().reference().child("posts")
        do {
            let snapshot = try await ref.getData()
            var loadedPosts: [Post] = []
            
            for child in snapshot.children { // Collect posts stored within this userID
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
                } // Retrieves all relevant data stored within the target postID
            }
            await MainActor.run { self.posts = loadedPosts.sorted { $0.timestamp > $1.timestamp } } // Orders posts based on upload timestamp, from newest to oldest
        } catch { print("Failed to load posts: \(error.localizedDescription)") } // Prints error if post retrieval fails
    }
    
    // MARK: - Follow/Unfollow
    private func checkIfFollowing() async { // Checks whether current authetnicated user is following the target user of the selected user profile
        guard let currentUserId = currentUserId else { return }
        let ref = Database.database().reference().child("users").child(currentUserId).child("following").child(userId)
        do {
            let snapshot = try await ref.getData()
            await MainActor.run { self.isFollowing = snapshot.exists() }
        } catch { print("Failed to check follow status: \(error.localizedDescription)") } // Prints error if unable to retrieve data
    }
    
    private func toggleFollow() { // Toggles follow/unfollow of other user
        guard let currentUserId = currentUserId else { return } // Authenticates the current user to prevent error
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
    
    // MARK: Observe followers/following count
    private func observeFollowerCounts() {
        let ref = Database.database().reference().child("users").child(userId)
        ref.child("followers").observe(.value) { snapshot in
            self.followersCount = Int(snapshot.childrenCount)
        }
        ref.child("following").observe(.value) { snapshot in
            self.followingCount = Int(snapshot.childrenCount)
        }
    } // Observes for changes in follower/following counts
    
    // MARK: Observe live post changes
    private func observePostChanges(for userId: String) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return } // Authenticates current suer
        let postsRef = Database.database().reference().child("posts")
        
        postsRef.observe(.childChanged) { snapshot in // Listens for updates to posts made by the target user
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
// MARK: User list view
struct UserListView: View { // Reusable view for showing followers or following lists relevant to the current user
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
                } else if users.isEmpty { // If no users are listed under the followers/following of current user
                    Text("No \(title.lowercased()) yet.")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    List(users, id: \.id) { user in // Displays all relevant users listed under the current followers/following of the target user
                        NavigationLink(destination: OtherUserProfileView(userId: user.id)) {
                            HStack(spacing: 12) {
                                if let urlString = user.profileUrl, let url = URL(string: urlString) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty: Circle().fill(Color.gray.opacity(0.3))
                                        case .success(let image): image.resizable()
                                        case .failure: Circle().fill(Color.gray.opacity(0.3))
                                        @unknown default: EmptyView()
                                        } // Displays user profile image within list
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 40, height: 40)
                                        .overlay(Image(systemName: "person.fill").foregroundColor(.white))
                                } // Placeholder image if no image has been uploaded
                                Text(user.username)
                                    .font(.body) // Displays username
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
                } // Function to close the list view and return to user profile
            }
        }
        .onAppear { loadUsers() } // Runs the loadUsers on initial appearence
    }
    
    // MARK: - Load Users
    private func loadUsers() {
        let ref = Database.database().reference().child(userIdsPath)
        ref.observeSingleEvent(of: .value) { snapshot in
            var loaded: [(id: String, username: String, profileUrl: String?)] = []
            let group = DispatchGroup()
            
            for child in snapshot.children { // For each user ID listed under followers/following of the current profile, the relevant user data will be retrieved for display
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
            } // Updates the state once all users and relevant data has been retrieved, sorting usernames in alphabetical order
        }
    }
}
