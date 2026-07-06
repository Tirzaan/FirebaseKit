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
}

// MARK: - Fetching

public extension FirestoreService {
    /// Fetch a Codable document
    func fetch<T: Decodable>(
        collection: String,
        documentID: String
    ) async throws -> T {
        let snapshot = try await database.collection(collection).document(documentID).getDocument()
        return try snapshot.data(as: T.self)
    }

    func fetchRaw(
        collection: String,
        documentID: String
    ) async throws -> [String: Any] {
        let snapshot = try await database.collection(collection).document(documentID).getDocument()
        return snapshot.data() ?? [:]
    }

    /// Fetch all Codable documents in a collection
    func fetchAll<T: Decodable>(
        collection: String,
        as type: T.Type
    ) async throws -> [T] {
        let snapshot = try await database.collection(collection).getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: T.self) }
    }

    func fetchAll<T: Decodable>(
        collection: String,
        limit: Int,
        as type: T.Type
    ) async throws -> [T] {
        let snapshot = try await database.collection(collection).limit(to: limit).getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: T.self) }
    }

    func fetchField<T>(
        collection: String,
        documentID: String,
        field: String,
        as type: T.Type
    ) async throws -> T? {
        let data = try await fetchRaw(collection: collection, documentID: documentID)
        return data[field] as? T
    }

    /// Fetch all documents in a subcollection
    func fetchSubcollection<T: Decodable>(
        collection: String,
        documentID: String,
        subcollection: String,
        as type: T.Type
    ) async throws -> [T] {
        let snapshot = try await database.collection(collection).document(documentID).collection(subcollection).getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: T.self) }
    }

    func fetchPaginated<T: Decodable>(
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
}

// MARK: - Saving

public extension FirestoreService {
    /// Save a Codable document
    func save<T: Encodable & Identifiable>(
        _ object: T,
        collection: String
    ) async throws where T.ID == String {
        try database.collection(collection).document(object.id).setData(from: object)
    }

    /// Save a document to a subcollection
    func saveToSubcollection<T: Encodable & Identifiable>(
        _ object: T,
        collection: String,
        documentID: String,
        subcollection: String
    ) async throws where T.ID == String {
        try database.collection(collection).document(documentID).collection(subcollection).document(object.id).setData(from: object)
    }
}

// MARK: - Deleting & Updating

public extension FirestoreService {
    /// Delete a document
    func delete(
        collection: String,
        documentID: String
    ) async throws {
        try await database.collection(collection).document(documentID).delete()
    }

    /// Delete a field in a document
    func deleteField(
        collection: String,
        documentID: String,
        field: String
    ) async throws {
        try await database.collection(collection).document(documentID).updateData([
            field: FieldValue.delete()
        ])
    }

    func updateFields(
        collection: String,
        documentID: String,
        fields: [String: Any]
    ) async throws {
        try await database.collection(collection).document(documentID).updateData(fields)
    }
}

// MARK: - Real-time Listening

public extension FirestoreService {
    /// Listen to a collection in real time
    func listen<T: Decodable>(
        collection: String,
        onChange: @escaping ([T]) -> Void
    ) -> ListenerRegistration {
        database.collection(collection).addSnapshotListener { snapshot, _ in
            guard let docs = snapshot?.documents else { return }
            let items = docs.compactMap { try? $0.data(as: T.self) }
            onChange(items)
        }
    }

    func listenToDocument<T: Decodable>(
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

    func listenToSubcollection<T: Decodable>(
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
}

// MARK: - Querying

public extension FirestoreService {
    func query<T: Decodable>(
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

    func queryWhere<T: Decodable>(
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

    func queryOrdered<T: Decodable>(
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

// MARK: - Encrypted Fetching

public extension FirestoreService {
    /// Fetch and decrypt a Codable document saved with saveEncrypted.
    func fetchEncrypted<T: Decodable>(
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
    func fetchEncrypted<T: Decodable>(
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

    /// Fetch and decrypt all documents in a subcollection saved with saveEncryptedToSubcollection.
    func fetchEncryptedSubcollection<T: Decodable>(
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
    func fetchEncryptedSubcollection<T: Decodable>(
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

    /// Fetch and decrypt all Codable documents in a collection saved with saveEncrypted.
    func fetchAllEncrypted<T: Decodable>(
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

    /// Fetch and decrypt all Codable documents in a collection saved with saveEncrypted.
    func fetchAllEncrypted<T: Decodable>(
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

    func fetchAllEncrypted<T: Decodable>(
        collection: String,
        as type: T.Type,
        passphrase: String,
        userID: String? = nil
    ) async throws -> [T] {
        let key = try await FirebaseEncryptionService.shared.dataKey(
            passphrase: passphrase,
            userID: userID
        )

        return try await fetchAllEncrypted(
            collection: collection,
            as: type,
            using: key
        )
    }

    func fetchAllEncrypted<T: Decodable>(
        collection: String,
        limit: Int,
        as type: T.Type,
        passphrase: String,
        userID: String? = nil
    ) async throws -> [T] {
        let key = try await FirebaseEncryptionService.shared.dataKey(
            passphrase: passphrase,
            userID: userID
        )

        return try await fetchAllEncrypted(
            collection: collection,
            limit: limit,
            as: type,
            using: key
        )
    }

    func fetchEncryptedField<T: Decodable>(
        collection: String,
        documentID: String,
        field: String,
        as type: T.Type,
        using key: SymmetricKey
    ) async throws -> T? {
        guard let encryptedValue = try await fetchField(
            collection: collection,
            documentID: documentID,
            field: field,
            as: String.self
        ) else {
            return nil
        }

        return try encryptedValue.decrypted(as: type, using: key)
    }

    func fetchEncryptedField<T: Decodable>(
        collection: String,
        documentID: String,
        field: String,
        as type: T.Type,
        passphrase: String,
        userID: String? = nil
    ) async throws -> T? {
        let key = try await FirebaseEncryptionService.shared.dataKey(
            passphrase: passphrase,
            userID: userID
        )

        return try await fetchEncryptedField(
            collection: collection,
            documentID: documentID,
            field: field,
            as: type,
            using: key
        )
    }

    func fetchPaginatedEncrypted<T: Decodable>(
        collection: String,
        orderBy field: String,
        descending: Bool = false,
        limit: Int = 20,
        after lastDocument: DocumentSnapshot? = nil,
        as type: T.Type,
        using key: SymmetricKey
    ) async throws -> (items: [T], lastDocument: DocumentSnapshot?) {
        let page = try await fetchPaginated(
            collection: collection,
            orderBy: field,
            descending: descending,
            limit: limit,
            after: lastDocument,
            as: EncryptedFirestoreDocument.self
        )

        let items = try page.items.map {
            try $0.encryptedValue.decrypted(as: type, using: key)
        }

        return (items, page.lastDocument)
    }

    func fetchPaginatedEncrypted<T: Decodable>(
        collection: String,
        orderBy field: String,
        descending: Bool = false,
        limit: Int = 20,
        after lastDocument: DocumentSnapshot? = nil,
        as type: T.Type,
        passphrase: String,
        userID: String? = nil
    ) async throws -> (items: [T], lastDocument: DocumentSnapshot?) {
        let key = try await FirebaseEncryptionService.shared.dataKey(
            passphrase: passphrase,
            userID: userID
        )

        return try await fetchPaginatedEncrypted(
            collection: collection,
            orderBy: field,
            descending: descending,
            limit: limit,
            after: lastDocument,
            as: type,
            using: key
        )
    }
}

// MARK: - Encrypted Saving

public extension FirestoreService {
    /// Encrypt and save a Codable document to a subcollection.
    func saveEncryptedToSubcollection<T: Encodable & Identifiable>(
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
    func saveEncryptedToSubcollection<T: Encodable & Identifiable>(
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

    /// Encrypt and save a Codable document using its String id.
    func saveEncrypted<T: Encodable & Identifiable>(
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
    func saveEncrypted<T: Encodable & Identifiable>(
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
    func saveEncrypted<T: Encodable>(
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
    func saveEncrypted<T: Encodable>(
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
}

// MARK: - Encrypted Updating

public extension FirestoreService {
    func updateEncryptedField<T: Encodable>(
        collection: String,
        documentID: String,
        field: String,
        value: T,
        using key: SymmetricKey
    ) async throws {
        try await updateFields(
            collection: collection,
            documentID: documentID,
            fields: [field: try value.encrypted(using: key)]
        )
    }

    func updateEncryptedField<T: Encodable>(
        collection: String,
        documentID: String,
        field: String,
        value: T,
        passphrase: String,
        userID: String? = nil
    ) async throws {
        let key = try await FirebaseEncryptionService.shared.dataKey(
            passphrase: passphrase,
            userID: userID
        )

        try await updateEncryptedField(
            collection: collection,
            documentID: documentID,
            field: field,
            value: value,
            using: key
        )
    }

    func encryptedFieldValue<T: Encodable>(
        _ value: T,
        passphrase: String,
        userID: String? = nil
    ) async throws -> String {
        let key = try await FirebaseEncryptionService.shared.dataKey(
            passphrase: passphrase,
            userID: userID
        )

        return try value.encrypted(using: key)
    }
}

// MARK: - Encrypted Real-time Listening

public extension FirestoreService {
    /// Listen to a collection in real time, decrypting each document's field.
    func listenEncrypted<T: Decodable>(
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

    /// Listen to a subcollection in real time, decrypting each document's field.
    func listenToEncryptedSubcollection<T: Decodable>(
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

    func listenToEncryptedDocument<T: Decodable>(
        collection: String,
        documentID: String,
        as type: T.Type,
        using key: SymmetricKey,
        onChange: @escaping (T?) -> Void
    ) -> ListenerRegistration {
        listenToDocument(
            collection: collection,
            documentID: documentID,
            as: EncryptedFirestoreDocument.self
        ) { encryptedDocument in
            onChange(try? encryptedDocument?.encryptedValue.decrypted(as: type, using: key))
        }
    }

    func listenToEncryptedDocument<T: Decodable>(
        collection: String,
        documentID: String,
        as type: T.Type,
        passphrase: String,
        userID: String? = nil,
        onChange: @escaping (T?) -> Void
    ) async throws -> ListenerRegistration {
        let key = try await FirebaseEncryptionService.shared.dataKey(
            passphrase: passphrase,
            userID: userID
        )

        return listenToEncryptedDocument(
            collection: collection,
            documentID: documentID,
            as: type,
            using: key,
            onChange: onChange
        )
    }
}

// MARK: - Encrypted Querying

public extension FirestoreService {
    func queryEncrypted<T: Decodable>(
        collection: String,
        field: String,
        isEqualTo value: Any,
        as type: T.Type,
        using key: SymmetricKey
    ) async throws -> [T] {
        let encryptedDocuments: [EncryptedFirestoreDocument] = try await query(
            collection: collection,
            field: field,
            isEqualTo: value,
            as: EncryptedFirestoreDocument.self
        )

        return try encryptedDocuments.map {
            try $0.encryptedValue.decrypted(as: type, using: key)
        }
    }

    func queryEncrypted<T: Decodable>(
        collection: String,
        field: String,
        isEqualTo value: Any,
        as type: T.Type,
        passphrase: String,
        userID: String? = nil
    ) async throws -> [T] {
        let key = try await FirebaseEncryptionService.shared.dataKey(
            passphrase: passphrase,
            userID: userID
        )

        return try await queryEncrypted(
            collection: collection,
            field: field,
            isEqualTo: value,
            as: type,
            using: key
        )
    }

    func queryWhereEncrypted<T: Decodable>(
        collection: String,
        field: String,
        in values: [Any],
        as type: T.Type,
        using key: SymmetricKey
    ) async throws -> [T] {
        let encryptedDocuments: [EncryptedFirestoreDocument] = try await queryWhere(
            collection: collection,
            field: field,
            in: values,
            as: EncryptedFirestoreDocument.self
        )

        return try encryptedDocuments.map {
            try $0.encryptedValue.decrypted(as: type, using: key)
        }
    }

    func queryWhereEncrypted<T: Decodable>(
        collection: String,
        field: String,
        in values: [Any],
        as type: T.Type,
        passphrase: String,
        userID: String? = nil
    ) async throws -> [T] {
        let key = try await FirebaseEncryptionService.shared.dataKey(
            passphrase: passphrase,
            userID: userID
        )

        return try await queryWhereEncrypted(
            collection: collection,
            field: field,
            in: values,
            as: type,
            using: key
        )
    }

    func queryOrderedEncrypted<T: Decodable>(
        collection: String,
        orderBy field: String,
        descending: Bool = false,
        limit: Int? = nil,
        as type: T.Type,
        using key: SymmetricKey
    ) async throws -> [T] {
        let encryptedDocuments: [EncryptedFirestoreDocument] = try await queryOrdered(
            collection: collection,
            orderBy: field,
            descending: descending,
            limit: limit,
            as: EncryptedFirestoreDocument.self
        )

        return try encryptedDocuments.map {
            try $0.encryptedValue.decrypted(as: type, using: key)
        }
    }

    func queryOrderedEncrypted<T: Decodable>(
        collection: String,
        orderBy field: String,
        descending: Bool = false,
        limit: Int? = nil,
        as type: T.Type,
        passphrase: String,
        userID: String? = nil
    ) async throws -> [T] {
        let key = try await FirebaseEncryptionService.shared.dataKey(
            passphrase: passphrase,
            userID: userID
        )

        return try await queryOrderedEncrypted(
            collection: collection,
            orderBy: field,
            descending: descending,
            limit: limit,
            as: type,
            using: key
        )
    }
}

public extension FirestoreService {
    /// Save a new document where every top-level stored property is encrypted separately.
    func saveEncryptedFields<T: Encodable>(
        _ object: T,
        collection: String,
        documentID: String,
        using key: SymmetricKey,
        merge: Bool = false
    ) async throws {
        let fields = try encryptedFieldDictionary(from: object, using: key)

        try await Firestore.firestore()
            .collection(collection)
            .document(documentID)
            .setData(fields, merge: merge)
    }

    /// Save a new document where every top-level stored property is encrypted separately.
    func saveEncryptedFields<T: Encodable>(
        _ object: T,
        collection: String,
        documentID: String,
        passphrase: String,
        userID: String? = nil,
        merge: Bool = false
    ) async throws {
        let key = try await FirebaseEncryptionService.shared.dataKey(
            passphrase: passphrase,
            userID: userID
        )

        try await saveEncryptedFields(
            object,
            collection: collection,
            documentID: documentID,
            using: key,
            merge: merge
        )
    }

    /// Save an Identifiable document where every top-level stored property is encrypted separately.
    func saveEncryptedFields<T: Encodable & Identifiable>(
        _ object: T,
        collection: String,
        using key: SymmetricKey,
        merge: Bool = false
    ) async throws where T.ID == String {
        try await saveEncryptedFields(
            object,
            collection: collection,
            documentID: object.id,
            using: key,
            merge: merge
        )
    }

    /// Save an Identifiable document where every top-level stored property is encrypted separately.
    func saveEncryptedFields<T: Encodable & Identifiable>(
        _ object: T,
        collection: String,
        passphrase: String,
        userID: String? = nil,
        merge: Bool = false
    ) async throws where T.ID == String {
        let key = try await FirebaseEncryptionService.shared.dataKey(
            passphrase: passphrase,
            userID: userID
        )

        try await saveEncryptedFields(
            object,
            collection: collection,
            documentID: object.id,
            using: key,
            merge: merge
        )
    }

    private func encryptedFieldDictionary<T: Encodable>(
        from object: T,
        using key: SymmetricKey
    ) throws -> [String: Any] {
        var fields: [String: Any] = [:]

        for child in Mirror(reflecting: object).allStoredChildren {
            guard let fieldName = child.label?.cleanPropertyName else {
                continue
            }

            guard let encodableValue = child.value as? Encodable else {
                throw EncryptedFieldsError.unsupportedField(fieldName)
            }

            fields[fieldName] = try SecureCodable.shared.encrypt(
                AnyEncodable(encodableValue),
                using: key
            )
        }

        return fields
    }
}

public enum EncryptedFieldsError: LocalizedError {
    case unsupportedField(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedField(let field):
            return "The field '\(field)' could not be encrypted because it does not conform to Encodable."
        }
    }
}

private struct AnyEncodable: Encodable {
    private let value: Encodable

    init(_ value: Encodable) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

private extension Mirror {
    var allStoredChildren: [Mirror.Child] {
        var children = Array(self.children)
        var mirror = self

        while let superclassMirror = mirror.superclassMirror {
            children.append(contentsOf: superclassMirror.children)
            mirror = superclassMirror
        }

        return children
    }
}

private extension String {
    var cleanPropertyName: String {
        hasPrefix("_") ? String(dropFirst()) : self
    }
}
