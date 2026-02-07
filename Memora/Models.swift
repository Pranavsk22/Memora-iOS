import Foundation

// MARK: - User Profile (from profiles table)
struct UserProfile: Codable, Identifiable {
    let id: String
    let name: String
    let email: String
    let createdAt: Date?
    let updatedAt: Date?
    
    // Make createdAt optional and add explicit CodingKeys
    enum CodingKeys: String, CodingKey {
        case id, name, email
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Add custom init to handle missing createdAt
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decode(String.self, forKey: .email)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
    
    // ADD THIS: Custom initializer for creating profiles manually
    init(id: String, name: String, email: String, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}


// MARK: - Daily Prompt
struct DailyPrompt: Codable, Identifiable {
    let id: String
    let question: String
    let category: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, question, category
        case createdAt = "created_at"
    }
}

// MARK: - Memory
struct UserMemory: Codable, Identifiable {
    let id: String
    let userId: String
    let title: String
    let content: String?
    let mediaUrl: String?
    let mediaType: String?
    let year: Int?
    let category: String?
    let visibility: String
    let scheduledDate: Date?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, title, content, year, category, visibility
        case userId = "user_id"
        case mediaUrl = "media_url"
        case mediaType = "media_type"
        case scheduledDate = "scheduled_date"
        case createdAt = "created_at"
    }
}

// MARK: - For creating memories
struct MemoryRequest: Codable {
    let title: String
    let content: String?
    let category: String
    let visibility: String
    let year: Int?
}

// MARK: - Group Models (CORRECTED - NO NESTING)
struct UserGroup: Codable, Identifiable {
    let id: String
    let name: String
    let code: String
    let createdBy: String
    let adminId: String  // ADD THIS
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, code
        case createdBy = "created_by"
        case adminId = "admin_id"  // ADD THIS
        case createdAt = "created_at"
    }
    
    init(id: String, name: String, code: String, createdBy: String, adminId: String, createdAt: Date) {
            self.id = id
            self.name = name
            self.code = code
            self.createdBy = createdBy
            self.adminId = adminId
            self.createdAt = createdAt
    }
}



struct GroupMember: Codable, Identifiable {
    let id: String
    let name: String
    let email: String
    let isAdmin: Bool
    let joinedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, email
        case isAdmin = "is_admin"
        case joinedAt = "joined_at"
    }
}

struct GroupMemory: Codable, Identifiable {
    let id: String
    let userId: String?  // Make optional
    let groupId: String
    let title: String
    let content: String?
    let mediaUrl: String?
    let mediaType: String?
    let year: Int?
    let category: String?
    let createdAt: Date
    let userName: String?
    let memoryMedia: [SupabaseMemoryMedia]?
    
    enum CodingKeys: String, CodingKey {
        case id, title, content, year, category
        case userId = "user_id"
        case groupId = "group_id"
        case mediaUrl = "media_url"
        case mediaType = "media_type"
        case createdAt = "created_at"
        case userName = "user_name"
        case memoryMedia = "memory_media"
    }
}



// MARK: - Join Request Models
struct JoinRequest: Codable, Identifiable {
    let id: String
    let groupId: String
    let userId: String
    let status: String
    let requestedAt: Date
    let reviewedAt: Date?
    let reviewedBy: String?
    let userName: String?
    let userEmail: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case userId = "user_id"
        case status
        case requestedAt = "requested_at"
        case reviewedAt = "reviewed_at"
        case reviewedBy = "reviewed_by"
        case userName = "user_name"
        case userEmail = "user_email"
    }
}

// For creating join requests
struct CreateJoinRequest: Codable {
    let groupId: String
    let userId: String
    
    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case userId = "user_id"
    }
}



// MARK: - Memory Models for Supabase
struct SupabaseMemory: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let title: String
    let year: Int?
    let category: String?
    let visibility: String
    let releaseAt: Date?
    let createdAt: Date
    let updatedAt: Date
    
    // ADD THIS: Memory media array (optional for backward compatibility)
    let memoryMedia: [SupabaseMemoryMedia]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case year
        case category
        case visibility
        case releaseAt = "release_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case memoryMedia = "memory_media"
    }
}

struct SupabaseMemoryMedia: Codable, Identifiable {
    let id: UUID
    let memoryId: UUID?
    let mediaUrl: String
    let mediaType: String
    let textContent: String?
    let sortOrder: Int
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case memoryId = "memory_id"
        case mediaUrl = "media_url"
        case mediaType = "media_type"
        case textContent = "text_content"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
    }
}

struct SupabaseMemoryGroupAccess: Codable, Identifiable {
    let id: UUID
    let memoryId: UUID
    let groupId: UUID
    let grantedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case memoryId = "memory_id"
        case groupId = "group_id"
        case grantedAt = "granted_at"
    }
}

struct SupabaseGroupMemory: Codable, Identifiable {
    let id: UUID
    let userId: UUID?
    let groupId: UUID
    let memoryId: UUID
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case groupId = "group_id"
        case memoryId = "memory_id"
        case createdAt = "created_at"
    }
}



// MARK: - Request Models for Creating Memories
struct CreateMemoryRequest: Codable {
    let title: String
    let year: Int?
    let category: String?
    let visibility: String
    let releaseAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case title
        case year
        case category
        case visibility
        case releaseAt = "release_at"
    }
}

struct CreateMemoryMediaRequest: Codable {
    let memoryId: UUID
    let mediaUrl: String
    let mediaType: String
    let textContent: String?
    let sortOrder: Int
    
    enum CodingKeys: String, CodingKey {
        case memoryId = "memory_id"
        case mediaUrl = "media_url"
        case mediaType = "media_type"
        case textContent = "text_content"
        case sortOrder = "sort_order"
    }
}


// MARK: - Enhanced Memory Models with Groups
struct MemoryWithGroups: Codable, Identifiable {
    let memory: SupabaseMemory
    let media: [SupabaseMemoryMedia]
    let groups: [UserGroup]  // Groups this memory is shared with
    let isOwner: Bool
    
    var id: UUID { memory.id }
    var title: String { memory.title }
    var userId: UUID { memory.userId }
    var visibility: String { memory.visibility }
    var createdAt: Date { memory.createdAt }
}

// MARK: - Group Memory View Model
struct GroupMemoryViewModel: Identifiable {
    let id: UUID
    let title: String
    let content: String?
    let imageUrl: String?
    let audioUrl: String?
    let userName: String?
    let userAvatar: String?
    let createdAt: Date
    let isOwnMemory: Bool
    
    init(from memory: SupabaseMemory, media: [SupabaseMemoryMedia] = [], userName: String? = nil) {
        self.id = memory.id
        self.title = memory.title
        self.createdAt = memory.createdAt
        self.isOwnMemory = SupabaseManager.shared.getCurrentUserId() == memory.userId.uuidString
        
        // Extract content from text media
        self.content = media.first { $0.mediaType == "text" }?.textContent
        
        // Extract image URL
        self.imageUrl = media.first { $0.mediaType == "photo" }?.mediaUrl
        
        // Extract audio URL
        self.audioUrl = media.first { $0.mediaType == "audio" }?.mediaUrl
        
        self.userName = userName
        self.userAvatar = nil // You can add avatar support later
    }
}


struct ScheduledMemoryGroup: Codable, Identifiable {
    let id: UUID
    let memoryId: UUID
    let groupId: UUID
    let scheduledAt: Date
    let isOpened: Bool
    let openedAt: Date?
    let memory: SupabaseMemory?  // Optional nested memory
    let group: UserGroup?       // Optional nested group
    
    enum CodingKeys: String, CodingKey {
        case id
        case memoryId = "memory_id"
        case groupId = "group_id"
        case scheduledAt = "scheduled_at"
        case isOpened = "is_opened"
        case openedAt = "opened_at"
        case memory
        case group
    }
}

struct ScheduledMemoryWithGroups: Codable, Identifiable {
    let scheduledMemory: ScheduledMemoryGroup
    let memoryDetails: SupabaseMemory
    let media: [SupabaseMemoryMedia]
    let scheduledForGroups: [UserGroup]
    
    var id: UUID { scheduledMemory.id }
    var isReadyToOpen: Bool {
        memoryDetails.releaseAt ?? Date() <= Date()
    }
}
