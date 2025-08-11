import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseCore
import FirebaseDatabase

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    FirebaseApp.configure()
    return true
} // Configuring firebase

struct ContentView: View {
    
    @State private var email: String = "" //for users to enter
    @State private var password: String = "" // for users to enter
    @State private var showingAlert = false // activated when input is incorrect
    @State private var alertMessage = "" // displays specific alert depending on the input causing the alert
    @State private var username = "" // for users to enter
    @State private var loggedIn = false // determines whether user has logged in to a valid account or not
    @EnvironmentObject var authManager: AuthManager // authenticates users
    
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
                    
                    VStack(spacing: 20) {
                        
                        // TextFields for users to enter
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
                            signInUser() // directs to sign in page
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
                            ProfileView() //directs to profile page if the data entered is authenticated
                        }
                        
                        //Sign up links
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
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))} // establishes alerts to be activated if inputs are invalid, setting the message to specify the invalid field
    }
    
    private func signInUser() {
            guard !email.isEmpty, !password.isEmpty else {
                alertMessage = "Please enter both email and password."
                showingAlert = true
                return
            } // if either field has been left empty, the alert will be didsplayed

            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                if let error = error {
                    print("Error signing in: \(error.localizedDescription)")
                    alertMessage = error.localizedDescription
                    showingAlert = true // if the email and password are not correct/do not link to a valid account, the alert will display with the information
                } else {
                    print("User successfully logged in! AuthManager's listener will update.")
                    self.loggedIn = true
                        //user is authenticated and will be directed to the login page
                }
            }
    }
}

struct SignupView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var username = "" //For user to enter
    @State private var emailError: String?
    @State private var passwordError: String?
    @State private var usernameError: String?
    @State private var errorMessage: String? //Specific errors with certain fields
    @State private var isSignupSuccessful = false // If the conditions to sign up are successful
    @State private var isCheckingAvailability = false //If the username or email is not being used by a preexisting account
    
    var body: some View {
        NavigationView {
            ZStack {
                RadialGradient(colors: [Color.palegreen, Color.ggreen], center: .center, startRadius: 100, endRadius: 350)
                    .ignoresSafeArea() //Background
                
                VStack {
                    Image("leafly")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 400, height: 150) //Logo
                    
                    VStack(spacing: 20) {
                        Text("Create Account")
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .padding(.horizontal) //Heading
                        
                        //Email Field
                        VStack(alignment: .leading, spacing: 5) {
                            TextField("Email", text: $email)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .padding(.horizontal)
                                .onChange(of: email) { _ in validateEmail() }
                            //When the value of "email" is changed, the email entered will be run through the function validateEmail()
                            if let emailError = emailError { //If the email was invalid or preexisting, text will be displayed describing the error
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
                            //When the value "username" is changed as the user enters text, the text entered will be run through the function validateUsername
                            if let usernameError = usernameError {
                                Text(usernameError)
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .padding(.horizontal) //If the username is too short or preexisting, the error message will be displayed
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
                            //When the value "password" is changed as the user enters text, the text entered will be run through the function validatePassword
                            if let passwordError = passwordError {
                                Text(passwordError)
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .padding(.horizontal)
                            } //The error message will be displayed if the password entered does not satisfy requirements
                        }
                        
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .padding(.top, 5)
                        } //Displays any error message set
                        
                        Button("Sign Up") {
                            signupUser()
                        } // Runs the function signupUser when pressed
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.ggreen)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .disabled(!isFormValid || isCheckingAvailability) // Disabled if isFormValid is false or if isCheckingAvailability is true (program is still actively validating fields)
                        .fullScreenCover(isPresented: $isSignupSuccessful) {
                            successView()
                        } // Directed to successView if the signup is successful
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
    // Computed property to check if all form fields are valid and non-empty
    private var isFormValid: Bool {
        return emailError == nil && passwordError == nil && usernameError == nil && !email.isEmpty && !password.isEmpty && !username.isEmpty
    }
    // Validate the email field and set an error message if invalid
    private func validateEmail() {
        if email.isEmpty {
            emailError = "Email is required."
        } else if !isValidEmail(email) {
            emailError = "Enter a valid email address."
        } else {
            emailError = nil
        }
    }
    // Validate the password field and set an error message if invalid
    private func validatePassword() {
        if password.isEmpty {
            passwordError = "Password is required."
        } else if !isValidPassword(password) {
            passwordError = "Must be 8+ characters, include 1 uppercase and 1 special character."
        } else {
            passwordError = nil
        }
    }
    // Validate the username field and set an error message if invalid
    private func validateUsername() {
        if username.isEmpty {
            usernameError = "Username is required."
        } else if username.count < 3 {
            usernameError = "Username must be at least 3 characters."
        } else {
            usernameError = nil
        }
    }
    // Helper function to check email format using a regex
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^\S+@\S+\.\S+$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
    // Helper function to check password requirements using a regex
    private func isValidPassword(_ password: String) -> Bool {
        let passwordRegex = #"^(?=.*[A-Z])(?=.*[!@#$&*.,?]).{8,}$"#
        return password.range(of: passwordRegex, options: .regularExpression) != nil
    }
    
    // MARK: - Signup Logic
    private func signupUser() {
        // Run field validations before attempting signup
        validateEmail()
        validatePassword()
        validateUsername()
        
        guard isFormValid else { return }  // Stop if form is invalid
        
        isCheckingAvailability = true  // Indicating that the program is checking username/email availability
        
        checkUsernameAndEmailAvailability(username: username, email: email) { available, error in // Check if username and email are already taken in the database
            guard available else {
                self.isCheckingAvailability = false
                self.errorMessage = error ?? "Username or email already in use."
                return   // Availability check failed — set error and stop
            }
            
            // Create the user with Firebase Authentication
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                if let error = error {  // Handle account creation error
                    self.errorMessage = error.localizedDescription
                    self.isCheckingAvailability = false
                } else {
                    guard let uid = result?.user.uid else { return }  // Successfully created account, now save user data in Realtime Database
                    
                    let ref = Database.database().reference()
                    let userData: [String: Any] = ["email": email, "username": username]
                    ref.child("users").child(uid).setValue(userData) { error, _ in  // Save user profile info under their UID
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
        
        ref.observeSingleEvent(of: .value) { snapshot in // Fetch all existing users once
            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let userData = snap.value as? [String: Any] {
                    if let existingUsername = userData["username"] as? String, existingUsername.lowercased() == username.lowercased() {
                        completion(false, "Username already taken.")
                        return  // Check if username matches an existing one (case-insensitive)
                    }
                    if let existingEmail = userData["email"] as? String, existingEmail.lowercased() == email.lowercased() {
                        completion(false, "Email already registered.")
                        return  // Check if email matches an existing one (case-insensitive)
                    }
                }
            }
            completion(true, nil)  // If no conflicts found, mark as available
        }
    }
    
    struct successView: View {
        @State private var returntologin = false
        var body: some View {
            ZStack {
                RadialGradient(colors: [Color.palegreen, Color.ggreen], center: .center, startRadius: 100, endRadius: 350)
                    .ignoresSafeArea() // Background
                VStack {
                    Button("Return to login") {
                        returntologin.toggle() // Toggles the boolean returntologin from false to true
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.ggreen)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .fullScreenCover(isPresented: $returntologin) {
                        ContentView() // If returntologin is set to true, user is redirected to ContentView
                    }
                }
            }
        }
    }
}


#Preview {
    ContentView()
}
