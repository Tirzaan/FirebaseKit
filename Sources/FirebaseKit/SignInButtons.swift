//
//  SignInButtons.swift
//  FirebaseKit
//
//  Created by Tirzaan on 4/9/26.
//

// Sources/FirebaseKit/SignInButtons.swift
#if canImport(UIKit)
import SwiftUI
import AuthenticationServices
import GoogleSignIn
import FirebaseAuth

public struct AppleSignInButton: View {
    
    var label: SignInWithAppleButton.Label
    var style: SignInWithAppleButton.Style
    var onSuccess: ((User) -> Void)?
    var onFailure: ((Error) -> Void)?
    
    public init(
        label: SignInWithAppleButton.Label,
        style: SignInWithAppleButton.Style,
        onSuccess: ((User) -> Void)? = nil,
        onFailure: ((Error) -> Void)? = nil
    ) {
        self.label = label
        self.style = style
        self.onSuccess = onSuccess
        self.onFailure = onFailure
    }
    
    public var body: some View {
        SignInWithAppleButton(label) { request in
            request.requestedScopes = [.fullName, .email]
            request.nonce = AppleSignInHelper.randomNonceString()
        } onCompletion: { result in
            if case .success(let auth) = result {
                AppleSignInHelper.handle(auth) { result in
                    switch result {
                    case .success(let user): onSuccess?(user)
                    case .failure(let error): onFailure?(error)
                    }
                }
            } else if case .failure(let error) = result {
                onFailure?(error)
            }
        }
        .signInWithAppleButtonStyle(style)
        .frame(height: 50)
    }
}

public enum GoogleSignInLabel: String {
    case signIn = "Sign in with Google"
    case signUp = "Sign up with Google"
    case `continue` = "Continue with Google"
}

public struct GoogleSignInButton: View {
    
    var label: GoogleSignInLabel
    var foregroundColor: Color
    var backgroundColor: Color
    var onSuccess: ((User) -> Void)?
    var onFailure: ((Error) -> Void)?
    
    public init(
        label: GoogleSignInLabel,
        foregroundColor: Color = .white,
        backgroundColor: Color = .black,
        onSuccess: ((User) -> Void)? = nil,
        onFailure: ((Error) -> Void)? = nil
    ) {
        self.label = label
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.onSuccess = onSuccess
        self.onFailure = onFailure
    }
    
    public var body: some View {
        Button {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = scene.windows.first?.rootViewController else { return }
            
            GoogleSignInService.shared.signIn(from: rootVC) { result in
                switch result {
                case .success(let user): onSuccess?(user)
                case .failure(let error): onFailure?(error)
                }
            }
        } label: {
            Text(label.rawValue)
                .font(.system(size: 16, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(backgroundColor)
                .foregroundStyle(foregroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

@available(iOS 13.0.0, *)
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.smooth(duration: 0.25), value: configuration.isPressed)
    }
}

#endif
