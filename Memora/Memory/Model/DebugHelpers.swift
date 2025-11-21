//
//  DebugHelpers.swift
//  Home
//
//  Created by user@3 on 17/11/25.
//

import Foundation
import UIKit

// Add this near MemoryStore (same file or any file in project)
extension MemoryStore {
    /// Prints all memories to console as pretty JSON and also logs a compact per-memory summary.
    /// Useful for debugging visibility/attachments/owner issues.
    public func debugDumpAll(printPrettyJSON: Bool = true) {
        let all = self.allMemories()
        if printPrettyJSON {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            do {
                let data = try encoder.encode(all)
                if let json = String(data: data, encoding: .utf8) {
                    print("=== MemoryStore: All memories (JSON) ===")
                    print(json)
                    print("=== End JSON ===")
                } else {
                    print("MemoryStore: unable to convert JSON data to string")
                }
            } catch {
                print("MemoryStore: failed to encode memories to JSON:", error)
            }
        }

        print("=== MemoryStore: Per-memory summary ===")
        for m in all {
            print("----- Memory id:", m.id, "title:", m.title)
            print(" ownerId:", m.ownerId)
            print(" visibility (raw):", m.visibility) // shows enum representation
            // If MemoryVisibility is Codable/RawRepresentable, show rawValue:
            if let raw = (m.visibility as? RawRepresentable)?.rawValue {
                print(" visibility.rawValue:", raw)
            }
            print(" createdAt:", m.createdAt)
            if let body = m.body { print(" body:", body) } else { print(" body: <nil>") }
            if let cat = m.category { print(" category:", cat) } else { print(" category: <nil>") }
            print(" attachments count:", m.attachments.count)
            for att in m.attachments {
                print("   - attachment id:", att.id)
                print("     kind:", att.kind)
                print("     filename:", att.filename)
                print("     createdAt:", att.createdAt)
            }
            print("----------------------------------------")
        }
        print("=== End per-memory summary ===")
    }
}
