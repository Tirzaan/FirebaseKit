//
//  FirebaseManager.swift
//  FirebaseKit
//
//  Created by Tirzaan on 4/4/26.
//

import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

public final class FirebaseManager {
    
    public static let shared = FirebaseManager()
    
    public let auth: Auth
    public let database: Firestore
    
    private init() {
        // FirebaseApp.configure() must be called before this
        self.auth = Auth.auth()
        self.database = Firestore.firestore()
    }
    
    // MARK: - Configure
    /// Call this once at app launch, before using shared
    public static func configure() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }
}
