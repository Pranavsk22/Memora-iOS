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
    
    enum CodingKeys: String, CodingKey {
        case id, title, content, year, category
        case userId = "user_id"
        case groupId = "group_id"
        case mediaUrl = "media_url"
        case mediaType = "media_type"
        case createdAt = "created_at"
        case userName = "user_name"
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
