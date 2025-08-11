import SwiftUI
import FirebaseDatabase
import FirebaseAuth
import Combine

class FollowService: ObservableObject {
    static let shared = FollowService()

    @Published private(set) var following: Set<String> = []

    private var ref = Database.database().reference()
    private var listenerHandle: DatabaseHandle?
    private var cancellables = Set<AnyCancellable>()

    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    private init() {
        // Automatically start listening when created
        startListening()
    }

    func startListening() {
        guard let uid = currentUserId else { return }
        let followingRef = ref.child("users").child(uid).child("following")

        // Remove old listener if any
        if let handle = listenerHandle {
            followingRef.removeObserver(withHandle: handle)
        }

        listenerHandle = followingRef.observe(.value) { [weak self] snapshot in
            var newFollowing = Set<String>()
            for child in snapshot.children {
                if let snap = child as? DataSnapshot {
                    newFollowing.insert(snap.key)
                }
            }
            DispatchQueue.main.async {
                self?.following = newFollowing
            }
        }
    }

    func stopListening() {
        guard let uid = currentUserId, let handle = listenerHandle else { return }
        ref.child("users").child(uid).child("following").removeObserver(withHandle: handle)
    }

    func isFollowing(_ userId: String) -> Bool {
        following.contains(userId)
    }

    func toggleFollow(userId: String) {
        guard let currentUserId = currentUserId else { return }
        if userId == currentUserId { return } // Cannot follow yourself

        let currentUserFollowingRef = ref.child("users").child(currentUserId).child("following").child(userId)
        let targetUserFollowersRef = ref.child("users").child(userId).child("followers").child(currentUserId)

        if isFollowing(userId) {
            currentUserFollowingRef.removeValue()
            targetUserFollowersRef.removeValue()
        } else {
            currentUserFollowingRef.setValue(true)
            targetUserFollowersRef.setValue(true)
        }
    }
}
class PostService: ObservableObject {
    static let shared = PostService()

    @Published var posts: [PostWithUser] = []

    private var ref = Database.database().reference().child("posts")
    private var listeners: [DatabaseHandle] = []
    private var currentUserID: String? { Auth.auth().currentUser?.uid }

    private init() {
        startListening()
    }

    func startListening() {
        // Remove previous observers
        listeners.forEach { ref.removeObserver(withHandle: $0) }
        listeners.removeAll()

        // Listen for new posts added
        let addedHandle = ref.observe(.childAdded) { [weak self] snapshot in
            self?.handlePostSnapshot(snapshot)
        }

        // Listen for post changes (likes, comments)
        let changedHandle = ref.observe(.childChanged) { [weak self] snapshot in
            self?.handlePostChangeSnapshot(snapshot)
        }

        listeners.append(addedHandle)
        listeners.append(changedHandle)
    }

    func stopListening() {
        listeners.forEach { ref.removeObserver(withHandle: $0) }
        listeners.removeAll()
    }

    private func handlePostSnapshot(_ snapshot: DataSnapshot) {
        guard let data = snapshot.value as? [String: Any],
              let userId = data["userID"] as? String else { return }

        // Fetch user data for the post
        Database.database().reference().child("users").child(userId)
            .observeSingleEvent(of: .value) { [weak self] userSnapshot in
                guard let self = self else { return }
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
                    isLikedByCurrentUser: (data["likedBy"] as? [String: Bool])?[self.currentUserID ?? ""] ?? false
                )

                let postWithUser = PostWithUser(
                    id: snapshot.key,
                    post: post,
                    username: username,
                    userProfileUrl: profileImageUrl
                )

                DispatchQueue.main.async {
                    if !(self.posts.contains(where: { $0.id == postWithUser.id })) {
                        self.posts.insert(postWithUser, at: 0)
                        self.posts.sort { $0.post.timestamp > $1.post.timestamp }
                    }
                }
            }
    }

    private func handlePostChangeSnapshot(_ snapshot: DataSnapshot) {
        guard let data = snapshot.value as? [String: Any] else { return }
        DispatchQueue.main.async {
            if let index = self.posts.firstIndex(where: { $0.id == snapshot.key }) {
                var updatedPost = self.posts[index].post
                updatedPost.likes = data["likes"] as? Int ?? updatedPost.likes
                updatedPost.commentsCount = data["commentsCount"] as? Int ?? updatedPost.commentsCount
                updatedPost.isLikedByCurrentUser = (data["likedBy"] as? [String: Bool])?[self.currentUserID ?? ""] ?? updatedPost.isLikedByCurrentUser

                self.posts[index] = PostWithUser(
                    id: snapshot.key,
                    post: updatedPost,
                    username: self.posts[index].username,
                    userProfileUrl: self.posts[index].userProfileUrl
                )
            }
        }
    }

    func toggleLike(postID: String) {
        guard let uid = currentUserID else { return }
        let postRef = ref.child(postID)

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

