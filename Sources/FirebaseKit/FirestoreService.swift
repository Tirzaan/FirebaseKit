//
//  FirestoreService.swift
//  FirebaseKit
//
//  Created by Tirzaan on 4/5/26.
//

// Sources/FirebaseKit/FirestoreService.swift
import CryptoKit
import FirebaseFirestore
import Foundation
import SecureCodable

public struct EncryptedFirestoreDocument: Codable {
    public let encryptedValue: String
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        encryptedValue: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.encryptedValue = encryptedValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public final class FirestoreService {
    
    public static let shared = FirestoreService()
    
    private let database: Firestore
    
    private init() {
        self.database = Firestore.firestore()
    }
    
    public init(database: Firestore = Firestore.firestore()) {
        self.database = database
    }
    
    /// Fetch a Codable document
    public func fetch<T: Decodable>(
        collection: String,
        documentID: String
    ) async throws -> T {
        let snapshot = try await database.collection(collection).document(documentID).getDocument()
        return try snapshot.data(as: T.self)
    }

    /// Fetch and decrypt a Codable document saved with saveEncrypted.
    public func fetchEncrypted<T: Decodable>(
        collection: String,
        documentID: String,
        as type: T.Type,
        using key: SymmetricKey
    ) async throws -> T {
        let encryptedDocument: EncryptedFirestoreDocument = try await fetch(
            collection: collection,
            documentID: documentID
        )

        return try encryptedDocument.encryptedValue.decrypted(as: type, using: key)
    }

    /// Fetch and decrypt a Codable document using the current user's FirebaseKit-managed data key.
    public func fetchEncrypted<T: Decodable>(
        collection: String,
        documentID: String,
        as type: T.Type,
        passphrase: String,
        userID: String? = nil
    ) async throws -> T {
        let key = try await FirebaseEncryptionService.shared.dataKey(
            passphrase: passphrase,
            userID: userID
        )

        return try await fetchEncrypted(
            collection: collection,
            documentID: documentID,
            as: type,
            using: key
        )
    }
    
    public func fetchRaw(
        collection: String,
        documentID: String
    ) async throws -> [String: Any] {
        let snapshot = try await database.collection(collection).document(documentID).getDocument()
        return snapshot.data() ?? [:]
    }
    
    /// Fetch all Codable documents in a collection
    public func fetchAll<T: Decodable>(
        collection: String,
        as type: T.Type
    ) async throws -> [T] {
        let snapshot = try await database.collection(collection).getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: T.self) }
    }
    
    /// Fetch and decrypt all Codable documents in a collection saved with saveEncrypted.
    public func fetchAllEncrypted<T: Decodable>(
        collection: String,
        as type: T.Type,
        using key: SymmetricKey
    ) async throws -> [T] {
        let encryptedDocuments: [EncryptedFirestoreDocument] = try await fetchAll(collection: collection, as: EncryptedFirestoreDocument.self)
        var decryptedDocuments: [T] = []
        
        for encryptedDocument in encryptedDocuments {
            decryptedDocuments.append(try encryptedDocument.encryptedValue.decrypted(as: type, using: key))
        }
        
        return decryptedDocuments
    }
    
    public func fetchAll<T: Decodable>(
        collection: String,
        limit: Int,
        as type: T.Type
    ) async throws -> [T] {
        let snapshot = try await database.collection(collection).limit(to: limit).getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: T.self) }
    }
    
    /// Fetch and decrypt all Codable documents in a collection saved with saveEncrypted.
    public func fetchAllEncrypted<T: Decodable>(
        collection: String,
        limit: Int,
        as type: T.Type,
        using key: SymmetricKey
    ) async throws -> [T] {
        let encryptedDocuments: [EncryptedFirestoreDocument] = try await fetchAll(collection: collection, limit: limit, as: EncryptedFirestoreDocument.self)
        var decryptedDocuments: [T] = []
        
        for encryptedDocument in encryptedDocuments {
            decryptedDocuments.append(try encryptedDocument.encryptedValue.decrypted(as: type, using: key))
        }
        
        return decryptedDocuments
    }
    
    public func fetchField<T>(
        collection: String,
        documentID: String,
        field: String,
        as type: T.Type
    ) async throws -> T? {
        let data = try await fetchRaw(collection: collection, documentID: documentID)
        return data[field] as? T
    }
    
    /// Fetch and decrypt a Codable document saved with saveEncrypted.
//    public func fetchEncryptedField<T: Decodable>(
//        collection: String,
//        documentID: String,
//        field: String,
//        as type: T.Type,
//        using key: SymmetricKey
//    ) async throws -> T? {
//        guard let encryptedDocument = try await fetchField(
//            collection: collection,
//            documentID: documentID,
//            field: field,
//            as: EncryptedFirestoreDocument.self
//        ) else {
//            return nil
//        }
//
//        do {
//            return try encryptedDocument.encryptedValue.decrypted(as: type, using: key)
//        } catch {
//            return nil
//        }
//    }
    
    /// Fetch all documents in a subcollection
    public func fetchSubcollection<T: Decodable>(
        collection: String,
        documentID: String,
        subcollection: String,
        as type: T.Type
    ) async throws -> [T] {
        let snapshot = try await database.collection(collection).document(documentID).collection(subcollection).getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: T.self) }
    }

    /// Fetch and decrypt all documents in a subcollection saved with saveEncryptedToSubcollection.
    public func fetchEncryptedSubcollection<T: Decodable>(
        collection: String,
        documentID: String,
        subcollection: String,
        as type: T.Type,
        using key: SymmetricKey
    ) async throws -> [T] {
        let snapshot = try await database.collection(collection).document(documentID).collection(subcollection).getDocuments()

        return snapshot.documents.compactMap { document in
            guard let encryptedValue = document.data()["encryptedValue"] as? String else {
                return nil
            }

            return try? encryptedValue.decrypted(as: type, using: key)
        }
    }

    /// Fetch and decrypt all documents in a subcollection using the current user's FirebaseKit-managed data key.
    public func fetchEncryptedSubcollection<T: Decodable>(
        collection: String,
        documentID: String,
        subcollection: String,
        as type: T.Type,
        passphrase: String,
        userID: String? = nil
    ) async throws -> [T] {
        let key = try await FirebaseEncryptionService.shared.dataKey(
            passphrase: passphrase,
            userID: userID
        )

        return try await fetchEncryptedSubcollection(
            collection: collection,
            documentID: documentID,
            subcollection: subcollection,
            as: type,
            using: key
        )
    }
    
    public func fetchPaginated<T: Decodable>(
        collection: String,
        orderBy field: String,
        descending: Bool = false,
        limit: Int = 20,
        after lastDocument: DocumentSnapshot? = nil,
        as type: T.Type
    ) async throws -> (items: [T], lastDocument: DocumentSnapshot?) {
        var query = database.collection(collection)
            .order(by: field, descending: descending)
            .limit(to: limit)
        
        if let lastDocument = lastDocument {
            query = query.start(afterDocument: lastDocument)
        }
        
        let snapshot = try await query.getDocuments()
        let items = snapshot.documents.compactMap { try? $0.data(as: T.self) }
        let lastDoc = snapshot.documents.last
        return (items, lastDoc)
    }

    /// Save a document to a subcollection
    public func saveToSubcollection<T: Encodable & Identifiable>(
        _ object: T,
        collection: String,
        documentID: String,
        subcollection: String
    ) async throws where T.ID == String {
        try database.collection(collection).document(documentID).collection(subcollection).document(object.id).setData(from: object)
    }

    /// Encrypt and save a Codable document to a subcollection.
    public func saveEncryptedToSubcollection<T: Encodable & Identifiable>(
        _ object: T,
        collection: String,
        documentID: String,
        subcollection: String,
        using key: SymmetricKey
    ) async throws where T.ID == String {
        let encryptedValue = try object.encrypted(using: key)
        let encryptedDocument = EncryptedFirestoreDocument(encryptedValue: encryptedValue)

        try database.collection(collection)
            .document(documentID)
            .collection(subcollection)
            .document(object.id)
            .setData(from: encryptedDocument)
    }

    /// Encrypt and save a Codable document to a subcollection using the current user's FirebaseKit-managed data key.
    public func saveEncryptedToSubcollection<T: Encodable & Identifiable>(
        _ object: T,
        collection: String,
        documentID: String,
        subcollection: String,
        passphrase: String,
        userID: String? = nil
    ) async throws where T.ID == String {
        let key = try await FirebaseEncryptionService.shared.dataKey(
            passphrase: passphrase,
            userID: userID
        )

        try await saveEncryptedToSubcollection(
            object,
            collection: collection,
            documentID: documentID,
            subcollection: subcollection,
            using: key
        )
    }
    
    /// Save a Codable document
    public func save<T: Encodable & Identifiable>(
        _ object: T,
        collection: String
    ) async throws where T.ID == String {
        try database.collection(collection).document(object.id).setData(from: object)
    }

    /// Encrypt and save a Codable document using its String id.
    public func saveEncrypted<T: Encodable & Identifiable>(
        _ object: T,
        collection: String,
        using key: SymmetricKey
    ) async throws where T.ID == String {
        try await saveEncrypted(
            object,
            collection: collection,
            documentID: object.id,
            using: key
        )
    }

    /// Encrypt and save a Codable document using its String id and the current user's FirebaseKit-managed data key.
    public func saveEncrypted<T: Encodable & Identifiable>(
        _ object: T,
        collection: String,
        passphrase: String,
        userID: String? = nil
    ) async throws where T.ID == String {
        let key = try await FirebaseEncryptionService.shared.dataKey(
            passphrase: passphrase,
            userID: userID
        )

        try await saveEncrypted(
            object,
            collection: collection,
            using: key
        )
    }

    /// Encrypt and save any Codable value to a specific document id.
    public func saveEncrypted<T: Encodable>(
        _ object: T,
        collection: String,
        documentID: String,
        using key: SymmetricKey
    ) async throws {
        let encryptedValue = try object.encrypted(using: key)
        let encryptedDocument = EncryptedFirestoreDocument(encryptedValue: encryptedValue)

        try database.collection(collection)
            .document(documentID)
            .setData(from: encryptedDocument)
    }

    /// Encrypt and save any Codable value to a specific document id using the current user's FirebaseKit-managed data key.
    public func saveEncrypted<T: Encodable>(
        _ object: T,
        collection: String,
        documentID: String,
        passphrase: String,
        userID: String? = nil
    ) async throws {
        let key = try await FirebaseEncryptionService.shared.dataKey(
            passphrase: passphrase,
            userID: userID
        )

        try await saveEncrypted(
            object,
            collection: collection,
            documentID: documentID,
            using: key
        )
    }
    
    /// Delete a document
    public func delete(
        collection: String,
        documentID: String
    ) async throws {
        try await database.collection(collection).document(documentID).delete()
    }
    
    /// Delete a field in a document
    public func deleteField(
        collection: String,
        documentID: String,
        field: String
    ) async throws {
        try await database.collection(collection).document(documentID).updateData([
            field: FieldValue.delete()
        ])
    }
    
    public func updateFields(
        collection: String,
        documentID: String,
        fields: [String: Any]
    ) async throws {
        try await database.collection(collection).document(documentID).updateData(fields)
    }
    
    /// Listen to a collection in real time
    public func listen<T: Decodable>(
        collection: String,
        onChange: @escaping ([T]) -> Void
    ) -> ListenerRegistration {
        database.collection(collection).addSnapshotListener { snapshot, _ in
            guard let docs = snapshot?.documents else { return }
            let items = docs.compactMap { try? $0.data(as: T.self) }
            onChange(items)
        }
    }
    
    public func listenToDocument<T: Decodable>(
        collection: String,
        documentID: String,
        as type: T.Type,
        onChange: @escaping (T?) -> Void
    ) -> ListenerRegistration {
        database.collection(collection).document(documentID).addSnapshotListener { snapshot, _ in
            guard let snapshot = snapshot else { onChange(nil); return }
            onChange(try? snapshot.data(as: T.self))
        }
    }
    
    public func listenToSubcollection<T: Decodable>(
        collection: String,
        documentID: String,
        subcollection: String,
        orderBy field: String,
        descending: Bool = false,
        limit: Int? = nil,
        as type: T.Type,
        onChange: @escaping ([T]) -> Void
    ) -> ListenerRegistration {
        var query: Query = database.collection(collection).document(documentID).collection(subcollection).order(by: field, descending: descending)
        if let limit = limit { query = query.limit(to: limit) }
        return query.addSnapshotListener { snapshot, _ in
            guard let docs = snapshot?.documents else { return }
            let items = docs.compactMap { try? $0.data(as: T.self) }
            onChange(items)
        }
    }
    
    /// Listen to a collection in real time, decrypting each document's field.
    public func listenEncrypted<T: Decodable>(
        collection: String,
        as type: T.Type,
        using key: SymmetricKey,
        onChange: @escaping ([T]) -> Void
    ) -> ListenerRegistration {
        database.collection(collection).addSnapshotListener { snapshot, _ in
            guard let docs = snapshot?.documents else { return }
            let items: [T] = docs.compactMap { doc in
                guard let encryptedDocument = try? doc.data(as: EncryptedFirestoreDocument.self) else {
                    return nil
                }
                return try? encryptedDocument.encryptedValue.decrypted(as: type, using: key)
            }
            onChange(items)
        }
    }

    /// Listen to a single document in real time, decrypting its field.
//    public func listenToEncryptedDocument<T: Decodable>(
//        collection: String,
//        documentID: String,
//        as type: T.Type,
//        using key: SymmetricKey,
//        onChange: @escaping (T?) -> Void
//    ) -> ListenerRegistration {
//        database.collection(collection).document(documentID).addSnapshotListener { snapshot, _ in
//            guard let snapshot = snapshot,
//                  let encryptedDocument = try? snapshot.data(as: EncryptedFirestoreDocument.self) else {
//                onChange(nil)
//                return
//            }
//            onChange(try? encryptedDocument.encryptedValue.decrypted(as: type, using: key))
//        }
//    }

    /// Listen to a subcollection in real time, decrypting each document's field.
    public func listenToEncryptedSubcollection<T: Decodable>(
        collection: String,
        documentID: String,
        subcollection: String,
        orderBy field: String,
        descending: Bool = false,
        limit: Int? = nil,
        as type: T.Type,
        using key: SymmetricKey,
        onChange: @escaping ([T]) -> Void
    ) -> ListenerRegistration {
        var query: Query = database.collection(collection).document(documentID).collection(subcollection).order(by: field, descending: descending)
        if let limit = limit { query = query.limit(to: limit) }
        return query.addSnapshotListener { snapshot, _ in
            guard let docs = snapshot?.documents else { return }
            let items: [T] = docs.compactMap { doc in
                guard let encryptedDocument = try? doc.data(as: EncryptedFirestoreDocument.self) else {
                    return nil
                }
                return try? encryptedDocument.encryptedValue.decrypted(as: type, using: key)
            }
            onChange(items)
        }
    }
    
    public func query<T: Decodable>(
        collection: String,
        field: String,
        isEqualTo value: Any,
        as type: T.Type
    ) async throws -> [T] {
        let snapshot = try await database.collection(collection)
            .whereField(field, isEqualTo: value)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: T.self) }
    }

    // More query options
    public func queryWhere<T: Decodable>(
        collection: String,
        field: String,
        in values: [Any],
        as type: T.Type
    ) async throws -> [T] {
        let snapshot = try await database.collection(collection)
            .whereField(field, in: values)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: T.self) }
    }

    public func queryOrdered<T: Decodable>(
        collection: String,
        orderBy field: String,
        descending: Bool = false,
        limit: Int? = nil,
        as type: T.Type
    ) async throws -> [T] {
        var query: Query = database.collection(collection).order(by: field, descending: descending)
        if let limit = limit { query = query.limit(to: limit) }
        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: T.self) }
    }
}
