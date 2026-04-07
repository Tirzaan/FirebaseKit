# FirebaseKit

A Swift Package that wraps the Firebase iOS SDK, providing a clean and simple interface for Authentication, Firestore, and Storage.

---

## Requirements

- iOS 16+
- macOS 13+
- Xcode 15+
- Swift 5.9+

---

## Installation

### Adding to a Project

1. Open your app project in Xcode
2. **File → Add Package Dependencies → Add Local**
3. Navigate to the `FirebaseKit` folder and click **Add Package**
4. Make sure `FirebaseKit` is checked and added to your app target
5. Drag `GoogleService-Info.plist` into your app target — check **Copy items if needed**

### Configure at Launch

In your `@main` App struct:

```swift
import SwiftUI
import FirebaseKit

@main
struct MyApp: App {

    init() {
        FirebaseManager.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

Then add `import FirebaseKit` to any file that needs it.

---

## Services

All three services support both singleton and custom instance usage:

```swift
// Singleton (recommended for most cases)
AuthService.shared
FirestoreService.shared
StorageService.shared

// Custom instance (useful for testing)
let auth = AuthService(auth: mockAuth)
let db = FirestoreService(db: mockFirestore)
let storage = StorageService(storage: mockStorage)
```

---

## AuthService

### Current User

```swift
AuthService.shared.currentUser      // User?
AuthService.shared.isSignedIn       // Bool
AuthService.shared.userID           // String?
AuthService.shared.userEmail        // String?
AuthService.shared.displayName      // String?
AuthService.shared.isEmailVerified  // Bool
```

### Email & Password

```swift
// Sign up
_ = try await AuthService.shared.signUp(email: email, password: password)

// Sign in
_ = try await AuthService.shared.signIn(email: email, password: password)

// Sign out
try AuthService.shared.signOut()

// Reset password
try await AuthService.shared.resetPassword(email: email)

// Update password
try await AuthService.shared.updatePassword(newPassword: newPassword)

// Update email
try await AuthService.shared.updateEmail(newEmail: newEmail)

// Send email verification
try await AuthService.shared.sendEmailVerification()
```

### Google Sign-In

Requires the GoogleSignIn SDK in your app to obtain the tokens.

```swift
_ = try await AuthService.shared.signInWithGoogle(
    idToken: idToken,
    accessToken: accessToken
)
```

### Apple Sign-In

Requires `AuthenticationServices` in your app to obtain the token and nonce.

```swift
_ = try await AuthService.shared.signInWithApple(
    idToken: idToken,
    nonce: nonce
)
```

### Phone Number

```swift
// Step 1 — send verification code
let verificationID = try await AuthService.shared.sendPhoneVerification(
    phoneNumber: "+11234567890"
)

// Step 2 — sign in with the code the user received
_ = try await AuthService.shared.signInWithPhone(
    verificationID: verificationID,
    verificationCode: code
)
```

### Anonymous

```swift
// Sign in anonymously
_ = try await AuthService.shared.signInAnonymously()

// Link anonymous account to email to preserve data
_ = try await AuthService.shared.linkAnonymousAccount(
    email: email,
    password: password
)
```

### Account Management

```swift
// Delete account
try await AuthService.shared.deleteAccount()

// Re-authenticate before sensitive operations
try await AuthService.shared.reAuthenticate(email: email, password: password)
```

### Auth State Listener

```swift
let handle = AuthService.shared.addAuthStateListener { user in
    if let user = user {
        print("Signed in as \(user.uid)")
    } else {
        print("Signed out")
    }
}

// Remove listener when done
AuthService.shared.removeAuthStateListener(handle)
```

---

## FirestoreService

```swift
// Fetch a single Codable document
let user: UserModel = try await FirestoreService.shared.fetch(
    collection: "users",
    documentID: uid
)

// Save a Codable document (must be Identifiable with String ID)
try await FirestoreService.shared.save(user, collection: "users")

// Listen to a collection in real time
let listener = FirestoreService.shared.listen(collection: "messages") { (messages: [Message]) in
    self.messages = messages
}

// Stop listening
listener.remove()
```

Your models must conform to `Codable` for fetch/save, and `Identifiable` with `String` ID for save:

```swift
struct UserModel: Codable, Identifiable {
    var id: String
    var name: String
    var email: String
}
```

---

## StorageService

```swift
// Upload Data (e.g. image bytes) — returns download URL
let url = try await StorageService.shared.upload(
    data: imageData,
    path: "avatars/\(userID).jpg",
    mimeType: "image/jpeg"
)

// Upload a local file by URL — returns download URL
let url = try await StorageService.shared.uploadFile(
    localURL: fileURL,
    path: "documents/\(fileID).pdf"
)

// Download as Data
let data = try await StorageService.shared.download(path: "avatars/\(userID).jpg")
let image = UIImage(data: data)

// Get a download URL
let url = try await StorageService.shared.downloadURL(path: "avatars/\(userID).jpg")

// Delete a file
try await StorageService.shared.delete(path: "avatars/\(userID).jpg")
```

### Recommended Path Structure

```
avatars/{userID}.jpg
documents/{userID}/{fileID}.pdf
attachments/{taskID}/{fileName}
progress/{userID}/{date}.jpg
```

---

## Calling from a Button

Button actions are synchronous — wrap async calls in a `Task`:

```swift
Button("Sign Up") {
    Task {
        await signUp()
    }
}

func signUp() async {
    do {
        _ = try await AuthService.shared.signUp(email: email, password: password)
    } catch {
        print(error.localizedDescription)
    }
}
```

---

## Firebase Console Setup

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Create or select a project
3. Click **Add App → iOS** and enter your Bundle ID
4. Download `GoogleService-Info.plist` and add it to your app target
5. Enable the auth providers you need under **Authentication → Sign-in method**

---

## License

MIT
