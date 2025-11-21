// MemorySeedLoader.swift
// Debug helper to seed MemoryStore from a bundle JSON file (supports optional remote image download).
// Usage:
//   MemorySeedLoader.seedFromBundleJSON(named: "memories_seed", downloadRemoteImages: true) { result in
//       switch result {
//       case .success(let importedCount): print("Imported \(importedCount) memories")
//       case .failure(let err): print("Seed failed:", err)
//       }
//   }

import Foundation
import UIKit

/// Small structs matching the seeded JSON (includes optional remoteURL for attachments).
private struct SeedAttachment: Codable {
    let id: String
    let kind: String
    var filename: String
    var createdAt: Double
    var remoteURL: String? // optional: our seed contains this for preview; we will download if requested
}

private struct SeedMemory: Codable {
    let id: String
    let ownerId: String
    let title: String
    let body: String?
    let category: String?
    var attachments: [SeedAttachment]
    let visibility: Int // 0 = everyone, 1 = private, 2 = scheduled
    let scheduledFor: Double?
    let createdAt: Double
}

/// Simple error enum for the loader
public enum MemorySeedLoaderError: Error {
    case fileNotFound(String)
    case invalidJSON(Error)
    case downloadFailed(URL)
    case saveImageFailed(Error)
}

/// Loader
public final class MemorySeedLoader {

    /// Public entry point.
    /// - Parameters:
    ///   - name: filename in bundle without .json (e.g. "memories_seed")
    ///   - downloadRemoteImages: if true, will try to download `remoteURL` for attachments and save them into MemoryStore attachments folder (replacing filenames in the Memory)
    ///   - completion: returns number of memories imported or an error
    public static func seedFromBundleJSON(named name: String,
                                          downloadRemoteImages: Bool = true,
                                          completion: @escaping (Result<Int, Error>) -> Void) {
        // Load the JSON file from the bundle
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            completion(.failure(MemorySeedLoaderError.fileNotFound(name + ".json")))
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let seed = try decoder.decode([SeedMemory].self, from: data)
            // Process asynchronously so we don't block main thread
            DispatchQueue.global(qos: .userInitiated).async {
                process(seed: seed, downloadRemoteImages: downloadRemoteImages) { result in
                    DispatchQueue.main.async {
                        completion(result)
                    }
                }
            }
        } catch {
            completion(.failure(MemorySeedLoaderError.invalidJSON(error)))
        }
    }

    // MARK: - Internal processing

    private static func process(seed: [SeedMemory],
                                downloadRemoteImages: Bool,
                                completion: @escaping (Result<Int, Error>) -> Void) {

        let group = DispatchGroup()
        var importedCount = 0
        var firstError: Error?

        for var s in seed {
            // For each seed memory, we may need to download remote images and save them to attachments folder.
            var finalAttachments: [MemoryAttachment] = []

            for var sa in s.attachments {
                // If remoteURL exists and user wants downloading, attempt it. Otherwise trust filename as-is.
                if downloadRemoteImages, let remote = sa.remoteURL, let rurl = URL(string: remote) {
                    group.enter()
                    downloadImage(from: rurl) { result in
                        switch result {
                        case .success(let image):
                            do {
                                // Save using MemoryStore (throws)
                                let savedFilename = try MemoryStore.shared.saveImageAttachment(image)
                                let ma = MemoryAttachment(id: sa.id,
                                                          kind: .image,
                                                          filename: savedFilename,
                                                          createdAt: Date(timeIntervalSince1970: sa.createdAt))
                                finalAttachments.append(ma)
                            } catch {
                                // fallback: keep original filename but log error
                                print("MemorySeedLoader: failed saving downloaded image to attachments:", error)
                                let ma = MemoryAttachment(id: sa.id,
                                                          kind: MemoryAttachment.Kind(rawValue: sa.kind) ?? .unknown,
                                                          filename: sa.filename,
                                                          createdAt: Date(timeIntervalSince1970: sa.createdAt))
                                finalAttachments.append(ma)
                                if firstError == nil { firstError = error }
                            }
                        case .failure(let err):
                            // download failed — keep original filename (seed may refer to bundled assets)
                            print("MemorySeedLoader: failed downloading \(rurl): \(err)")
                            let ma = MemoryAttachment(id: sa.id,
                                                      kind: MemoryAttachment.Kind(rawValue: sa.kind) ?? .unknown,
                                                      filename: sa.filename,
                                                      createdAt: Date(timeIntervalSince1970: sa.createdAt))
                            finalAttachments.append(ma)
                            if firstError == nil { firstError = err }
                        }
                        group.leave()
                    }
                } else {
                    // No download: use seed filename as-is (it might refer to a file you create later)
                    let ma = MemoryAttachment(id: sa.id,
                                              kind: MemoryAttachment.Kind(rawValue: sa.kind) ?? .unknown,
                                              filename: sa.filename,
                                              createdAt: Date(timeIntervalSince1970: sa.createdAt))
                    finalAttachments.append(ma)
                }
            }

            // Wait for any downloads for this memory to finish (we could also wait for all at the end; group ensures downloads complete)
            group.wait()

            // Map visibility int -> MemoryVisibility
            let memVisibility = mapVisibilityInt(s.visibility)

            // scheduledFor/date conversion
            let scheduledDate: Date? = {
                guard let sf = s.scheduledFor else { return nil }
                return Date(timeIntervalSince1970: sf)
            }()

            // Build Memory model and persist
            let memoryToCreate = Memory(id: s.id,
                                        ownerId: s.ownerId,
                                        title: s.title,
                                        body: s.body,
                                        category: s.category,
                                        attachments: finalAttachments,
                                        visibility: memVisibility,
                                        scheduledFor: scheduledDate,
                                        createdAt: Date(timeIntervalSince1970: s.createdAt))

            // Use MemoryStore.add to persist (it will save to disk on its own queue).
            let semaphore = DispatchSemaphore(value: 0)
            MemoryStore.shared.add(memoryToCreate) { res in
                switch res {
                case .success:
                    importedCount += 1
                case .failure(let e):
                    print("MemorySeedLoader: failed to add memory \(s.id):", e)
                    if firstError == nil { firstError = e }
                }
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + 10) // wait briefly for add completion; should be fast
        }

        if let err = firstError {
            completion(.failure(err))
        } else {
            completion(.success(importedCount))
        }
    }

    // MARK: - Image download helper
    private static func downloadImage(from url: URL, timeout: TimeInterval = 15.0, completion: @escaping (Result<UIImage, Error>) -> Void) {
        var req = URLRequest(url: url)
        req.timeoutInterval = timeout
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = timeout
        cfg.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: cfg)
        let task = session.dataTask(with: req) { data, response, error in
            if let err = error {
                completion(.failure(err))
                return
            }
            guard let d = data, let img = UIImage(data: d) else {
                let err = NSError(domain: "MemorySeedLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data from \(url)"])
                completion(.failure(err))
                return
            }
            completion(.success(img))
        }
        task.resume()
    }

    private static func mapVisibilityInt(_ v: Int) -> MemoryVisibility {
        // Try map 0->everyone, 1->private, 2->scheduled
        // If your MemoryVisibility type is different, adjust accordingly.
        switch v {
        case 1: return .private
        case 2: return .scheduled
        default: return .everyone
        }
    }
}
