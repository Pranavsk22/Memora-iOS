import Foundation

// MARK: - User Profile (from profiles table)
struct UserProfile: Codable, Identifiable {
    let id: String
    let name: String
    let email: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, email
        case createdAt = "created_at"
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
    let userId: String
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

// MARK: - Static Demo Models

// For static authentication
struct DemoUser: Codable, Identifiable {
    let id: String
    let name: String
    let email: String
    let password: String
    let createdAt: Date
    
    init(id: String, name: String, email: String, password: String = "password123") {
        self.id = id
        self.name = name
        self.email = email
        self.password = password
        self.createdAt = Date()
    }
}

// For memory storage
struct DemoMemory: Codable, Identifiable {
    let id: String
    let title: String
    let content: String?
    let category: String
    let createdAt: Date
}

// For static group members
struct DemoGroupMembership {
    let groupId: String
    let userId: String
    let isAdmin: Bool
    let joinedAt: Date
}
