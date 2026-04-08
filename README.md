# FirebaseKit

A Swift Package that wraps the Firebase iOS SDK, providing a clean and simple interface for Authentication, Firestore, Storage, Analytics, Cloud Messaging, and Crashlytics.

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

### Auth State Listener

To automatically show/hide your login screen, use the auth state listener in your root view:

```swift
struct ContentView: View {
    @State private var isSignedIn = AuthService.shared.isSignedIn

    var body: some View {
        if isSignedIn {
            HomeView()
        } else {
            SignUpView()
        }
        .onAppear {
            _ = AuthService.shared.addAuthStateListener { user in
                isSignedIn = user != nil
            }
        }
    }
}
```

---

## Services

All services support both singleton and custom instance usage:

```swift
// Singleton (recommended for most cases)
AuthService.shared
FirestoreService.shared
StorageService.shared
AnalyticsService.shared
FCMService.shared
CrashlyticsService.shared

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

### Profile

```swift
// Update display name
try await AuthService.shared.updateDisplayName("John")

// Update photo URL
try await AuthService.shared.updatePhotoURL(url)
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
// Delete account — capture userID before deletion
let userID = AuthService.shared.userID ?? ""
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

### Fetch

```swift
// Fetch a single document
let user: UserModel = try await FirestoreService.shared.fetch(
    collection: "users",
    documentID: uid
)

// Fetch all documents in a collection
let users = try await FirestoreService.shared.fetchAll(
    collection: "users",
    as: UserModel.self
)

// Fetch a specific field (any type)
let tribes = try await FirestoreService.shared.fetchField(
    collection: "admin_controls",
    documentID: "tribes",
    field: "list_of_tribes",
    as: [String].self
) ?? []

// Fetch raw dictionary
let data = try await FirestoreService.shared.fetchRaw(
    collection: "admin_controls",
    documentID: "config"
)
```

### Save & Update

```swift
// Save a full document (must be Codable & Identifiable with String ID)
try await FirestoreService.shared.save(user, collection: "users")

// Update specific fields without overwriting the whole document
try await FirestoreService.shared.updateFields(
    collection: "users",
    documentID: userID,
    fields: [
        "name": "John",
        "tribe": "Red Lions"
    ]
)
```

### Delete

```swift
// Delete a document
try await FirestoreService.shared.delete(
    collection: "users",
    documentID: userID
)

// Delete a specific field
try await FirestoreService.shared.deleteField(
    collection: "users",
    documentID: userID,
    field: "tribe"
)
```

### Query

```swift
// Filter by field value
let members = try await FirestoreService.shared.query(
    collection: "users",
    field: "tribe",
    isEqualTo: "Red Lions",
    as: UserModel.self
)

// Filter by multiple values
let members = try await FirestoreService.shared.queryWhere(
    collection: "users",
    field: "tribe",
    in: ["Red Lions", "Purple Eagles"],
    as: UserModel.self
)

// Order and limit
let messages = try await FirestoreService.shared.queryOrdered(
    collection: "messages",
    orderBy: "timestamp",
    descending: true,
    limit: 10,
    as: Message.self
)
```

### Real-Time Listeners

```swift
// Listen to a collection
let listener = FirestoreService.shared.listen(collection: "messages") { (messages: [Message]) in
    self.messages = messages
}

// Listen to a single document
let listener = FirestoreService.shared.listenToDocument(
    collection: "users",
    documentID: userID,
    as: UserModel.self
) { user in
    self.user = user
}

// Stop listening
listener.remove()
```

### Subcollections

```swift
// Fetch subcollection
let messages = try await FirestoreService.shared.fetchSubcollection(
    collection: "chats",
    documentID: chatID,
    subcollection: "messages",
    as: Message.self
)

// Save to subcollection
try await FirestoreService.shared.saveToSubcollection(
    message,
    collection: "chats",
    documentID: chatID,
    subcollection: "messages"
)
```

Your models must conform to `Codable` for fetch/save, and `Identifiable` with a `String` ID for save:

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
// Upload Data — returns download URL
let url = try await StorageService.shared.upload(
    data: imageData,
    path: "avatars/\(userID).jpg",
    mimeType: "image/jpeg"
)

// Upload a local file — returns download URL
let url = try await StorageService.shared.uploadFile(
    localURL: fileURL,
    path: "documents/\(fileID).pdf"
)

// Upload with progress (0.0 to 1.0)
let url = try await StorageService.shared.uploadWithProgress(
    data: imageData,
    path: "avatars/\(userID).jpg"
) { progress in
    uploadProgress = progress
}

// Download as Data
let data = try await StorageService.shared.download(path: "avatars/\(userID).jpg")
let image = UIImage(data: data)

// Get a download URL
let url = try await StorageService.shared.downloadURL(path: "avatars/\(userID).jpg")

// List all files in a folder
let files = try await StorageService.shared.listFiles(path: "avatars/")

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

## AnalyticsService

```swift
// Track a screen
AnalyticsService.shared.logScreen(name: "SignUp")

// Track sign up / login
AnalyticsService.shared.logSignUp(method: "email")
AnalyticsService.shared.logLogin(method: "google")

// Track a custom event
AnalyticsService.shared.logEvent("tribe_selected", parameters: [
    "tribe_name": selectedTribe
])

// Track search
AnalyticsService.shared.logSearch(term: searchText)

// Track content selection
AnalyticsService.shared.logSelectContent(type: "tribe", id: tribeID)

// Set user context after sign in
AnalyticsService.shared.setUserID(AuthService.shared.userID ?? "")
AnalyticsService.shared.setUserProperty("Student", for: "role")

// Clear on sign out
AnalyticsService.shared.resetUser()
```

---

## FCMService (Push Notifications)

```swift
// Request permission at launch
try await FCMService.shared.requestPermission()

// Get device token and save to Firestore
let token = try await FCMService.shared.getToken()
try await FirestoreService.shared.updateFields(
    collection: "users",
    documentID: userID,
    fields: ["fcmToken": token]
)

// Subscribe to a topic
try await FCMService.shared.subscribeToTopic("RedLions")

// Unsubscribe from a topic
try await FCMService.shared.unsubscribeFromTopic("RedLions")

// Delete token on sign out
try await FCMService.shared.deleteToken()
```

---

## CrashlyticsService

```swift
// Set user context after sign in
CrashlyticsService.shared.setUserID(AuthService.shared.userID ?? "")

// Log breadcrumbs
CrashlyticsService.shared.log("User tapped sign out")

// Record non-fatal errors
CrashlyticsService.shared.record(error: error)

// Set extra context
CrashlyticsService.shared.setValue("Red Lions", for: "tribe")

// Clear on sign out
CrashlyticsService.shared.resetUser()
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
5. Enable auth providers under **Authentication → Sign-in method**
6. Enable Crashlytics under **Crashlytics** in the console
7. Enable Cloud Messaging under **Cloud Messaging** in the console

---

## License

MIT
