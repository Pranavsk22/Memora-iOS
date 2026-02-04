//
//  Memory.swift
//  Home
//
//  Model for locally saved "memories"
//  Uses the app-wide MemoryVisibility enum (do NOT redeclare it here).
//

import Foundation
import UIKit

// Represents an attachment stored for a Memory. Filename is relative to app documents folder.
public struct MemoryAttachment: Codable, Equatable {
    public enum Kind: String, Codable {
        case image
        case audio
        case unknown
    }

    public let id: String
    public let kind: Kind
    public let filename: String     // stored filename relative to documents directory
    public let createdAt: Date

    public init(id: String = UUID().uuidString,
                kind: Kind,
                filename: String,
                createdAt: Date = Date()) {
        self.id = id
        self.kind = kind
        self.filename = filename
        self.createdAt = createdAt
    }
}

// Main memory model saved to disk
public struct Memory: Codable, Equatable {
    public var id: String
    public let ownerId: String
    public var title: String
    public var body: String?
    public let category: String?                     //  NEW: category of the prompt
    public var attachments: [MemoryAttachment]
    public var visibility: MemoryVisibility          // uses your existing enum
    public let scheduledFor: Date?
    public let createdAt: Date

    public init(id: String = UUID().uuidString,
                ownerId: String,
                title: String,
                body: String? = nil,
                category: String? = nil,             //  default nil for safety
                attachments: [MemoryAttachment] = [],
                visibility: MemoryVisibility = .everyone,
                scheduledFor: Date? = nil,
                createdAt: Date = Date()) {

        self.id = id
        self.ownerId = ownerId
        self.title = title
        self.body = body
        self.category = category                     //  assigned
        self.attachments = attachments
        self.visibility = visibility
        self.scheduledFor = scheduledFor
        self.createdAt = createdAt
    }
}


// In your existing Memory.swift file, add these extensions:
extension Memory {
    var isScheduled: Bool {
        return visibility == .scheduled && scheduledFor != nil
    }
    
    var isReadyToOpen: Bool {
        guard let releaseDate = scheduledFor else { return false }
        return releaseDate <= Date()
    }
    
    var timeUntilRelease: TimeInterval {
        guard let releaseDate = scheduledFor else { return 0 }
        return max(0, releaseDate.timeIntervalSince(Date()))
    }
    
    var formattedTimeRemaining: String {
        let interval = timeUntilRelease
        
        if interval <= 0 {
            return "Ready to open!"
        }
        
        let days = Int(interval / 86400)
        let hours = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var progressPercentage: Double {
        guard let releaseDate = scheduledFor else { return 0 }
        let totalDuration = releaseDate.timeIntervalSince(createdAt)
        guard totalDuration > 0 else { return 0 }
        
        let elapsed = Date().timeIntervalSince(createdAt)
        let percentage = min(1.0, max(0, elapsed / totalDuration))
        return percentage
    }
    
    var scheduledCapsuleStyle: CapsuleStyle {
        guard let releaseDate = scheduledFor else { return .bronze }
        let duration = releaseDate.timeIntervalSince(createdAt)
        return CapsuleStyle.styleForDuration(duration)
    }
}
