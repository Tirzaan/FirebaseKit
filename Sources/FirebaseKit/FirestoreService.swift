//
//  FirestoreService.swift
//  FirebaseKit
//
//  Created by Tirzaan on 4/5/26.
//

// Sources/FirebaseKit/FirestoreService.swift
import FirebaseFirestore

public final class FirestoreService {
    
    private let db = Firestore.firestore()
    
    public init() {}
    
    /// Fetch a Codable document
    public func fetch<T: Decodable>(
        collection: String,
        documentID: String
    ) async throws -> T {
        let snapshot = try await db.collection(collection).document(documentID).getDocument()
        return try snapshot.data(as: T.self)
    }
    
    /// Save a Codable document
    public func save<T: Encodable & Identifiable>(
        _ object: T,
        collection: String
    ) async throws where T.ID == String {
        try db.collection(collection).document(object.id).setData(from: object)
    }
    
    /// Listen to a collection in real time
    public func listen<T: Decodable>(
        collection: String,
        onChange: @escaping ([T]) -> Void
    ) -> ListenerRegistration {
        db.collection(collection).addSnapshotListener { snapshot, _ in
            guard let docs = snapshot?.documents else { return }
            let items = docs.compactMap { try? $0.data(as: T.self) }
            onChange(items)
        }
    }
}
