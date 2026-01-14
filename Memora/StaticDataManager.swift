//
//  StaticDataManager.swift
//  Memora
//
//  Created by user@3 on 14/01/26.
//


import Foundation

class StaticDataManager {
    static let shared = StaticDataManager()
    
    // MARK: - Demo Data Storage
    
    // Demo users (hardcoded)
    private var demoUsers: [DemoUser] = [
        DemoUser(id: "user1", name: "John Doe", email: "john@example.com"),
        DemoUser(id: "user2", name: "Jane Smith", email: "jane@example.com"),
        DemoUser(id: "user3", name: "Alex Johnson", email: "alex@example.com")
    ]
    
    // Demo groups storage
    private var demoGroups: [UserGroup] = []
    
    // Demo group members storage
    private var demoGroupMemberships: [DemoGroupMembership] = []
    
    // Demo memories storage
    private var demoMemories: [DemoMemory] = []
    
    // Current logged in user
    private(set) var currentUser: DemoUser?
    
    // Demo daily prompts
    private let dailyPrompts = [
        DailyPrompt(
            id: "1",
            question: "What was your favorite moment today?",
            category: "Daily Reflection",
            createdAt: Date()
        ),
        DailyPrompt(
            id: "2",
            question: "What are you grateful for this week?",
            category: "Gratitude",
            createdAt: Date()
        ),
        DailyPrompt(
            id: "3",
            question: "What made you smile recently?",
            category: "Happiness",
            createdAt: Date()
        )
    ]
    
    // Initialize with some demo groups
    private init() {
        setupDemoData()
    }
    
    private func setupDemoData() {
        // Create some demo groups
        let group1 = UserGroup(
            id: "group1",
            name: "Family Memories",
            code: "FAM123",
            createdBy: "user1",
            adminId: "user1",
            createdAt: Date().addingTimeInterval(-7 * 86400) // 7 days ago
        )
        
        let group2 = UserGroup(
            id: "group2",
            name: "Friends Forever",
            code: "FRN456",
            createdBy: "user2",
            adminId: "user2",
            createdAt: Date().addingTimeInterval(-3 * 86400) // 3 days ago
        )
        
        let group3 = UserGroup(
            id: "group3",
            name: "Work Team",
            code: "WRK789",
            createdBy: "user1",
            adminId: "user1",
            createdAt: Date().addingTimeInterval(-1 * 86400) // 1 day ago
        )
        
        demoGroups = [group1, group2, group3]
        
        // Add memberships
        demoGroupMemberships = [
            DemoGroupMembership(groupId: "group1", userId: "user1", isAdmin: true, joinedAt: Date().addingTimeInterval(-7 * 86400)),
            DemoGroupMembership(groupId: "group1", userId: "user2", isAdmin: false, joinedAt: Date().addingTimeInterval(-6 * 86400)),
            DemoGroupMembership(groupId: "group2", userId: "user2", isAdmin: true, joinedAt: Date().addingTimeInterval(-3 * 86400)),
            DemoGroupMembership(groupId: "group2", userId: "user1", isAdmin: false, joinedAt: Date().addingTimeInterval(-2 * 86400)),
            DemoGroupMembership(groupId: "group3", userId: "user1", isAdmin: true, joinedAt: Date().addingTimeInterval(-1 * 86400))
        ]
        
        // Create demo memories
        demoMemories = [
            DemoMemory(
                id: "1",
                title: "Family Vacation",
                content: "Had an amazing time at the beach with everyone!",
                category: "Family",
                createdAt: Date().addingTimeInterval(-5 * 86400)
            ),
            DemoMemory(
                id: "2",
                title: "Friends Reunion",
                content: "Great catching up with old friends after so long.",
                category: "Friends",
                createdAt: Date().addingTimeInterval(-2 * 86400)
            )
        ]
    }
    
    // MARK: - Simulation Helpers
    
    private func simulateDelay(seconds: Double = 0.5) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
    
    // MARK: - Authentication
    
    func signIn(email: String, password: String) async throws {
        await simulateDelay(seconds: 0.8)
        
        guard let user = demoUsers.first(where: { $0.email.lowercased() == email.lowercased() && $0.password == password }) else {
            throw NSError(domain: "Authentication", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid email or password"])
        }
        
        currentUser = user
        print("✅ Static: User logged in: \(user.name)")
    }
    
    func signUp(name: String, email: String, password: String) async throws {
        await simulateDelay(seconds: 1.0)
        
        // Check if email already exists
        if demoUsers.contains(where: { $0.email.lowercased() == email.lowercased() }) {
            throw NSError(domain: "Authentication", code: 400, userInfo: [NSLocalizedDescriptionKey: "Email already exists"])
        }
        
        let newUser = DemoUser(id: UUID().uuidString, name: name, email: email, password: password)
        demoUsers.append(newUser)
        currentUser = newUser
        
        print("✅ Static: User created: \(name)")
    }
    
    func signOut() async throws {
        await simulateDelay(seconds: 0.3)
        currentUser = nil
        print("✅ Static: User logged out")
    }
    
    // MARK: - User Management
    
    func getCurrentUserId() -> String? {
        return currentUser?.id
    }
    
    func isUserLoggedIn() -> Bool {
        return currentUser != nil
    }
    
    func getCurrentUserEmail() -> String? {
        return currentUser?.email
    }
    
    func getUserProfile() async throws -> UserProfile? {
        await simulateDelay(seconds: 0.4)
        
        guard let user = currentUser else {
            return nil
        }
        
        return UserProfile(
            id: user.id,
            name: user.name,
            email: user.email,
            createdAt: user.createdAt
        )
    }
    
    // MARK: - Groups
    
    func createGroup(name: String) async throws -> UserGroup {
        await simulateDelay(seconds: 0.8)
        
        guard let userId = currentUser?.id else {
            throw NSError(domain: "Authentication", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not logged in"])
        }
        
        let newGroup = UserGroup(
            id: UUID().uuidString,
            name: name,
            code: generateGroupCode(),
            createdBy: userId,
            adminId: userId,
            createdAt: Date()
        )
        
        demoGroups.append(newGroup)
        
        // Add creator as admin member
        let membership = DemoGroupMembership(
            groupId: newGroup.id,
            userId: userId,
            isAdmin: true,
            joinedAt: Date()
        )
        demoGroupMemberships.append(membership)
        
        print("✅ Static: Group created: \(name)")
        return newGroup
    }
    
    func joinGroup(code: String) async throws -> UserGroup {
        await simulateDelay(seconds: 0.8)
        
        guard let userId = currentUser?.id else {
            throw NSError(domain: "Authentication", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not logged in"])
        }
        
        // Find group by code
        guard let group = demoGroups.first(where: { $0.code == code.uppercased() }) else {
            throw NSError(domain: "Groups", code: 404, userInfo: [NSLocalizedDescriptionKey: "Invalid or expired group code"])
        }
        
        // Check if already a member
        let isAlreadyMember = demoGroupMemberships.contains { 
            $0.groupId == group.id && $0.userId == userId 
        }
        
        if !isAlreadyMember {
            // Add as non-admin member (unless they created it)
            let isAdmin = (userId == group.createdBy)
            let membership = DemoGroupMembership(
                groupId: group.id,
                userId: userId,
                isAdmin: isAdmin,
                joinedAt: Date()
            )
            demoGroupMemberships.append(membership)
            print("✅ Static: Joined group: \(group.name)")
        } else {
            print("ℹ️ Static: Already a member of: \(group.name)")
        }
        
        return group
    }
    
    func getMyGroups() async throws -> [UserGroup] {
        await simulateDelay(seconds: 0.5)
        
        guard let userId = currentUser?.id else {
            return []
        }
        
        // Get groups where user is admin, creator, or member
        let userGroups = demoGroups.filter { group in
            // User is admin or creator
            group.adminId == userId || group.createdBy == userId ||
            // User is a member
            demoGroupMemberships.contains { 
                $0.groupId == group.id && $0.userId == userId 
            }
        }
        
        print("✅ Static: Found \(userGroups.count) groups for user")
        return userGroups
    }
    
    func getGroupMembers(groupId: String) async throws -> [GroupMember] {
        await simulateDelay(seconds: 0.5)
        
        // Get all memberships for this group
        let memberships = demoGroupMemberships.filter { $0.groupId == groupId }
        
        // Convert to GroupMember format
        var members: [GroupMember] = []
        
        for membership in memberships {
            if let user = demoUsers.first(where: { $0.id == membership.userId }) {
                let groupMember = GroupMember(
                    id: user.id,
                    name: user.name,
                    email: user.email,
                    isAdmin: membership.isAdmin,
                    joinedAt: membership.joinedAt
                )
                members.append(groupMember)
            }
        }
        
        print("✅ Static: Found \(members.count) members for group")
        return members
    }
    
    func addGroupMember(groupId: String, userId: String, isAdmin: Bool = false) async throws {
        await simulateDelay(seconds: 0.3)
        
        let membership = DemoGroupMembership(
            groupId: groupId,
            userId: userId,
            isAdmin: isAdmin,
            joinedAt: Date()
        )
        demoGroupMemberships.append(membership)
        
        print("✅ Static: Added member to group")
    }
    
    func removeGroupMember(groupId: String, userId: String) async throws {
        await simulateDelay(seconds: 0.3)
        
        demoGroupMemberships.removeAll { 
            $0.groupId == groupId && $0.userId == userId 
        }
        
        print("✅ Static: Removed member from group")
    }
    
    func deleteGroup(groupId: String) async throws {
        await simulateDelay(seconds: 0.5)
        
        // Remove group
        demoGroups.removeAll { $0.id == groupId }
        
        // Remove all memberships for this group
        demoGroupMemberships.removeAll { $0.groupId == groupId }
        
        print("✅ Static: Deleted group")
    }
    
    // MARK: - Memories
    
    func getDailyPrompts() async throws -> [DailyPrompt] {
        await simulateDelay(seconds: 0.3)
        return dailyPrompts
    }
    
    func createMemory(title: String, content: String?, category: String, visibility: String, year: Int?) async throws -> DemoMemory {
        await simulateDelay(seconds: 0.8)
        
        let newMemory = DemoMemory(
            id: UUID().uuidString,
            title: title,
            content: content,
            category: category,
            createdAt: Date()
        )
        
        demoMemories.append(newMemory)
        print("✅ Static: Memory created: \(title)")
        return newMemory
    }
    
    func getMyMemories() async throws -> [DemoMemory] {
        await simulateDelay(seconds: 0.5)
        
        // Return all memories for demo (in real app, filter by user)
        return demoMemories
    }
    
    // MARK: - Helper Methods
    
    private func generateGroupCode() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in letters.randomElement()! })
    }
    
    // MARK: - Demo/Test Methods
    
    func testConnection() async -> Bool {
        await simulateDelay(seconds: 0.3)
        print("✅ Static: Connection test successful")
        return true
    }
    
    func getDemoGroups() -> [UserGroup] {
        // Return the first 2 groups for demo
        return Array(demoGroups.prefix(2))
    }
    
    func resetDemoData() {
        setupDemoData()
        currentUser = nil
        print("✅ Static: Demo data reset")
    }
    
    func getCurrentUser() -> DemoUser? {
        return currentUser
    }
    
    
    // MARK: - Groups (Add this method)

    func updateGroupAdmin(groupId: String, userId: String, isAdmin: Bool) async throws {
        await simulateDelay(seconds: 0.3)
        
        // Find the membership
        if let index = demoGroupMemberships.firstIndex(where: {
            $0.groupId == groupId && $0.userId == userId
        }) {
            // Update the membership
            let oldMembership = demoGroupMemberships[index]
            let updatedMembership = DemoGroupMembership(
                groupId: groupId,
                userId: userId,
                isAdmin: isAdmin,
                joinedAt: oldMembership.joinedAt
            )
            demoGroupMemberships[index] = updatedMembership
            
            print("✅ Static: Updated admin status for user \(userId) in group \(groupId): \(isAdmin)")
        } else {
            throw NSError(domain: "Groups", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Member not found in group"
            ])
        }
    }
}

