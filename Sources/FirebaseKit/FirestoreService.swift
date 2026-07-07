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
import Security

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
    
    func savePartiallyEncryptedToSubcollection<T: Encodable>(
        _ object: T,
        collection: String,
        documentID: String,
        subcollection: String,
        subdocumentID: String,
        encryptedFields: Set<String>,
        using key: SymmetricKey,
        merge: Bool = false
    ) async throws {

        var data = try Firestore.Encoder().encode(object)

        for field in encryptedFields {
            guard let value = data[field] else { continue }

            let encryptableValue = try FirestoreEncryptedJSONValue(firestoreValue: value)
            data[field] = try encryptableValue.encrypted(using: key)
        }

        try await Firestore.firestore()
            .collection(collection)
            .document(documentID)
            .collection(subcollection)
            .document(subdocumentID)
            .setData(data, merge: merge)
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
        using key: SymmetricKey
    ) throws -> String {
        try value.encrypted(using: key)
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

// MARK: - Partial Field Encryption

public extension FirestoreService {
    /// Save a document with public fields and selected encrypted fields.
    ///
    /// Example:
    /// try await FirestoreService.shared.savePartiallyEncrypted(
    ///     chat,
    ///     collection: "chats",
    ///     documentID: chatID,
    ///     encryptedFields: ["title", "lastMessage"],
    ///     passphrase: userEncryptionPassphrase
    /// )
    func savePartiallyEncrypted<T: Encodable>(
        _ object: T,
        collection: String,
        documentID: String,
        encryptedFields: Set<String>,
        using key: SymmetricKey,
        merge: Bool = false
    ) async throws {
        var data = try Firestore.Encoder().encode(object)

        for field in encryptedFields {
            guard let value = data[field] else {
                continue
            }

            let encryptableValue = try FirestoreEncryptedJSONValue(firestoreValue: value)
            data[field] = try encryptableValue.encrypted(using: key)
        }

        try await Firestore.firestore()
            .collection(collection)
            .document(documentID)
            .setData(data, merge: merge)
    }

    /// Save a document with public fields and selected encrypted fields using FirebaseKit's managed data key.
    func savePartiallyEncrypted<T: Encodable>(
        _ object: T,
        collection: String,
        documentID: String,
        encryptedFields: Set<String>,
        passphrase: String,
        userID: String? = nil,
        merge: Bool = false
    ) async throws {
        let key = try await FirebaseEncryptionService.shared.dataKey(
            passphrase: passphrase,
            userID: userID
        )

        try await savePartiallyEncrypted(
            object,
            collection: collection,
            documentID: documentID,
            encryptedFields: encryptedFields,
            using: key,
            merge: merge
        )
    }

    /// Save an Identifiable document with public fields and selected encrypted fields.
    func savePartiallyEncrypted<T: Encodable & Identifiable>(
        _ object: T,
        collection: String,
        encryptedFields: Set<String>,
        using key: SymmetricKey,
        merge: Bool = false
    ) async throws where T.ID == String {
        try await savePartiallyEncrypted(
            object,
            collection: collection,
            documentID: object.id,
            encryptedFields: encryptedFields,
            using: key,
            merge: merge
        )
    }

    /// Save an Identifiable document with public fields and selected encrypted fields using FirebaseKit's managed data key.
    func savePartiallyEncrypted<T: Encodable & Identifiable>(
        _ object: T,
        collection: String,
        encryptedFields: Set<String>,
        passphrase: String,
        userID: String? = nil,
        merge: Bool = false
    ) async throws where T.ID == String {
        let key = try await FirebaseEncryptionService.shared.dataKey(
            passphrase: passphrase,
            userID: userID
        )

        try await savePartiallyEncrypted(
            object,
            collection: collection,
            documentID: object.id,
            encryptedFields: encryptedFields,
            using: key,
            merge: merge
        )
    }

    /// Fetch a document with public fields and selected encrypted fields.
    ///
    /// Example:
    /// let chat = try await FirestoreService.shared.fetchPartiallyEncrypted(
    ///     collection: "chats",
    ///     documentID: chatID,
    ///     as: ChatModel.self,
    ///     encryptedFields: ["title", "lastMessage"],
    ///     passphrase: userEncryptionPassphrase
    /// )
    func fetchPartiallyEncrypted<T: Decodable>(
        collection: String,
        documentID: String,
        as type: T.Type,
        encryptedFields: Set<String>,
        using key: SymmetricKey
    ) async throws -> T {
        var data = try await fetchRaw(
            collection: collection,
            documentID: documentID
        )

        for field in encryptedFields {
            guard let encryptedValue = data[field] as? String else {
                continue
            }

            let decryptedValue = try encryptedValue.decrypted(
                as: FirestoreEncryptedJSONValue.self,
                using: key
            )

            data[field] = decryptedValue.firestoreValue
        }

        return try Firestore.Decoder().decode(type, from: data)
    }

    /// Fetch a document with public fields and selected encrypted fields using FirebaseKit's managed data key.
    func fetchPartiallyEncrypted<T: Decodable>(
        collection: String,
        documentID: String,
        as type: T.Type,
        encryptedFields: Set<String>,
        passphrase: String,
        userID: String? = nil
    ) async throws -> T {
        let key = try await FirebaseEncryptionService.shared.dataKey(
            passphrase: passphrase,
            userID: userID
        )

        return try await fetchPartiallyEncrypted(
            collection: collection,
            documentID: documentID,
            as: type,
            encryptedFields: encryptedFields,
            using: key
        )
    }
}

// MARK: - Per-Field Encryption

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

// MARK: - Supporting Types (Public)

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

// MARK: - Supporting Types (Private)

private enum FirestoreEncryptedJSONValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case date(TimeInterval)
    case array([FirestoreEncryptedJSONValue])
    case object([String: FirestoreEncryptedJSONValue])
    case null

    init(firestoreValue: Any) throws {
        switch firestoreValue {
        case let value as String:
            self = .string(value)
        case let value as Int:
            self = .int(value)
        case let value as Double:
            self = .double(value)
        case let value as Float:
            self = .double(Double(value))
        case let value as Bool:
            self = .bool(value)
        case let value as Date:
            self = .date(value.timeIntervalSince1970)
        case let value as Timestamp:
            self = .date(value.dateValue().timeIntervalSince1970)
        case let value as [Any]:
            self = .array(try value.map { try FirestoreEncryptedJSONValue(firestoreValue: $0) })
        case let value as [String: Any]:
            self = .object(try value.mapValues { try FirestoreEncryptedJSONValue(firestoreValue: $0) })
        case _ as NSNull:
            self = .null
        default:
            let data = try JSONSerialization.data(withJSONObject: firestoreValue, options: [])
            self = try JSONDecoder().decode(FirestoreEncryptedJSONValue.self, from: data)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(DateValue.self) {
            self = .date(value.timeIntervalSince1970)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([FirestoreEncryptedJSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: FirestoreEncryptedJSONValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .date(let value):
            try container.encode(DateValue(timeIntervalSince1970: value))
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var firestoreValue: Any {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return value
        case .double(let value):
            return value
        case .bool(let value):
            return value
        case .date(let value):
            return Date(timeIntervalSince1970: value)
        case .array(let values):
            return values.map(\.firestoreValue)
        case .object(let values):
            return values.mapValues(\.firestoreValue)
        case .null:
            return NSNull()
        }
    }
}

private struct DateValue: Codable {
    let timeIntervalSince1970: TimeInterval
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


public final class SharedKeyService {
    
    public static let shared = SharedKeyService()
    
    private let firestore: Firestore
    private let keychain: KeychainStore
    
    public init(
        firestore: Firestore = Firestore.firestore(),
        keychain: KeychainStore = .shared
    ) {
        self.firestore = firestore
        self.keychain = keychain
    }
    
    // MARK: - Identity Keys
    
    @discardableResult
    public func ensureIdentityKey(userID: String) throws -> Curve25519.KeyAgreement.PrivateKey {
        if let existing = try keychain.loadPrivateKey(userID: userID) {
            return existing
        }
        
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        try keychain.savePrivateKey(privateKey, userID: userID)
        try publishPublicKey(privateKey.publicKey, userID: userID)
        
        return privateKey
    }
    
    private func publishPublicKey(
        _ publicKey: Curve25519.KeyAgreement.PublicKey,
        userID: String
    ) throws {
        firestore.collection("users").document(userID).setData([
            "publicKey": publicKey.rawRepresentation.base64EncodedString(),
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }
    
    public func fetchPublicKey(userID: String) async throws -> Curve25519.KeyAgreement.PublicKey {
        let snapshot = try await firestore.collection("users").document(userID).getDocument()
        
        guard
            let base64 = snapshot.data()?["publicKey"] as? String,
            let data = Data(base64Encoded: base64)
        else {
            throw SharedKeyError.missingPublicKey(userID)
        }
        
        return try Curve25519.KeyAgreement.PublicKey(rawRepresentation: data)
    }
    
    // MARK: - Resource Key Creation
    
    @discardableResult
    public func createAndShareKey(
        resourceID: String,
        userIDs: [String],
        senderUserID: String
    ) async throws -> SymmetricKey {
        let key = SymmetricKey(size: .bits256)
        
        try await shareKey(
            key,
            resourceID: resourceID,
            userIDs: userIDs,
            senderUserID: senderUserID
        )
        
        return key
    }
    
    public func shareKey(
        _ key: SymmetricKey,
        resourceID: String,
        userIDs: [String],
        senderUserID: String
    ) async throws {
        
        let senderPrivateKey = try ensureIdentityKey(userID: senderUserID)
        let senderPublicKeyBase64 = senderPrivateKey.publicKey.rawRepresentation.base64EncodedString()
        
        for userID in userIDs {
            let recipientPublicKey = try await fetchPublicKey(userID: userID)
            
            let wrapped = try wrap(
                key: key,
                recipientPublicKey: recipientPublicKey,
                senderPrivateKey: senderPrivateKey
            )
            
            try await firestore
                .collection("resources").document(resourceID)
                .collection("accessKeys").document(userID)
                .setData([
                    "wrappedKey": wrapped.ciphertext,
                    "salt": wrapped.salt,
                    "senderPublicKey": senderPublicKeyBase64,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
        }
    }
    
    public func fetchKey(
        resourceID: String,
        userID: String
    ) async throws -> SymmetricKey {
        
        let doc = try await firestore
            .collection("resources").document(resourceID)
            .collection("accessKeys").document(userID)
            .getDocument()
        
        guard
            let data = doc.data(),
            let wrapped = data["wrappedKey"] as? String,
            let salt = data["salt"] as? String,
            let senderPublicKeyBase64 = data["senderPublicKey"] as? String,
            let senderPublicKeyData = Data(base64Encoded: senderPublicKeyBase64)
        else {
            throw SharedKeyError.missingWrappedKey(resourceID: resourceID, userID: userID)
        }
        
        let privateKey = try ensureIdentityKey(userID: userID)
        let senderPublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: senderPublicKeyData)
        
        return try unwrap(
            ciphertext: wrapped,
            salt: salt,
            senderPublicKey: senderPublicKey,
            recipientPrivateKey: privateKey
        )
    }
    
    @discardableResult
    public func rotateKey(
        resourceID: String,
        remainingUserIDs: [String],
        senderUserID: String
    ) async throws -> SymmetricKey {
        
        try await createAndShareKey(
            resourceID: resourceID,
            userIDs: remainingUserIDs,
            senderUserID: senderUserID
        )
    }
    
    // MARK: - Crypto (unchanged)
    
    private struct WrappedKey {
        let ciphertext: String
        let salt: String
    }
    
    private func wrap(
        key: SymmetricKey,
        recipientPublicKey: Curve25519.KeyAgreement.PublicKey,
        senderPrivateKey: Curve25519.KeyAgreement.PrivateKey
    ) throws -> WrappedKey {
        
        let sharedSecret = try senderPrivateKey.sharedSecretFromKeyAgreement(with: recipientPublicKey)
        let salt = try SecureCodable.randomData(byteCount: 32)
        
        let wrappingKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: salt,
            sharedInfo: Data("shared-key-wrap-v1".utf8),
            outputByteCount: 32
        )
        
        let keyData = key.withUnsafeBytes { Data($0) }
        let sealedBox = try AES.GCM.seal(keyData, using: wrappingKey)
        
        return WrappedKey(
            ciphertext: sealedBox.combined!.base64EncodedString(),
            salt: salt.base64EncodedString()
        )
    }
    
    private func unwrap(
        ciphertext: String,
        salt: String,
        senderPublicKey: Curve25519.KeyAgreement.PublicKey,
        recipientPrivateKey: Curve25519.KeyAgreement.PrivateKey
    ) throws -> SymmetricKey {
        
        let ciphertextData = Data(base64Encoded: ciphertext)!
        let saltData = Data(base64Encoded: salt)!
        
        let sharedSecret = try recipientPrivateKey.sharedSecretFromKeyAgreement(with: senderPublicKey)
        
        let wrappingKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: saltData,
            sharedInfo: Data("shared-key-wrap-v1".utf8),
            outputByteCount: 32
        )
        
        let sealedBox = try AES.GCM.SealedBox(combined: ciphertextData)
        let keyData = try AES.GCM.open(sealedBox, using: wrappingKey)
        
        return SymmetricKey(data: keyData)
    }
    
}

public final class KeychainStore {
    public static let shared = KeychainStore()
    
    private let service = "com.yourapp.sharedkeys"
    
    public init() {}
    
    public func savePrivateKey(_ key: Curve25519.KeyAgreement.PrivateKey, userID: String) throws {
        let data = key.rawRepresentation
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: userID
        ]
        
        // Remove existing entry first
        SecItemDelete(query as CFDictionary)
        
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        
        let status = SecItemAdd(attributes as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainStoreError.saveFailed(status: status)
        }
    }
    
    public func loadPrivateKey(userID: String) throws -> Curve25519.KeyAgreement.PrivateKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: userID,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            return nil
        }
        
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainStoreError.loadFailed(status: status)
        }
        
        return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
    }
    
}

public enum KeychainStoreError: LocalizedError {
    case saveFailed(status: OSStatus)
    case loadFailed(status: OSStatus)
    
    public var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save key (OSStatus: \(status))"
        case .loadFailed(let status):
            return "Failed to load key (OSStatus: \(status))"
        }
    }
}

public enum SharedKeyError: LocalizedError {
    case missingPublicKey(String)
    case missingWrappedKey(resourceID: String, userID: String)
    case invalidWrappedKeyData
    case sealFailed
    
    public var errorDescription: String? {
        switch self {
        case .missingPublicKey(let userID):
            return "No public key found for user \(userID). Call ensureIdentityKey first."
        case .missingWrappedKey(let resourceID, let userID):
            return "No wrapped key found for user \(userID) in resource \(resourceID)."
        case .invalidWrappedKeyData:
            return "Wrapped key data is invalid or corrupted."
        case .sealFailed:
            return "Failed to encrypt (seal) the key."
        }
    }
}

