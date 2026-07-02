//
//  FirebaseEncryptionService.swift
//  FirebaseKit
//

import CryptoKit
import FirebaseFirestore
import Foundation
import SecureCodable

public struct FirebaseEncryptionKeyDocument: Codable {
    public let wrappedDataKey: String
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        wrappedDataKey: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.wrappedDataKey = wrappedDataKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum FirebaseEncryptionError: LocalizedError {
    case missingUserID

    public var errorDescription: String? {
        switch self {
        case .missingUserID:
            return "No user id was provided and no Firebase Auth user is signed in."
        }
    }
}

public final class FirebaseEncryptionService {
    public static let shared = FirebaseEncryptionService()

    private let database: Firestore
    private let authService: AuthService
    private let keyCollection: String

    private init() {
        self.database = Firestore.firestore()
        self.authService = .shared
        self.keyCollection = "_firebasekit_encryption_keys"
    }

    public init(
        database: Firestore = Firestore.firestore(),
        authService: AuthService = .shared,
        keyCollection: String = "_firebasekit_encryption_keys"
    ) {
        self.database = database
        self.authService = authService
        self.keyCollection = keyCollection
    }

    public func dataKey(
        passphrase: String,
        userID: String? = nil
    ) async throws -> SymmetricKey {
        let documentID = try resolvedUserID(userID)
        let documentRef = database.collection(keyCollection).document(documentID)
        let snapshot = try await documentRef.getDocument()

        if snapshot.exists {
            let keyDocument = try snapshot.data(as: FirebaseEncryptionKeyDocument.self)
            return try SecureCodable.shared.unwrapDataKey(
                keyDocument.wrappedDataKey,
                passphrase: passphrase
            )
        }

        let bundle = try SecureCodable.shared.createKeyBundle(passphrase: passphrase)
        let keyDocument = FirebaseEncryptionKeyDocument(wrappedDataKey: bundle.wrappedDataKey)
        try documentRef.setData(from: keyDocument)

        return bundle.dataKey
    }

    public func wrappedDataKey(userID: String? = nil) async throws -> String {
        let documentID = try resolvedUserID(userID)
        let snapshot = try await database.collection(keyCollection).document(documentID).getDocument()
        let keyDocument = try snapshot.data(as: FirebaseEncryptionKeyDocument.self)
        return keyDocument.wrappedDataKey
    }

    public func rotatePassphrase(
        oldPassphrase: String,
        newPassphrase: String,
        userID: String? = nil
    ) async throws {
        let documentID = try resolvedUserID(userID)
        let documentRef = database.collection(keyCollection).document(documentID)
        let snapshot = try await documentRef.getDocument()
        let keyDocument = try snapshot.data(as: FirebaseEncryptionKeyDocument.self)

        let newWrappedDataKey = try SecureCodable.shared.rewrapDataKey(
            keyDocument.wrappedDataKey,
            oldPassphrase: oldPassphrase,
            newPassphrase: newPassphrase
        )

        let updatedDocument = FirebaseEncryptionKeyDocument(
            wrappedDataKey: newWrappedDataKey,
            createdAt: keyDocument.createdAt,
            updatedAt: Date()
        )

        try documentRef.setData(from: updatedDocument)
    }

    public func deleteDataKey(userID: String? = nil) async throws {
        let documentID = try resolvedUserID(userID)
        try await database.collection(keyCollection).document(documentID).delete()
    }

    private func resolvedUserID(_ userID: String?) throws -> String {
        if let userID, !userID.isEmpty {
            return userID
        }

        guard let currentUserID = authService.userID, !currentUserID.isEmpty else {
            throw FirebaseEncryptionError.missingUserID
        }

        return currentUserID
    }
}
