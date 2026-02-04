// PostOptionsViewControllerDelegate.swift
import Foundation
import UIKit

public enum MemoryVisibility: Int, Codable, CaseIterable {
    case everyone = 0
    case `private` = 1
    case scheduled = 2
    case group = 3
    
    public var databaseString: String {
        switch self {
        case .everyone: return "shared"
        case .private: return "private"
        case .scheduled: return "scheduled"
        case .group: return "group"
        }
    }
    
    public var title: String {
        switch self {
        case .everyone: return "Everyone"
        case .private: return "Private"
        case .scheduled: return "Scheduled"
        case .group: return "Group"
        }
    }
    
    public static func fromDatabaseString(_ string: String) -> MemoryVisibility {
        switch string.lowercased() {
        case "shared", "everyone": return .everyone
        case "private": return .private
        case "scheduled": return .scheduled
        case "group": return .group
        default: return .private
        }
    }
}

extension MemoryVisibility: RawRepresentable {
    public init?(rawValue: Int) {
        switch rawValue {
        case 0: self = .everyone
        case 1: self = .private
        case 2: self = .scheduled
        case 3: self = .group
        default: return nil
        }
    }
    
    public var rawValue: Int {
        switch self {
        case .everyone: return 0
        case .private: return 1
        case .scheduled: return 2
        case .group: return 3
        }
    }
}

public protocol PostOptionsViewControllerDelegate: AnyObject {
    func postOptionsViewControllerDidCancel(_ controller: UIViewController)
    func postOptionsViewController(_ controller: UIViewController,
                                   didFinishPostingWithTitle title: String?,
                                   scheduleDate: Date?,
                                   visibility: MemoryVisibility)
}
