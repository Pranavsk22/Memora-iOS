//
//  ScheduledMemory.swift
//  Memora
//
//  Created by user@3 on 03/02/26.
//


// MemoryCapsuleModel.swift
import Foundation
import SwiftUI

struct ScheduledMemory: Codable, Identifiable {
    let id: UUID
    let title: String
    let year: Int?
    let category: String?
    let releaseAt: Date
    let createdAt: Date
    let userId: UUID
    let previewImageUrl: String?
    let isReadyToOpen: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case year
        case category
        case releaseAt = "release_at"
        case createdAt = "created_at"
        case userId = "user_id"
        case previewImageUrl = "preview_image_url"
        case isReadyToOpen = "is_ready"
    }
    
    var timeUntilRelease: TimeInterval {
        return max(0, releaseAt.timeIntervalSince(Date()))
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
        let totalDuration = releaseAt.timeIntervalSince(createdAt)
        guard totalDuration > 0 else { return 0 }
        
        let elapsed = Date().timeIntervalSince(createdAt)
        let percentage = min(1.0, max(0, elapsed / totalDuration))
        return percentage
    }
}

// MARK: - Capsule UI Models
struct CapsuleStyle {
    let backgroundColor: Color
    let accentColor: Color
    let glowColor: Color
    
    static let gold = CapsuleStyle(
        backgroundColor: Color(hex: "#FFF8E1"),
        accentColor: Color(hex: "#FFD700"),
        glowColor: Color(hex: "#FFF59D").opacity(0.8)
    )
    
    static let silver = CapsuleStyle(
        backgroundColor: Color(hex: "#F5F5F5"),
        accentColor: Color(hex: "#C0C0C0"),
        glowColor: Color(hex: "#E0E0E0").opacity(0.8)
    )
    
    static let bronze = CapsuleStyle(
        backgroundColor: Color(hex: "#F3E5D8"),
        accentColor: Color(hex: "#CD7F32"),
        glowColor: Color(hex: "#E6CCB2").opacity(0.8)
    )
    
    static func styleForDuration(_ duration: TimeInterval) -> CapsuleStyle {
        let days = duration / 86400
        if days >= 365 { return .gold }
        if days >= 30 { return .silver }
        return .bronze
    }
}

// MARK: - Extension for Color
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
