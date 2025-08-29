import SwiftUI
import FirebaseDatabase
import FirebaseAuth

// MARK: - Data models
struct PostWithUser: Identifiable { // Struc that represents a post along with the user who uploaded it. Combines all relevant data stored within the post for later display in feed
    let id: String // Firebase post ID
    let post: Post // Post context
    let username: String // Publishers username
    let userProfileUrl: String? // Optional, publishers profile image URL
}
// Result returned when user search bar is interacted with
struct UserSearchResult: Identifiable {
    let id: String // User's firebase UID
    let username: String // User's username string
    let profileImageUrl: String? // User's profile image URL, optional
}

// MARK: - Homeview
struct HomeView: View {
    @State private var posts: [PostWithUser] = [] // Posts to display in feed
    @State private var isLoading = true // Whether feed is currently loading or not
    @StateObject private var postService = PostService.shared // Shared service for posts
    @StateObject private var followService = FollowService.shared // Shared service for follow/unfollow functions
    
    //Search State
    @State private var searchQuery = "" // Current search text
    @State private var searchResults: [UserSearchResult] = [] // Results retrieved from database
    @State private var isSearching = false // Whether a search is in progress or not
    
    // MARK: Body
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
                    // Search bar for users
                    HStack {
                        TextField("Search users...", text: $searchQuery, onCommit: {
                            searchUsers(query: searchQuery)
                        })
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .onChange(of: searchQuery) { newValue in
                            searchUsers(query: newValue)
                        } // Pushes entered value of searchQuery into searchUsers when value is changed
                        
                        if isSearching {
                            ProgressView()
                                .padding(.trailing)
                        } // Display if a search is being held
                    }
                    .padding(.vertical, 4)
                    
                    Spacer()
                    NavigationLink(destination: LeaderboardView()) { // Navigation to leaderboard
                        Image(systemName: "list.number")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.white)
                    }
                    
                    Image(systemName: "leaf.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.darkgreen)
                } // App icon
                .padding()
                .background(Color.ggreen)

                // Search Results
                if !searchResults.isEmpty { // If search results are not empty / contain atleast 1 user
                    List(searchResults) { user in // Displays all relevant users retrieved from search result
                        NavigationLink(destination: OtherUserProfileView(userId: user.id)) {
                            HStack {
                                if let url = user.profileImageUrl, let imageURL = URL(string: url) {
                                    AsyncImage(url: imageURL) { image in
                                        image.resizable()
                                    } placeholder: {
                                        Circle().fill(Color.gray.opacity(0.3))
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 40, height: 40)
                                } // Displays user profile image if available, or placeholder if not

                                Text(user.username)
                                    .font(.headline)
                            } // Displays username of relevant user
                        }
                    }
                    .listStyle(PlainListStyle())
                } else { // If no users satisfy the search request
                    
                    // Posts feed - only displayed if search results are empty
                    if postService.posts.isEmpty {
                        ProgressView("Loading posts...").padding() // If no posts are able to be displayed
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                ForEach(postService.posts) { postWithUser in
                                    PostCardView(
                                        postWithUser: postWithUser,
                                        onLike: { postService.toggleLike(postID: postWithUser.post.id) },
                                        onFollow: { followService.toggleFollow(userId: postWithUser.post.userId) }
                                    ) // Displays PostCardView for each post retrieved
                                    .environmentObject(followService) // pass follow service down
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            observePosts() // observes changes in posts on initial load
        }
        .refreshable {
            await loadPosts() // Loads posts when refreshed
        }
    }
    // MARK: Search Users
    private func searchUsers(query: String) {
        guard !query.isEmpty else {
            searchResults = [] // returns empty search results
            return
        }

        let lowercaseQuery = query.lowercased() // converts input text to lowercase to prevent case-sensitive errors
        let usersRef = Database.database().reference().child("users")

        // Fetch all users
        usersRef.observeSingleEvent(of: .value) { snapshot in
            var results: [UserSearchResult] = []

            for child in snapshot.children { // Loads all users and relevant usernames
                if let childSnapshot = child as? DataSnapshot,
                   let data = childSnapshot.value as? [String: Any],
                   let username = data["username"] as? String {

                    // Retrieves users who satisfy the case-insensitive search query
                    if username.lowercased().contains(lowercaseQuery) {
                        let profileImageUrl = data["profileImageUrl"] as? String
                        let user = UserSearchResult(
                            id: childSnapshot.key,
                            username: username,
                            profileImageUrl: profileImageUrl
                        )
                        results.append(user)
                    }
                }
            }

            DispatchQueue.main.async {
                self.searchResults = results
                print("Total results: \(results.count)")
            } // Displays relevant results, prints the expected number of results for debugging
        }
    }
    // MARK: Load Posts
    private func loadPosts() async { // Loads all posts and user data for pull to refresh
        guard let currentUserID = Auth.auth().currentUser?.uid else { return } // Ensures current user is authenticated
        let postsRef = Database.database().reference().child("posts")
        
        do {
            let snapshot = try await postsRef.getData()
            var fetchedPosts: [PostWithUser] = []
            
            for case let child as DataSnapshot in snapshot.children {
                guard let data = child.value as? [String: Any],
                      let userId = data["userID"] as? String else { continue }
                
                // Fetch user data for each post
                let userRef = Database.database().reference().child("users").child(userId)
                let userSnapshot = try await userRef.getData()
                let userData = userSnapshot.value as? [String: Any]
                
                // Explicitly annotate types
                let username: String = userData?["username"] as? String ?? "Unknown"
                let profileImageUrl: String? = userData?["profileImageUrl"] as? String
                
                // Build post struct previously defined
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
            
            fetchedPosts.shuffle() // randomises order
            await MainActor.run {
                self.posts = fetchedPosts
                self.isLoading = false
            }
            
        } catch {
            print("Failed to load posts: \(error.localizedDescription)")
            await MainActor.run { self.isLoading = false } // prints error if posts are not able to load
        }
    }
    // MARK: Observe posts in realtime
    private func observePosts() { // Observes Firebase posts in real time and updates feed on new/changed posts
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        let postsRef = Database.database().reference().child("posts")
        
        // Clear existing posts before observing
        self.posts.removeAll()
        self.isLoading = true
        
        postsRef.observe(.childAdded) { snapshot in // observes new posts added
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
                    ) // retrieves all post data to define post struct
                    
                    let postWithUser = PostWithUser(
                        id: snapshot.key,
                        post: post,
                        username: username,
                        userProfileUrl: profileImageUrl
                    ) // retrieves user data relevant to post
                    
                    DispatchQueue.main.async {
                        if !self.posts.contains(where: { $0.id == postWithUser.id }) {
                            self.posts.insert(postWithUser, at: 0)
                            self.posts.sort { $0.post.timestamp > $1.post.timestamp }
                        }
                        self.isLoading = false   // sets isLoading to false once loading has been completed
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
                } // observes for updates to likes and comments, retrieves the relevant data to update the UI display
            }
        }
    }
    
    // MARK: Like toggle
    private func toggleLike(for postID: String) { // Automatically toggles likes/unlikes for current user in Firebase storage
        guard let uid = Auth.auth().currentUser?.uid else { return } // Ensures current user is authenticated
        let postRef = Database.database().reference().child("posts/\(postID)") // Defines the target post
        
        postRef.runTransactionBlock { currentData in
            if var postData = currentData.value as? [String: Any] { // Retrieves existing post data of likes and users who have liked the post
                var likes = postData["likes"] as? Int ?? 0
                var likedBy = postData["likedBy"] as? [String: Bool] ?? [:]
                
                if likedBy[uid] == true { // Unlikes if already liked by current user
                    likes -= 1
                    likedBy[uid] = nil
                } else {
                    likes += 1 // Adds like if not already liked by current user
                    likedBy[uid] = true
                }
                postData["likes"] = max(likes, 0)
                postData["likedBy"] = likedBy
                currentData.value = postData
            }
            return TransactionResult.success(withValue: currentData) // Returns updated data if successful
        }
    }
    
    // MARK: Follow user
    private func followUser(targetUserId: String) { // Updates follower/following counts in firebase when changes
        guard let currentUserId = Auth.auth().currentUser?.uid else { return } // Ensures current user is authenticated
        if currentUserId == targetUserId { return } // prevents users from following themself
        
        let usersRef = Database.database().reference().child("users")
        
        // Increment current user's following count
        usersRef.child(currentUserId).child("followingCount").runTransactionBlock { data in
            var count = data.value as? Int ?? 0
            data.value = count + 1
            return .success(withValue: data)
        }
        
        // Increment target user's followers count
        usersRef.child(targetUserId).child("followersCount").runTransactionBlock { data in
            var count = data.value as? Int ?? 0
            data.value = count + 1
            return .success(withValue: data)
        }
    }
}
// MARK: - PostCardView
struct PostCardView: View { // Reusable structure that retrieves and displays a single post
    let postWithUser: PostWithUser // Loads publishing user's data
    var onLike: (() -> Void)?
    var onFollow: (() -> Void)?
    @State private var isFollowing = false // Sets follow state
    @EnvironmentObject private var followService: FollowService // Connects followService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // User info header
            HStack {
                if let urlString = postWithUser.userProfileUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in // Retrieves user profile image if possible
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
                } // Placeholder if no image is found or image cannot be retrieved
                
                VStack(alignment: .leading) { // Allows navigation to target user's profile view if username is tapped
                    NavigationLink(destination: OtherUserProfileView(userId: postWithUser.post.userId)) {
                        Text(postWithUser.username)
                            .font(.headline)
                            .foregroundStyle(.black)
                    }
                    Text(Date(timeIntervalSince1970: postWithUser.post.timestamp) // Displays post timestamp
                        .formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.gray)
                }
                Spacer()
            }
            
            // Displays post text
            Text(postWithUser.post.text)
                .font(.body)
            
            // Retrieves and loads post image if attached
            if let urlString = postWithUser.post.imageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty: ProgressView() // remains empty if no image is attached
                    case .success(let image): image.resizable().scaledToFill().frame(height: 200).cornerRadius(10) // sets constraints for image size if retrievable
                    case .failure: Image(systemName: "photo") // Placeholder icon if the photo fails to load
                    @unknown default: EmptyView()
                    }
                }
                .clipped()
            }
            
            // Green Points
            HStack {
                Image(systemName: "leaf.circle")
                Text("+\(postWithUser.post.points) Green Points")
                    .font(.caption)
                    .foregroundColor(.darkgreen)
                Spacer()
            }
            
            // Likes & Comments
            HStack(spacing: 16) {
                Button(action: { onLike?() }) {
                    Label("\(postWithUser.post.likes)", systemImage: postWithUser.post.isLikedByCurrentUser ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.caption)
                        .foregroundColor(postWithUser.post.isLikedByCurrentUser ? .blue : .gray)
                } // If post has already been liked by the current authenticated user, it will display as a filled, blue icon, otherwise a gray outline
                
                NavigationLink(destination: CommentsView(postId: postWithUser.post.id)) {
                    Label("\(postWithUser.post.commentsCount)", systemImage: "bubble.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                } // Navigations to comments view of the target post
                
                if postWithUser.post.userId != Auth.auth().currentUser?.uid { // Checks that the userID of the target post does not match the userID of the authenticated current userID
                    Button(action: {
                        onFollow?()
                    }) {
                        Text(followService.isFollowing(postWithUser.post.userId) ? "Unfollow" : "Follow") // determines appearence of button if the current authenticated user
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(followService.isFollowing(postWithUser.post.userId) ? Color.gray.opacity(0.3) : Color.blue)
                            .foregroundColor(followService.isFollowing(postWithUser.post.userId) ? .black : .white) // determines background colour based on if user is following target user
                            .cornerRadius(6)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
        .onAppear {
            if !postWithUser.post.userId.isEmpty {
                checkIfFollowing()
            } // On intial appearence, check the post is not empty and runs checkIfFollowing
        }
    }
// MARK: Toggle follow/unfollow
    private func toggleFollow(targetUserId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return } // Ensures current user is authenticated
        let userRef = Database.database().reference().child("users")
        let currentUserFollowingRef = userRef.child(currentUserId).child("following").child(targetUserId) // Retrieves users current following
        let targetUserFollowersRef = userRef.child(targetUserId).child("followers").child(currentUserId) // Retrieves users current followers
        
        currentUserFollowingRef.observeSingleEvent(of: .value) { snapshot in
            if snapshot.exists() {
                // Unfollows, removes current userID from target user's followers, and target userID from current user's following
                currentUserFollowingRef.removeValue()
                targetUserFollowersRef.removeValue()
                self.isFollowing = false //toggles isFollowing
            } else {
                // Follows, adds current userID to target user's followers, and target userID to the current user's following
                currentUserFollowingRef.setValue(true)
                targetUserFollowersRef.setValue(true)
                self.isFollowing = true //toggles isFollowing
            }
        }
    }
    // MARK: Checks if current user is following target user
    private func checkIfFollowing() { // Checks whether the current authenticated userID is listed within the target user's followers
        guard let currentUserId = Auth.auth().currentUser?.uid, // Authenticates that the current authenticated userID does not match the post publishers userID (does not complete the function to the user's own published post)
              !postWithUser.post.userId.isEmpty else { return }
        
        let ref = Database.database().reference()
            .child("users")
            .child(currentUserId)
            .child("following")
            .child(postWithUser.post.userId)
        
        ref.observeSingleEvent(of: .value) { snapshot in
            self.isFollowing = snapshot.exists()
        } // observes for changes if users follow/unfollow
    }
}
// MARK: - Leaderboard View
struct LeaderboardView: View {
    @State private var leaderboard: [(uid: String, username: String, profileImageUrl: String?, points: Int)] = [] // Stores leaderboard users after applying filter (all or following)
    @State private var allUsers: [(uid: String, username: String, profileImageUrl: String?, points: Int)] = [] // Stores all users fetched from firebase before filtering
    @State private var isLoading = true // Determines whether functions are currently in progress
    @State private var currentUserId: String? // Stores current authenticated user's UserID
    @State private var followingIds: [String] = [] // Stores UserID of the users the current user is following
    @State private var filterOption: String = "All" // Determines which leaderboard filter is active
    
    // MARK:  Body
    var body: some View {
        VStack {
            // Filter Picker
            Picker("Filter", selection: $filterOption) {
                Text("All").tag("All")
                Text("Following").tag("Following")
            }
            .pickerStyle(.segmented) // Segmented control for switching
            .padding(.horizontal)
            .onChange(of: filterOption) { _ in
                applyFilter() // Re-apply filter when selection is changed
            }
            
            if isLoading { // Determines if loading
                ProgressView("Loading leaderboard...")
                    .padding()
            } else if leaderboard.isEmpty { // If the leaderboard does not display any users
                Text("No users found.")
                    .foregroundColor(.gray)
            } else {
                List { // Displays top 10 users
                    ForEach(Array(leaderboard.prefix(10).enumerated()), id: \.offset) { index, user in
                        leaderboardRow(index: index, user: user)
                    }
                    
                    // If current user is outside the top 10, show their position separately
                    if let currentId = currentUserId,
                       let myIndex = leaderboard.firstIndex(where: { $0.uid == currentId }),
                       myIndex >= 10 {
                        Section {
                            leaderboardRow(index: myIndex, user: leaderboard[myIndex])
                        } header: {
                            Text("Your Rank")
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Get current user's ID and load data on initial appearence
            currentUserId = Auth.auth().currentUser?.uid
            loadFollowingIds()
            loadLeaderboard()
        }
    }
// MARK: - Leaderboard
    @ViewBuilder
    private func leaderboardRow(index: Int, user: (uid: String, username: String, profileImageUrl: String?, points: Int)) -> some View {
        NavigationLink(destination: OtherUserProfileView(userId: user.uid)) { // Navigate to OtherUserProfileView when row is tapped
            HStack {
                Text("\(index + 1)") // Rank number
                    .font(.headline)
                    .frame(width: 30)
                
                if let urlString = user.profileImageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in  // Loading profile image
                        switch phase {
                        case .empty: ProgressView().frame(width: 40, height: 40) // while loading image or if no image is present
                        case .success(let image): image.resizable().scaledToFill().frame(width: 40, height: 40).clipShape(Circle()) // Displays profile image if successfully retrieved
                        case .failure: Circle().fill(Color.green.opacity(0.3)).frame(width: 40, height: 40).overlay(Image(systemName: "person.fill").foregroundColor(.white)) // Placeholder if profile picture failed to load
                        @unknown default: EmptyView()
                        }
                    }
                } else {
                    Circle() // Default placeholder if image  is not available
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .overlay(Image(systemName: "person.fill").foregroundColor(.white))
                }
                // Username and points display
                VStack(alignment: .leading) {
                    Text(user.username)
                        .font(.headline)
                    Text("\(user.points) Green Points")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                Spacer()
            }
            .padding(.vertical, 4)
            .background(user.uid == currentUserId ? Color.yellow.opacity(0.2) : Color.clear) // Sets background colour to yellow if the userID matches the current authenticated userID (Changes current user's background in list)
            .cornerRadius(8)
        }
    }
    // MARK: Load Leaderboard Data
    private func loadLeaderboard() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return } // Authenticates current userId
        self.currentUserId = currentUserId // Sets current userID
        
        let usersRef = Database.database().reference().child("users")
        usersRef.observeSingleEvent(of: .value) { snapshot in
            var fetchedLeaderboard: [(String, String, String?, Int)] = [] // Retrieves all users from database
            for case let child as DataSnapshot in snapshot.children {
                guard let userData = child.value as? [String: Any] else { continue }
                let username = userData["username"] as? String ?? "Unknown"
                let profileImageUrl = userData["profileImageUrl"] as? String // Loads all user data
                
                // MARK: Handle points
                let pointsValue = userData["points"] // Handle all cases if Firebase returns points as an inconsistant value type (Int, Double or String)
                let points: Int
                if let p = pointsValue as? Int {
                    points = p
                } else if let p = pointsValue as? Double {
                    points = Int(p)
                } else if let p = pointsValue as? String, let intP = Int(p) {
                    points = intP
                } else {
                    points = 0
                }
                
                fetchedLeaderboard.append((child.key, username, profileImageUrl, points))
            }
            
            fetchedLeaderboard.sort { $0.3 > $1.3 } // Sort by points descending
            
            DispatchQueue.main.async {
                self.allUsers = fetchedLeaderboard // Sets the target users to display
                self.applyFilter() // Apply filters
                self.isLoading = false // Determine loading state
            }
        }
    }
// MARK: Load Following IDs
    private func loadFollowingIds() { // Loads specific UserID's when filter is applied
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let followingRef = Database.database().reference()
            .child("users").child(uid).child("following")
        
        followingRef.observeSingleEvent(of: .value) { snapshot in
            var ids: [String] = []
            for child in snapshot.children {
                if let snap = child as? DataSnapshot {
                    ids.append(snap.key)
                }
            }
            DispatchQueue.main.async {
                self.followingIds = ids
                applyFilter()
            }
        } // Retrieves and loads all userID's within the current authenticated user's following list
    }
    // MARK: Apply  filter
    private func applyFilter() { // Applies the filter to select specific users to display
        if filterOption == "Following" { // Show only following and current user
            leaderboard = allUsers.filter { followingIds.contains($0.uid) || $0.uid == currentUserId }
        } else {
            leaderboard = allUsers // Show all users
        }
    }
}



#Preview {
    HomeView()
}
