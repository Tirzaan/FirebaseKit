//
//  FirestoreService.swift
//  FirebaseKit
//
//  Created by Tirzaan on 4/5/26.
//

// Sources/FirebaseKit/FirestoreService.swift
import FirebaseFirestore

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
    
    public func fetchAll<T: Decodable>(
        collection: String,
        limit: Int,
        as type: T.Type
    ) async throws -> [T] {
        let snapshot = try await database.collection(collection).limit(to: limit).getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: T.self) }
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
    
    /// Save a Codable document
    public func save<T: Encodable & Identifiable>(
        _ object: T,
        collection: String
    ) async throws where T.ID == String {
        try database.collection(collection).document(object.id).setData(from: object)
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
