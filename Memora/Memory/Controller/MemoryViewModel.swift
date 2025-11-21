//
//  MemoryViewModel.swift
//  Home
//
//  Created by user@3 on 17/11/25.
//

import Foundation

final class MemoryViewModel {

    // number of recents to show
    let recentsLimit: Int

    init(recentsLimit: Int = 6) {
        self.recentsLimit = recentsLimit
    }

    /// Latest memories (newest first)
    var recents: [Memory] {
        return MemoryStore.shared.allMemories()
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(recentsLimit)
            .map { $0 }
    }

    /// Returns:
    ///   • remote URL string (if attachment.filename is a full URL)
    ///   • nil if no remote → UI should fall back to MemoryStore local file
    func firstRemoteImageURLString(for memory: Memory) -> String? {
        guard let att = memory.attachments.first(where: { $0.kind == .image }) else {
            return nil
        }

        let s = att.filename.trimmingCharacters(in: .whitespacesAndNewlines)

        // If filename is remote → return it
        if s.lowercased().hasPrefix("http://") || s.lowercased().hasPrefix("https://") {
            return s
        }

        // If it's local → return nil so cell loads local file
        return nil
    }
}
