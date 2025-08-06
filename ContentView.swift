import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseCore
import FirebaseDatabase

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    FirebaseApp.configure()
    return true
}

struct ContentView: View {
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var username = ""
    @State private var loggedIn = false
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        NavigationView {
            ZStack {
                // Gradient background
                RadialGradient(colors: [Color.palegreen, Color.ggreen], center: .center, startRadius: 100, endRadius: 350)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Logo
                    Image("leafly")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 400, height: 150)
                    
                    // Form Container
                    VStack(spacing: 20) {
                        
                        // TextFields
                        TextField("Email…", text: $email)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                        
                        SecureField("Password…", text: $password)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                        
                        // Log in button
                        Button(action: {
                            signInUser()
                        }) {
                            Text("Log in")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.ggreen)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .fullScreenCover(isPresented: $loggedIn) {
                            ProfileView()
                        }
                        
                        // Forgot password and Sign up links
                        VStack(spacing: 10) {
                            NavigationLink(destination: SignupView()) {
                                Text("Don’t have an account yet?")
                                    .foregroundColor(.gray)
                                    .underline()
                            }
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(25)
                    .padding(.horizontal)
                }
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))}
    }
    
    private func signInUser() {
            guard !email.isEmpty, !password.isEmpty else {
                alertMessage = "Please enter both email and password."
                showingAlert = true
                return
            }

            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                if let error = error {
                    print("Error signing in: \(error.localizedDescription)")
                    alertMessage = error.localizedDescription
                    showingAlert = true
                } else {
                    print("User successfully logged in! AuthManager's listener will update.")
                    self.loggedIn = true
                    // No need to directly set authManager.isAuthenticated here;
                    // the `AuthManager`'s internal listener (in its init) will detect
                    // the sign-in and automatically update its @Published isAuthenticated.
                }
            }
    }
}

struct SignupView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var emailError: String?
    @State private var passwordError: String?
    @State private var usernameError: String?
    @State private var errorMessage: String?
    @State private var isSignupSuccessful = false
    @State private var isCheckingAvailability = false
    
    var body: some View {
        NavigationView {
            ZStack {
                RadialGradient(colors: [Color.palegreen, Color.ggreen], center: .center, startRadius: 100, endRadius: 350)
                    .ignoresSafeArea()
                
                VStack {
                    Image("leafly")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 400, height: 150)
                    
                    VStack(spacing: 20) {
                        Text("Create Account")
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                        
                        // Email Field
                        VStack(alignment: .leading, spacing: 5) {
                            TextField("Email", text: $email)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .padding(.horizontal)
                                .onChange(of: email) { _ in validateEmail() }
                            
                            if let emailError = emailError {
                                Text(emailError)
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .padding(.horizontal)
                            }
                        }
                        
                        // Username Field
                        VStack(alignment: .leading, spacing: 5) {
                            TextField("Username", text: $username)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .padding(.horizontal)
                                .onChange(of: username) { _ in validateUsername() }
                            
                            if let usernameError = usernameError {
                                Text(usernameError)
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .padding(.horizontal)
                            }
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 5) {
                            SecureField("Password", text: $password)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .padding(.horizontal)
                                .onChange(of: password) { _ in validatePassword() }
                            
                            if let passwordError = passwordError {
                                Text(passwordError)
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .padding(.horizontal)
                            }
                        }
                        
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .padding(.top, 5)
                        }
                        
                        Button("Sign Up") {
                            signupUser()
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.ggreen)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .disabled(!isFormValid || isCheckingAvailability)
                        
                        .fullScreenCover(isPresented: $isSignupSuccessful) {
                            successView()
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(25)
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Live Validation
    private var isFormValid: Bool {
        return emailError == nil && passwordError == nil && usernameError == nil && !email.isEmpty && !password.isEmpty && !username.isEmpty
    }
    
    private func validateEmail() {
        if email.isEmpty {
            emailError = "Email is required."
        } else if !isValidEmail(email) {
            emailError = "Enter a valid email address."
        } else {
            emailError = nil
        }
    }
    
    private func validatePassword() {
        if password.isEmpty {
            passwordError = "Password is required."
        } else if !isValidPassword(password) {
            passwordError = "Must be 8+ characters, include 1 uppercase and 1 special character."
        } else {
            passwordError = nil
        }
    }
    
    private func validateUsername() {
        if username.isEmpty {
            usernameError = "Username is required."
        } else if username.count < 3 {
            usernameError = "Username must be at least 3 characters."
        } else {
            usernameError = nil
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^\S+@\S+\.\S+$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
    
    private func isValidPassword(_ password: String) -> Bool {
        let passwordRegex = #"^(?=.*[A-Z])(?=.*[!@#$&*.,?]).{8,}$"#
        return password.range(of: passwordRegex, options: .regularExpression) != nil
    }
    
    // MARK: - Signup Logic
    private func signupUser() {
        validateEmail()
        validatePassword()
        validateUsername()
        
        guard isFormValid else { return }
        
        isCheckingAvailability = true
        checkUsernameAndEmailAvailability(username: username, email: email) { available, error in
            guard available else {
                self.isCheckingAvailability = false
                self.errorMessage = error ?? "Username or email already in use."
                return
            }
            
            // Proceed with signup
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.isCheckingAvailability = false
                } else {
                    guard let uid = result?.user.uid else { return }
                    
                    let ref = Database.database().reference()
                    let userData: [String: Any] = ["email": email, "username": username]
                    ref.child("users").child(uid).setValue(userData) { error, _ in
                        self.isCheckingAvailability = false
                        if let error = error {
                            self.errorMessage = "Failed to save user info."
                        } else {
                            self.isSignupSuccessful = true
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Check Username & Email Uniqueness
    private func checkUsernameAndEmailAvailability(username: String, email: String, completion: @escaping (Bool, String?) -> Void) {
        let ref = Database.database().reference().child("users")
        ref.observeSingleEvent(of: .value) { snapshot in
            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let userData = snap.value as? [String: Any] {
                    if let existingUsername = userData["username"] as? String, existingUsername.lowercased() == username.lowercased() {
                        completion(false, "Username already taken.")
                        return
                    }
                    if let existingEmail = userData["email"] as? String, existingEmail.lowercased() == email.lowercased() {
                        completion(false, "Email already registered.")
                        return
                    }
                }
            }
            completion(true, nil)
        }
    }
    
    struct successView: View {
        @State private var returntologin = false
        var body: some View {
            ZStack {
                RadialGradient(colors: [Color.palegreen, Color.ggreen], center: .center, startRadius: 100, endRadius: 350)
                    .ignoresSafeArea()
                VStack {
                    Button("Return to login") {
                        returntologin.toggle()
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.ggreen)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .fullScreenCover(isPresented: $returntologin) {
                        ContentView()
                    }
                }
            }
        }
    }
}


#Preview {
    ContentView()
}
