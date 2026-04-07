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
    
    public func fetchField<T>(
        collection: String,
        documentID: String,
        field: String,
        as type: T.Type
    ) async throws -> T? {
        let data = try await fetchRaw(collection: collection, documentID: documentID)
        return data[field] as? T
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
}
