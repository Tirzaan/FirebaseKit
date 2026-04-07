//
//  StorageService.swift
//  FirebaseKit
//
//  Created by Tirzaan on 4/5/26.
//

// Sources/FirebaseKit/StorageService.swift
import FirebaseStorage
import Foundation

public final class StorageService {
    
    public static let shared = StorageService()  // singleton style
    
    private let storage: Storage
    
    // private init for singleton
    private init() {
        self.storage = Storage.storage()
    }
    
    // public init for custom instance style
    public init(storage: Storage = Storage.storage()) {
        self.storage = storage
    }
    
    // MARK: - Upload
    
    /// Upload raw Data (e.g. image bytes) and return the download URL
    public func upload(
        data: Data,
        path: String,
        mimeType: String = "image/jpeg"
    ) async throws -> URL {
        let ref = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = mimeType
        
        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        return url
    }
    
    /// Upload a local file by URL and return the download URL
    public func uploadFile(
        localURL: URL,
        path: String
    ) async throws -> URL {
        let ref = storage.reference().child(path)
        _ = try await ref.putFileAsync(from: localURL)
        let url = try await ref.downloadURL()
        return url
    }
    
    // MARK: - Download
    
    /// Download a file as Data (suitable for images etc.)
    public func download(path: String, maxSize: Int64 = 10 * 1024 * 1024) async throws -> Data {
        let ref = storage.reference().child(path)
        return try await ref.data(maxSize: maxSize)
    }
    
    /// Get a download URL for a given path
    public func downloadURL(path: String) async throws -> URL {
        let ref = storage.reference().child(path)
        return try await ref.downloadURL()
    }
    
    // MARK: - Delete
    
    /// Delete a file at the given path
    public func delete(path: String) async throws {
        let ref = storage.reference().child(path)
        try await ref.delete()
    }
}

// Usage Example
/*
 let storage = StorageService()

 // Upload a profile picture
 let imageData: Data = ... // e.g. from UIImage
 let url = try await storage.upload(
     data: imageData,
     path: "avatars/\(userID).jpg",
     mimeType: "image/jpeg"
 )

 // Download an image
 let data = try await storage.download(path: "avatars/\(userID).jpg")
 let image = UIImage(data: data)

 // Delete a file
 try await storage.delete(path: "avatars/\(userID).jpg")
 */
