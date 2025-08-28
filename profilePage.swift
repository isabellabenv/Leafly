import SwiftUI
import PhotosUI
import FirebaseAuth
import FirebaseStorage
import FirebaseDatabase
import FirebaseDatabaseInternal

// MARK: - Enum for navigation tabs, determines the active view
enum SelectedTab {
    case home, addPost, profile
}

// MARK: - Post model, identifies the information of each post
struct Post: Identifiable {
    let id: String  // Unique post ID
    let userId: String // ID of user who made the post
    let text: String // Post text content
    let imageUrl: String? // Optional image URL
    let timestamp: Double // Timestamp for when post was created
    let category: String // Category label for the post
    let points: Int // Points awarded for this post
    var likes: Int // Number of likes (mutable)
    var commentsCount: Int // Number of comments (mutable)
    var isLikedByCurrentUser: Bool // Whether current user liked this post
}

// MARK: - Profile view
struct ProfileView: View {
    // State variables for profile and post data
    @State private var userPosts: [Post] = [] // Current user's posts
    @State private var selectedTab: SelectedTab = .profile // Selected tab
    @State private var showMenu = false // Show/hide menu
    @State private var username: String = "Loading..." // Displayed username
    @State private var profileImage: UIImage? = nil // Selected profile image
    @State private var profileImageUrl: URL? = nil // URL to stored profile image
    @State private var points: Int = 0 // User's total points
    @State private var level: Int = 1 // User's level (calculated from points)
    @State private var selectedItem: PhotosPickerItem? // Picked image from photo library
    @State private var selectedPostForComments: Post? = nil // Selected post for comment view
    @State private var showComments = false // Whether comments sheet is showing
    @State private var followersCount: Int = 0 // Follower count
    @State private var followingCount: Int = 0 // Following count
    

    // MARK: - Progress bar logic
        // Calculates progress toward next level based on points
    private var progressValue: Double {
        let currentLevelPoints = (level - 1) * 100
        let nextLevelPoints = level * 100
        let progress = Double(points - currentLevelPoints) / Double(nextLevelPoints - currentLevelPoints)
        return min(max(progress, 0), 1) // Limit between 0 and 1
    }

    var body: some View {
        NavigationStack {
            ZStack {
                switch selectedTab {
                case .home: HomeView()
                case .addPost: CreatePostView()
                case .profile: profileContent
                } // Switch between main app tabs
            }
            .toolbar {  // Bottom tab bar
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer(minLength: 20)
                    Button(action: { selectedTab = .home }) {
                        Image(systemName: "house")
                            .font(.system(size: 30))
                            .foregroundColor(selectedTab == .home ? .ggreen : .gray)
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
                            .foregroundColor(selectedTab == .profile ? .ggreen : .gray)
                    }
                    Spacer(minLength: 20)
                }
            }
        }
        .task { // Load data when view appears
            await loadProfileData()
                await loadUserPosts()
                await loadFollowCounts()
                observeUserPosts()
                observeFollowCounts()
        }
        .refreshable { // Pull-to-refresh handler
            await loadProfileData()
            await loadUserPosts()
        }
        .sheet(isPresented: $showMenu) { MenuView() } // Menu sheet appears
    }
    
    // MARK: - Profile Content
    var profileContent: some View {
        VStack(spacing: 0) {
            // Profile Header
            VStack {
                HStack {
                    PhotosPicker(selection: $selectedItem, matching: .images) { // Profile image picker
                        if let image = profileImage {
                            Image(uiImage: image).resizable().scaledToFill().frame(width: 80, height: 80).clipShape(Circle()) // Show selected image
                        } else if let url = profileImageUrl { // Show stored image from URL
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty: ProgressView().frame(width: 80, height: 80)
                                case .success(let image): image.resizable().scaledToFill().frame(width: 80, height: 80).clipShape(Circle())
                                case .failure: Image(systemName: "person.crop.circle.badge.exclamationmark").resizable().scaledToFit().frame(width: 80, height: 80).foregroundColor(.gray) //Placeholder image if the image uploaded fails to be retrieved
                                @unknown default: EmptyView()
                                }
                            }
                        } else {
                            ZStack(alignment: .bottomTrailing) {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Image(systemName: "person.crop.circle")
                                            .font(.system(size: 40))
                                            .foregroundColor(.white)
                                    )

                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Image(systemName: "plus")
                                            .foregroundColor(.white)
                                            .font(.system(size: 14, weight: .bold))
                                    )
                                    .offset(x: 4, y: 4)
                            }
                        } // Placeholder image for when users are yet to upload their own image, displaying a default circle with a "+" icon to indicate the customisability
                    }
                    .onChange(of: selectedItem) { newItem in
                        if let item = newItem { Task { await loadImage(from: item) } } // When new image is selected, the profile image will be loaded again
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 6) {  // Username, progress bar, and points display
                        Text(username).font(.headline)
                        ProgressView(value: progressValue).progressViewStyle(LinearProgressViewStyle(tint: .green)).frame(width: 120)
                        HStack(spacing: 8) {
                            Text("Level \(level)").font(.caption).foregroundColor(.gray)
                            Text("·").font(.caption).foregroundColor(.gray)
                            Text("\(points) Green Points").font(.caption).foregroundColor(.green)
                        }
                    }
                    Spacer()
                    Button(action: { showMenu.toggle() }) { Label("", systemImage: "ellipsis") }.padding() // Menu button
                }

                HStack { // Follower / Following counts
                    Spacer()
                    VStack { Text("\(followersCount)").bold(); Text("Followers").font(.caption) }
                    Spacer()
                    VStack { Text("\(followingCount)").bold(); Text("Following").font(.caption) }
                    Spacer()
                }
                .padding(.bottom, 10)
            }
            .background(Color.ggreen)

            // User Posts
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(userPosts) { post in
                        VStack(alignment: .leading, spacing: 8) {
                            if let urlString = post.imageUrl, let url = URL(string: urlString) { // Post image
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty: ProgressView()
                                    case .success(let image): image.resizable().scaledToFill().frame(height: 200).cornerRadius(10)
                                    case .failure: Image(systemName: "photo")
                                    @unknown default: EmptyView()
                                    }
                                }
                            }
                            Text(post.text).font(.body) // Post text
                            HStack { // Category and points
                                Text(post.category).font(.caption).foregroundColor(.secondary)
                                Spacer()
                                Text("+\(post.points) pts").font(.caption).foregroundColor(.green)
                            }
                            HStack(spacing: 16) { // Likes & comments row
                                Label("\(post.likes)", systemImage: post.isLikedByCurrentUser ? "hand.thumbsup.fill" : "hand.thumbsup")
                                    .font(.caption)
                                    .foregroundColor(post.isLikedByCurrentUser ? .blue : .gray)
                                    .onTapGesture {
                                        toggleLike(for: post)
                                    }
                                
                                NavigationLink(destination: CommentsView(postId: post.id)
                                    .onDisappear {
                                        Task { await loadUserPosts() } // Refresh posts after returning from comments
                                    }
                                ) {
                                    Label("\(post.commentsCount)", systemImage: "bubble.right")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            Text(Date(timeIntervalSince1970: post.timestamp).formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2).foregroundColor(.gray) // Timestamp
                        }
                        .padding().background(Color.white).cornerRadius(10).shadow(radius: 1)
                    }
                }
                .padding()
                .sheet(isPresented: $showComments) {
                    if let post = selectedPostForComments {
                        CommentsView(postId: post.id)
                    } // Sheet for comments view
                }
            }
        }
    }

    // MARK: - Load profile info from Firebase
    private func loadProfileData() async {
        guard let uid = Auth.auth().currentUser?.uid else { return } // Ensures user is authenticated before continuing
        let ref = Database.database().reference().child("users").child(uid)
        do {
            let snapshot = try await ref.getData()
            if let userData = snapshot.value as? [String: Any] {
                await MainActor.run {
                    username = userData["username"] as? String ?? "Unknown"
                    points = userData["points"] as? Int ?? 0
                    level = calculateLevel(for: points) // Calculate level from points
                }
            }
            await loadProfileImageURL()
        } catch { print("Failed to load profile data: \(error.localizedDescription)") }
    }
    private func calculateLevel(for points: Int) -> Int {
        return (points / 100) + 1      // Calculate level from points (100 pts per level)
    }

    private func loadProfileImageURL() async { // Load profile image URL from Firebase
        guard let uid = Auth.auth().currentUser?.uid else { return } // Ensures user is authenticated before continuing
        let dbRef = Database.database().reference().child("users/\(uid)/profileImageUrl")
        do {
            let snapshot = try await dbRef.getData()
            if let urlString = snapshot.value as? String, let url = URL(string: urlString) {
                await MainActor.run { profileImageUrl = url }
            }
        } catch { print("Failed to load profile image URL: \(error.localizedDescription)") }
    }

    // MARK: - Load user's posts
    private func loadUserPosts() async {
        guard let uid = Auth.auth().currentUser?.uid else { return } // Ensures user is authenticated before continuing
        let ref = Database.database().reference().child("posts")
        do {
            let snapshot = try await ref.getData()
            var posts: [Post] = []
            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let data = snap.value as? [String: Any],
                   let userId = data["userID"] as? String, userId == uid {
                    posts.append(Post( // Create Post object from Firebase data
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
                    )) // Loads all predefined items within the post struct
                }
            }
            await MainActor.run { self.userPosts = posts.sorted { $0.timestamp > $1.timestamp } } // Sort posts by timestamp
        } catch {
            print("Failed to load posts: \(error.localizedDescription)")
        }
    }

    // MARK: - Observe live post updates from Firebase
    private func observeUserPosts() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return } // Ensures user is authenticated before continuing
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
            ) // Retrieves all data stored under a post within firebase
            
            DispatchQueue.main.async {
                if !self.userPosts.contains(where: { $0.id == post.id }) {
                    self.userPosts.insert(post, at: 0)
                    self.userPosts.sort { $0.timestamp > $1.timestamp }
                } // Displays posts in order of most recent to oldest
            }
        }
    }

    // MARK: - Upload and set profile image
    private func loadImage(from item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run { profileImage = uiImage }
                await uploadProfileImage(uiImage)
            }
        } catch { print("Error loading image: \(error.localizedDescription)") } // Prints the error if the profile image uploaded is not valid and able to be used
    }

    private func uploadProfileImage(_ image: UIImage) async {
        guard let uid = Auth.auth().currentUser?.uid else { return } // Ensures user is authenticated before continuing
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        let storageRef = Storage.storage().reference().child("profile_pictures/\(uid).jpg")
        do { // Stores the compressed image within a specific folder once converted to a consistent form for later retrieval
            _ = try await storageRef.putDataAsync(imageData)
            let downloadURL = try await storageRef.downloadURL() // Assigns URL
            let dbRef = Database.database().reference().child("users/\(uid)/profileImageUrl")
            try await dbRef.setValue(downloadURL.absoluteString)
            await MainActor.run { profileImageUrl = downloadURL }
        } catch { print("Upload failed: \(error.localizedDescription)") } // Indicates an error in compression/storage of the image URL in the target destination
    }
    // MARK: - Like/unlike post
    private func toggleLike(for post: Post) {
        guard let uid = Auth.auth().currentUser?.uid else { return } // Ensures user is authenticated before continuing
        let postRef = Database.database().reference().child("posts/\(post.id)") // Assigns the specific target post id to the functions
        
        var updatedPost = post
        if post.isLikedByCurrentUser {
            updatedPost.likes -= 1 // Removes current like if already liked by suer
        } else {
            updatedPost.likes += 1 // Adds like if not already liked by current user
        }
        updatedPost.isLikedByCurrentUser.toggle() // Toggles whether the post has been liked by the user
        
        if let index = userPosts.firstIndex(where: { $0.id == post.id }) {
            userPosts[index] = updatedPost
        }
        
        // Update Firebase data with transaction
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
    
    // MARK: - Load and observe follow counts
    private func loadFollowCounts() async { // Loads initial follow/following counts
        guard let uid = Auth.auth().currentUser?.uid else { return } // Ensures user is authenticated before continuing
        let ref = Database.database().reference().child("users").child(uid) // Retrieves the specific data stored under the current active user
        do {
            let snapshot = try await ref.getData()
            if let userData = snapshot.value as? [String: Any] {
                let followers = userData["followers"] as? [String: Bool] ?? [:]
                let following = userData["following"] as? [String: Bool] ?? [:]
                await MainActor.run {
                    self.followersCount = followers.count
                    self.followingCount = following.count
                } // Retrieves the stored value of followers/following of a specific account
            }
        } catch {
            print("Failed to load follow counts: \(error.localizedDescription)") // Prints error if followers/following are unable to be retrieved from firebase
        }
    }
    private func observeFollowCounts() { // Observes follow counts for changes/updates
        guard let uid = Auth.auth().currentUser?.uid else { return } // Ensures user is authenticated before continuing
        let ref = Database.database().reference().child("users").child(uid)
        
        ref.observe(.value) { snapshot in
            if let userData = snapshot.value as? [String: Any] {
                let followers = userData["followers"] as? [String: Bool] ?? [:]
                let following = userData["following"] as? [String: Bool] ?? [:]
                DispatchQueue.main.async {
                    self.followersCount = followers.count
                    self.followingCount = following.count
                }
            }
        }
    }
}
// MARK: - Comment Model
struct Comment: Identifiable {
    let id: String // Unique Firebase comment ID
    let userId: String // ID of the user who posted the comment
    let username: String // Display name of the user
    let userProfileUrl: String? // Optional profile image URL
    let text: String // Comment content
    let timestamp: Double // Rimestamp of comment creation
}
// MARK: - Comments View
struct CommentsView: View {
    let postId: String // The ID of the post that is having comments displayed
    @State private var comments: [Comment] = [] // All comments for this post
    @State private var newComment: String = "" // Text input for new comment
    @State private var isLoading = true // Show loading state until comments are fetched

    var body: some View {
        VStack {
            if isLoading { // Loading and Empty States
                ProgressView("Loading comments...")
                    .padding()
            } else if comments.isEmpty { // If no comments are stored within the post ID
                Text("No comments yet.")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                // MARK: - Display Comments
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(comments) { comment in
                            HStack(alignment: .top, spacing: 10) {
                                if let url = comment.userProfileUrl.flatMap(URL.init) { // Profile Image
                                    AsyncImage(url: url) { image in
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
                                        .overlay(Image(systemName: "person.fill").foregroundColor(.white))
                                }
                                
                                VStack(alignment: .leading, spacing: 4) { // Comment Content
                                    Text(comment.username)
                                        .font(.subheadline)
                                        .bold()
                                    Text(comment.text)
                                        .font(.body)
                                    Text(Date(timeIntervalSince1970: comment.timestamp)
                                        .formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                } // Displays all data attached to the posted comment
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            Spacer()

            // MARK: - Input Field for New Comment
            HStack {
                TextField("Add a comment...", text: $newComment)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button(action: postComment) {
                    Text("Send").bold()
                }
                .disabled(newComment.isEmpty) // Disable send button if empty
            }
            .padding()
        }
        .navigationTitle("Comments")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            observeComments()
        }
    }
    // MARK: - Fetch and Listen for Comments
    private func observeComments() {
        let ref = Database.database().reference()
            .child("posts").child(postId).child("comments") // Retrieves the specific postID to load relevant comments
        
        ref.observe(.value) { snapshot in
            var fetched: [Comment] = []
            let group = DispatchGroup()  // Ensure all user data is fetched before updating UI
            
            for case let child as DataSnapshot in snapshot.children {  // Fetch user info for each comment
                if let data = child.value as? [String: Any],
                   let userId = data["userID"] as? String,
                   let text = data["text"] as? String,
                   let timestamp = data["timestamp"] as? Double {
                    
                    group.enter()
                    Database.database().reference().child("users").child(userId)
                        .observeSingleEvent(of: .value) { userSnapshot in
                            let userData = userSnapshot.value as? [String: Any]
                            let username = userData?["username"] as? String ?? "Unknown"
                            let profileImageUrl = userData?["profileImageUrl"] as? String
                            
                            let comment = Comment(
                                id: child.key,
                                userId: userId,
                                username: username,
                                userProfileUrl: profileImageUrl,
                                text: text,
                                timestamp: timestamp
                            )
                            fetched.append(comment)
                            group.leave()
                        } // Retrieves all comment information required to display the comment under target post
                }
            }
            
            // Once all user data is loaded, update UI
            group.notify(queue: .main) {
                self.comments = fetched.sorted { $0.timestamp < $1.timestamp }
                self.isLoading = false
            }
        }
    }
    // MARK: - Post a New Comment
    private func postComment() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ref = Database.database().reference()
            .child("posts").child(postId).child("comments").childByAutoId()
        
        let data: [String: Any] = [
            "userID": uid,
            "text": newComment,
            "timestamp": Date().timeIntervalSince1970
        ] // Sets relevant information of the comment posted, ready to be stored within Firebase
        
        ref.setValue(data)
        newComment = "" // Clear input after posting
    }
}


#Preview {
    ProfileView()
}
