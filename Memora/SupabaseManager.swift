//
//  SupabaseManager.swift
//  Memora
//
//  Created by user@3 on 20/01/26.
//


import Foundation
import Supabase
import UIKit



class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    private(set) var currentUser: User?
    
    public let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        
        // IMPORTANT: Use .convertFromSnakeCase for automatic conversion
        //decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        // Date handling
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Try without fractional seconds
            let fallbackFormatter = ISO8601DateFormatter()
            fallbackFormatter.formatOptions = [.withInternetDateTime]
            if let date = fallbackFormatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string: \(dateString)"
            )
        }
        
        return decoder
    }()
    
    private init() {
        //  REPLACE THESE WITH YOUR ACTUAL VALUES
        let supabaseUrl = "https://rphfhugkmcycarakepvb.supabase.co"
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJwaGZodWdrbWN5Y2FyYWtlcHZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc4NDQ5NzUsImV4cCI6MjA4MzQyMDk3NX0.KjYhMxIp1LgKDZ8II31oAyjszVJwURhQZAFn4WAyF9w"
        
        self.client = SupabaseClient(
            supabaseURL: URL(string: supabaseUrl)!,
            supabaseKey: supabaseKey
        )
        
        // Load current user on init
        loadCurrentUser()
    }
    
    // MARK: - Current User Management
    private func loadCurrentUser() {
        Task {
            do {
                let session = try await client.auth.session
                self.currentUser = session.user
            } catch {
                print("No current session: \(error)")
                self.currentUser = nil
            }
        }
    }
    
    func getCurrentUserId() -> String? {
        return currentUser?.id.uuidString
    }
    
    func isUserLoggedIn() -> Bool {
        return getCurrentUserId() != nil
    }
    
    func getCurrentUserEmail() -> String? {
        return currentUser?.email
    }
    
    // MARK: - Authentication
    func signUp(name: String, email: String, password: String) async throws {
        print("Signing up user: \(email)")
        
        do {
            // 1. Create auth user WITHOUT auto-signin
            let authResponse = try await client.auth.signUp(
                email: email,
                password: password
            )
            
            let user = authResponse.user
            let newUserId = user.id.uuidString
            
            print("Auth user created with ID: \(newUserId)")
            
            // IMPORTANT: DO NOT try to sign in here
            // The user needs to verify their email first
            
            // 2. Update current user (will be nil since not signed in)
            self.currentUser = nil // Not signed in yet
            
            // 3. Create profile with upsert in case user already exists
            try await createUserProfile(userId: newUserId, name: name, email: email)
            
            print("Sign up completed successfully for user: \(newUserId)")
            
            // Note: User is NOT signed in - they need to verify email first
            
        } catch {
            print("Sign up error: \(error)")
            
            // If it's a duplicate user error, that's okay
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("user already registered") ||
               errorMessage.contains("already exists") {
                print("User already exists - they should verify their email")
                // Don't throw here - treat this as "success" for UX purposes
                // The user will need to verify email and then sign in
                return
            }
            
            throw error
        }
    }

    
    
    func signIn(email: String, password: String) async throws {
        do {
            _ = try await client.auth.signIn(email: email, password: password)
            // Update current user
            let session = try await client.auth.session
            self.currentUser = session.user
        } catch {
            print("Sign in error: \(error)")
            throw error
        }
    }
    
    func signOut() async throws {
        do {
            try await client.auth.signOut()
            self.currentUser = nil
        } catch {
            print("Sign out error: \(error)")
            throw error
        }
    }
    
    func resendVerificationEmail(email: String) async throws {
        let authResponse = try await client.auth.resend(email: email, type: .signup)
        
        // You might want to handle the response if needed
        print("Verification email resent: \(authResponse)")
    }
    
    // MARK: - Profile Management
    // Update createUserProfile to handle duplicates properly
    func createUserProfile(userId: String, name: String, email: String) async throws {
        print("Creating profile for user ID: \(userId)")
        
        do {
            // Use upsert to handle duplicates gracefully
            try await client
                .from("profiles")
                .upsert([
                    "id": userId,
                    "name": name,
                    "email": email
                ])
                .execute()
            
            print("Profile created/updated successfully for \(userId)")
            
        } catch {
            print("Profile creation error: \(error)")
            
            // If it's a duplicate, that's okay - profile already exists
            let errorString = error.localizedDescription.lowercased()
            if errorString.contains("duplicate") || errorString.contains("already exists") {
                print("Profile already exists (this is okay)")
                return
            }
            
            throw error
        }
    }
    
    func getUserProfile() async throws -> UserProfile? {
        guard let userId = getCurrentUserId() else {
            return nil
        }
        
        do {
            let response = try await client
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
            
            // Use the shared jsonDecoder instead of creating a new one
            return try jsonDecoder.decode(UserProfile.self, from: response.data)
        } catch {
            print("Error fetching profile: \(error)")
            return nil
        }
    }
    
    
    func ensureUserProfileExists(userId: String) async throws {
        print("Ensuring profile exists for user: \(userId)")
        
        do {
            // First, try to get the existing profile
            let response = try await client
                .from("profiles")
                .select("id, name, email")
                .eq("id", value: userId)
                .single()
                .execute()
            
            print("Profile exists for user \(userId)")
            
        } catch {
            // Profile doesn't exist or other error
            print("Profile doesn't exist for user \(userId), creating one...")
            
            // Get user email from auth table
            var userEmail = "user@example.com"
            var userName = "New User"
            
            do {
                let authResponse = try await client
                    .from("auth.users")
                    .select("email")
                    .eq("id", value: userId)
                    .single()
                    .execute()
                
                if let authDict = try? JSONSerialization.jsonObject(with: authResponse.data) as? [String: Any] {
                    userEmail = authDict["email"] as? String ?? "user@example.com"
                    // Use email prefix as name
                    userName = userEmail.components(separatedBy: "@").first ?? "New User"
                }
            } catch {
                print("Could not get auth user info: \(error)")
            }
            
            // Create a profile
            do {
                try await client
                    .from("profiles")
                    .insert([
                        "id": userId,
                        "name": userName,
                        "email": userEmail
                    ])
                    .execute()
                
                print("Created profile for user \(userId): \(userName) (\(userEmail))")
                
            } catch {
                print("Failed to create profile: \(error)")
                
                // If it's a duplicate error, that's okay - profile might have been created by another process
                let errorString = error.localizedDescription.lowercased()
                if errorString.contains("duplicate") || errorString.contains("already exists") {
                    print("Profile already exists (this is okay)")
                    return
                }
                
                throw error
            }
        }
    }
    
    
    
    func createProfileForExistingUser(userId: String, name: String? = nil, email: String? = nil) async throws {
        print("Creating profile for existing user: \(userId)")
        
        var userName = name ?? "User"
        var userEmail = email ?? "user@example.com"
        
        // If we don't have name/email, try to get from auth table
        if name == nil || email == nil {
            do {
                // Note: This requires RLS policies to allow reading auth.users
                let response = try await client
                    .from("auth.users")
                    .select("email")
                    .eq("id", value: userId)
                    .single()
                    .execute()
                
                if let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
                   let authEmail = json["email"] as? String {
                    userEmail = authEmail
                    userName = authEmail.components(separatedBy: "@").first ?? "User"
                }
            } catch {
                print("Could not get user info from auth: \(error)")
                // Use defaults
            }
        }
        
        // Create the profile
        try await createUserProfile(userId: userId, name: userName, email: userEmail)
    }
    
    
    func checkAndFixUserProfile(userId: String) async {
        print("Checking user profile for: \(userId)")
        
        do {
            let profileExists = try await client
                .from("profiles")
                .select("count")
                .eq("id", value: userId)
                .single()
                .execute()
            
            if let json = try? JSONSerialization.jsonObject(with: profileExists.data) as? [String: Any],
               let count = json["count"] as? Int, count > 0 {
                print("User \(userId) has a profile")
            } else {
                print("User \(userId) does NOT have a profile")
                // Create one
                try await ensureUserProfileExists(userId: userId)
            }
        } catch {
            print("Error checking profile: \(error)")
        }
    }
    
    // MARK: - Test Connection
    func testConnection() async -> Bool {
        do {
            _ = try await client
                .from("profiles")
                .select("count")
                .limit(1)
                .execute()
            
            print("Supabase connection successful")
            return true
        } catch {
            print("Supabase connection failed: \(error)")
            return false
        }
    }
    

    // MARK: - Groups
    func createGroup(name: String) async throws -> UserGroup {
        print(" DEBUG createGroup: Starting with name: \(name)")
        
        guard let userId = getCurrentUserId() else {
            print(" DEBUG createGroup: No user ID found")
            throw NSError(domain: "No user logged in", code: 401)
        }
        
        print(" DEBUG createGroup: User ID: \(userId)")
        
        let code = generateGroupCode()
        print(" DEBUG createGroup: Generated code: \(code)")
        
        do {
            print(" DEBUG createGroup: Calling PostgreSQL function...")
            
            let response = try await client
                .rpc("create_group_with_admin", params: [
                    "group_name": name,
                    "group_code": code,
                    "user_id": userId
                ])
                .execute()
            
            print("DEBUG createGroup: Function call successful")
            let jsonString = String(data: response.data, encoding: .utf8) ?? "No data"
            print(" DEBUG createGroup: Response data: \(jsonString)")
            
            // Parse the group
            let groups = try jsonDecoder.decode([UserGroup].self, from: response.data)
            
            guard let group = groups.first else {
                print(" DEBUG createGroup: No group returned from function")
                throw NSError(domain: "No group created", code: 500)
            }
            
            print(" DEBUG createGroup: Group created: \(group.name), ID: \(group.id), Code: \(group.code)")
            
            // MANUAL FIX: Also add creator to group_members table
            print(" DEBUG createGroup: Manually adding creator to group_members...")
            do {
                try await addGroupMember(groupId: group.id, userId: userId, isAdmin: true)
                print(" DEBUG createGroup: Successfully added creator to group_members")
            } catch {
                print(" DEBUG createGroup: Warning: Could not add creator to group_members: \(error)")
                // Continue anyway - at least the group was created
            }
            
            return group
            
        } catch {
            print(" DEBUG createGroup: Error: \(error)")
            print(" DEBUG createGroup: Error localized: \(error.localizedDescription)")
            
            // Try alternative approach
            print(" DEBUG createGroup: Trying alternative approach...")
            return try await createGroupAlternative(name: name)
        }
    }

    // Alternative create group function
    func createGroupAlternative(name: String) async throws -> UserGroup {
        guard let userId = getCurrentUserId() else {
            throw NSError(domain: "No user logged in", code: 401)
        }
        
        let code = generateGroupCode()
        
        // Step 1: Create the group
        let groupResponse = try await client
            .from("groups")
            .insert([
                "name": name,
                "code": code,
                "created_by": userId,
                "admin_id": userId
            ])
            .select()
            .single()
            .execute()
        
        let group = try jsonDecoder.decode(UserGroup.self, from: groupResponse.data)
        
        // Step 2: Add creator as admin member
        try await addGroupMember(groupId: group.id, userId: userId, isAdmin: true)
        
        return group
    }

    func joinGroup(code: String) async throws -> UserGroup {
        print("Looking for group with code: '\(code)'")
        
        guard let userId = getCurrentUserId() else {
            throw NSError(domain: "No user logged in", code: 401)
        }
        
        do {
            // Find group by code - don't use .single() yet
            let groupResponse = try await client
                .from("groups")
                .select()
                .eq("code", value: code.uppercased())
                .execute()
            
            print("Response: \(String(data: groupResponse.data, encoding: .utf8) ?? "No data")")
            
            // First, try to decode as array
            if let jsonArray = try? JSONSerialization.jsonObject(with: groupResponse.data) as? [[String: Any]] {
                print("Found \(jsonArray.count) groups")
                
                guard let firstGroup = jsonArray.first else {
                    throw NSError(domain: "Group not found", code: 404, userInfo: [
                        NSLocalizedDescriptionKey: "Invalid group code"
                    ])
                }
                
                // Debug print all keys
                print("Keys in response: \(firstGroup.keys)")
                for (key, value) in firstGroup {
                    print("  \(key): \(value) (\(type(of: value)))")
                }
                
                // Manual decoding
                guard let id = firstGroup["id"] as? String,
                      let name = firstGroup["name"] as? String,
                      let code = firstGroup["code"] as? String,
                      let createdBy = firstGroup["created_by"] as? String,
                      let adminId = firstGroup["admin_id"] as? String,
                      let createdAtString = firstGroup["created_at"] as? String else {
                    throw NSError(domain: "Invalid group data", code: 500)
                }
                
                // Parse date
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                guard let createdAt = formatter.date(from: createdAtString) else {
                    throw NSError(domain: "Invalid date format", code: 500)
                }
                
                let group = UserGroup(
                    id: id,
                    name: name,
                    code: code,
                    createdBy: createdBy,
                    adminId: adminId,
                    createdAt: createdAt
                )
                
                print("Manually decoded group: \(group.name) (ID: \(group.id))")
                
                // Check if user is already a member
                do {
                    let existingMemberCheck = try await client
                        .from("group_members")
                        .select()
                        .eq("group_id", value: group.id)
                        .eq("user_id", value: userId)
                        .execute()
                    
                    if let memberArray = try? JSONSerialization.jsonObject(with: existingMemberCheck.data) as? [[String: Any]],
                       !memberArray.isEmpty {
                        print("User is already a member of this group")
                        return group
                    }
                    
                } catch {
                    print("No existing membership found")
                }
                
                // Add user as member
                let isAdmin = (userId.lowercased() == group.adminId.lowercased())
                try await addGroupMember(groupId: group.id, userId: userId, isAdmin: isAdmin)
                print("Successfully added user to group")
                
                return group
                
            } else {
                throw NSError(domain: "Invalid response", code: 500)
            }
            
        } catch {
            print("Error finding group: \(error)")
            
            if let supabaseError = error as? PostgrestError,
               supabaseError.code == "PGRST116" {
                throw NSError(domain: "Group not found", code: 404, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid or expired group code"
                ])
            }
            
            throw error
        }
    }

    func getMyGroups() async throws -> [UserGroup] {
        print("getMyGroups: Starting...")
        
        guard let userId = getCurrentUserId() else {
            print("No user ID")
            return getDemoGroups() // Fall back to demo
        }
        
        do {
            // Get groups where user is admin OR creator OR member
            // First, get groups where user is admin/creator
            let adminCreatorResponse = try await client
                .from("groups")
                .select()
                .or("admin_id.eq.\(userId),created_by.eq.\(userId)")
                .execute()
            
            print("Admin/creator query successful")
            
            // Parse admin/creator groups
            var allGroups: [UserGroup] = []
            
            if let adminGroups = try? jsonDecoder.decode([UserGroup].self, from: adminCreatorResponse.data) {
                allGroups.append(contentsOf: adminGroups)
                print("Found \(adminGroups.count) admin/creator groups")
            }
            
            // Now get groups where user is a member (not admin/creator)
            do {
                let memberResponse = try await client
                    .from("group_members")
                    .select("""
                        groups(*)
                    """)
                    .eq("user_id", value: userId)
                    .execute()
                
                print("Member query successful")
                
                // Parse the nested response
                struct MemberGroupWrapper: Codable {
                    let groups: UserGroup
                }
                
                if let memberGroups = try? jsonDecoder.decode([MemberGroupWrapper].self, from: memberResponse.data) {
                    let memberUserGroups = memberGroups.map { $0.groups }
                    
                    // Filter out duplicates (in case user is both member and admin)
                    let newGroups = memberUserGroups.filter { memberGroup in
                        !allGroups.contains { $0.id == memberGroup.id }
                    }
                    
                    allGroups.append(contentsOf: newGroups)
                    print("Found \(newGroups.count) member-only groups")
                }
            } catch {
                print("Error fetching member groups: \(error)")
                // Continue with just admin/creator groups
            }
            
            if allGroups.isEmpty {
                print("No real groups found, showing demo groups")
                return getDemoGroups()
            }
            
            print("Total groups found: \(allGroups.count)")
            return allGroups
            
        } catch {
            print("Query failed: \(error.localizedDescription)")
            print("Falling back to demo groups...")
            return getDemoGroups()
        }
    }

    public func getDemoGroups() -> [UserGroup] {
        print(" DEMO: Creating demo groups")
        
        guard let userId = getCurrentUserId() else {
            // Create a truly dummy group if no user ID
            let dummyGroup = UserGroup(
                id: UUID().uuidString,
                name: "Sample Family",
                code: "SAMPLE123",
                createdBy: "demo_user",
                adminId: "demo_user",
                createdAt: Date()
            )
            return [dummyGroup]
        }
        
        // Create demo groups based on real user ID
        let demoGroup1 = UserGroup(
            id: UUID().uuidString,
            name: "My Family",
            code: "FAMILY",
            createdBy: userId,
            adminId: userId,
            createdAt: Date().addingTimeInterval(-86400) // 1 day ago
        )
        
        let demoGroup2 = UserGroup(
            id: UUID().uuidString,
            name: "Friends Group",
            code: "FRIENDS",
            createdBy: userId,
            adminId: userId,
            createdAt: Date().addingTimeInterval(-172800) // 2 days ago
        )
        
        return [demoGroup1, demoGroup2]
    }

    // Alternative: If you need to show groups where user is just a member (not admin)
    func getAllMyGroups() async throws -> [UserGroup] {
        guard let userId = getCurrentUserId() else {
            return []
        }
        
        print(" DEBUG getAllMyGroups: Starting for user: \(userId)")
        
        do {
            // Get groups where user is admin/creator
            let adminResponse = try await client
                .from("groups")
                .select()
                .or("admin_id.eq.\(userId),created_by.eq.\(userId)")
                .execute()
            
            let adminGroups = try jsonDecoder.decode([UserGroup].self, from: adminResponse.data)
            print(" DEBUG getAllMyGroups: Found \(adminGroups.count) admin/creator groups")
            
            // For member groups, we'll handle them separately via API call
            // or show a loading state first
            return adminGroups
            
        } catch {
            print(" DEBUG getAllMyGroups: Error: \(error)")
            return []
        }
    }
    
    func getMyGroupsForDemo() async throws -> [UserGroup] {
        print("🎯 DEMO MODE: Getting groups with workaround")
        
        // For demo purposes, let's cache groups in UserDefaults
        let defaults = UserDefaults.standard
        
        // Check if we have cached groups
        if let cachedData = defaults.data(forKey: "cached_groups"),
           let cachedGroups = try? jsonDecoder.decode([UserGroup].self, from: cachedData) {
            print("🎯 DEMO: Returning \(cachedGroups.count) cached groups")
            return cachedGroups
        }
        
        // If no cache, create a dummy group for demo
        let dummyGroup = UserGroup(
            id: UUID().uuidString,
            name: "Demo Family",
            code: "DEMO123",
            createdBy: getCurrentUserId() ?? "demo_user",
            adminId: getCurrentUserId() ?? "demo_user",
            createdAt: Date()
        )
        
        let demoGroups = [dummyGroup]
        
        // Cache for next time
        if let encoded = try? JSONEncoder().encode(demoGroups) {
            defaults.set(encoded, forKey: "cached_groups")
        }
        
        print("🎯 DEMO: Created \(demoGroups.count) demo groups")
        return demoGroups
    }

    func getGroupMembers(groupId: String) async throws -> [GroupMember] {
        do {
            let response = try await client
                .from("group_members")
                .select("""
                    user_id, 
                    is_admin, 
                    joined_at, 
                    profiles!inner(id, name, email)
                """)
                .eq("group_id", value: groupId)
                .execute()
            
            print("Group members raw response: \(String(data: response.data, encoding: .utf8) ?? "")")
            
            // Parse manually first to debug
            if let jsonArray = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] {
                print("Found \(jsonArray.count) members in raw response")
                for member in jsonArray {
                    print("  Member: \(member)")
                }
            }
            
            // Use a simpler approach - decode manually
            guard let jsonArray = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] else {
                print("Could not parse group members response")
                return []
            }
            
            var members: [GroupMember] = []
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            for item in jsonArray {
                guard let userId = item["user_id"] as? String,
                      let isAdminValue = item["is_admin"],
                      let joinedAtString = item["joined_at"] as? String,
                      let profilesDict = item["profiles"] as? [String: Any],
                      let userName = profilesDict["name"] as? String,
                      let userEmail = profilesDict["email"] as? String else {
                    print("Skipping invalid member data")
                    continue
                }
                
                // Convert isAdmin to Bool (it could be 1/0 or true/false)
                let isAdmin: Bool
                if let boolValue = isAdminValue as? Bool {
                    isAdmin = boolValue
                } else if let intValue = isAdminValue as? Int {
                    isAdmin = intValue == 1
                } else if let stringValue = isAdminValue as? String {
                    isAdmin = stringValue.lowercased() == "true" || stringValue == "1"
                } else {
                    isAdmin = false
                }
                
                let joinedAt = dateFormatter.date(from: joinedAtString) ?? Date()
                
                let member = GroupMember(
                    id: userId,
                    name: userName,
                    email: userEmail,
                    isAdmin: isAdmin,
                    joinedAt: joinedAt
                )
                members.append(member)
            }
            
            print("Successfully parsed \(members.count) members")
            return members
            
        } catch {
            print("Error fetching group members: \(error)")
            throw error
        }
    }
    

    func addGroupMember(groupId: String, userId: String, isAdmin: Bool = false) async throws {
        // Use AnyJSON to handle the boolean properly
        let data: [String: AnyJSON] = [
            "group_id": .string(groupId),
            "user_id": .string(userId),
            "is_admin": .bool(isAdmin)
        ]
        
        try await client
            .from("group_members")
            .insert(data)
            .execute()
    }

    func removeGroupMember(groupId: String, userId: String) async throws {
        try await client
            .from("group_members")
            .delete()
            .eq("group_id", value: groupId)
            .eq("user_id", value: userId)
            .execute()
    }

    func deleteGroup(groupId: String) async throws {
        try await client
            .from("groups")
            .delete()
            .eq("id", value: groupId)
            .execute()
    }

    func updateGroupAdmin(groupId: String, userId: String, isAdmin: Bool) async throws {
        print("updateGroupAdmin: Updating admin status for user \(userId) to \(isAdmin)")
        
        // Step 1: Update group_members table
        let memberData: [String: AnyJSON] = [
            "is_admin": .bool(isAdmin)
        ]
        
        try await client
            .from("group_members")
            .update(memberData)
            .eq("group_id", value: groupId)
            .eq("user_id", value: userId)
            .execute()
        
        print("updateGroupAdmin: Updated group_members table")
        
        // Step 2: If making admin, ALSO update the groups table's admin_id
        if isAdmin {
            let groupData: [String: AnyJSON] = [
                "admin_id": .string(userId)
            ]
            
            try await client
                .from("groups")
                .update(groupData)
                .eq("id", value: groupId)
                .execute()
            
            print("updateGroupAdmin: Updated groups table admin_id to \(userId)")
        } else {
            // If removing admin and this user was the main admin in groups table,
            // we need to assign a new admin. Let's pick the first other admin.
            // For now, we'll leave it - this is a more complex scenario.
            print("updateGroupAdmin: User removed as admin, but groups table not updated (needs new admin assignment)")
        }
    }
    

    
    
    // MARK: - Join Requests
    func createJoinRequest(groupId: String) async throws {
        guard let userId = getCurrentUserId() else {
            throw NSError(domain: "No user logged in", code: 401)
        }
        
        print("createJoinRequest: Creating request for group: \(groupId), user: \(userId)")
        
        // FIRST: Ensure the user has a profile
        try await ensureUserProfileExists(userId: userId)
        
        // Check if user already has a pending request
        do {
            let existingResponse = try await client
                .from("join_requests")
                .select("*")
                .eq("group_id", value: groupId)
                .eq("user_id", value: userId)
                .eq("status", value: "pending")
                .execute()
            
            if let jsonArray = try? JSONSerialization.jsonObject(with: existingResponse.data) as? [[String: Any]],
               !jsonArray.isEmpty {
                print("User already has a pending request for this group")
                throw NSError(domain: "Already requested", code: 409, userInfo: [
                    NSLocalizedDescriptionKey: "You already have a pending request to join this group"
                ])
            }
        } catch {
            print("Error checking existing requests: \(error)")
        }
        
        // Create the join request
        do {
            let response = try await client
                .from("join_requests")
                .insert([
                    "group_id": groupId,
                    "user_id": userId,
                    "status": "pending"
                ])
                .select()
                .execute()
            
            print("createJoinRequest: Request created successfully")
            
        } catch {
            print("createJoinRequest: Error: \(error)")
            if let supabaseError = error as? PostgrestError {
                print("Error code: \(supabaseError.code ?? "No code")")
                print("Error message: \(supabaseError.message)")
            }
            throw error
        }
    }

    func getPendingJoinRequests(groupId: String) async throws -> [JoinRequest] {
        print("getPendingJoinRequests: Fetching for group: \(groupId)")
        
        do {
            // Try Method 1: Simple join query
            let response = try await client
                .from("join_requests")
                .select("""
                    *,
                    profiles(id, name, email)
                """)
                .eq("group_id", value: groupId)
                .eq("status", value: "pending")
                .order("requested_at", ascending: false)
                .execute()
            
            let responseString = String(data: response.data, encoding: .utf8) ?? "No data"
            print("Join requests response: \(responseString)")
            
            // Try to parse with a flexible decoder
            if let jsonArray = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] {
                print("Successfully parsed as JSON array with \(jsonArray.count) items")
                
                // Process each item manually
                var joinRequests: [JoinRequest] = []
                
                for item in jsonArray {
                    // Extract join request data
                    guard let id = item["id"] as? String,
                          let groupId = item["group_id"] as? String,
                          let userId = item["user_id"] as? String,
                          let status = item["status"] as? String,
                          let requestedAtString = item["requested_at"] as? String else {
                        continue
                    }
                    
                    // Parse date
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    guard let requestedAt = formatter.date(from: requestedAtString) else {
                        continue
                    }
                    
                    let reviewedAtString = item["reviewed_at"] as? String
                    let reviewedAt = reviewedAtString.flatMap { formatter.date(from: $0) }
                    let reviewedBy = item["reviewed_by"] as? String
                    
                    // Extract profile data
                    var userName: String? = nil
                    var userEmail: String? = nil
                    
                    if let profiles = item["profiles"] as? [String: Any] {
                        userName = profiles["name"] as? String
                        userEmail = profiles["email"] as? String
                    }
                    
                    let request = JoinRequest(
                        id: id,
                        groupId: groupId,
                        userId: userId,
                        status: status,
                        requestedAt: requestedAt,
                        reviewedAt: reviewedAt,
                        reviewedBy: reviewedBy,
                        userName: userName ?? "Unknown User",
                        userEmail: userEmail ?? "No email available"
                    )
                    joinRequests.append(request)
                }
                
                print("Manually created \(joinRequests.count) join requests")
                return joinRequests
            }
            
            // If manual parsing fails, try the alternative method
            print("Manual parsing failed, trying alternative method...")
            return try await getPendingJoinRequestsAlternative(groupId: groupId)
            
        } catch {
            print("getPendingJoinRequests error: \(error)")
            print("Trying alternative method...")
            return try await getPendingJoinRequestsAlternative(groupId: groupId)
        }
    }

    private func getPendingJoinRequestsAlternative(groupId: String) async throws -> [JoinRequest] {
        print("Using alternative method for join requests")
        
        // Method 1: First, get all pending requests
        let requestsResponse = try await client
            .from("join_requests")
            .select("*")
            .eq("group_id", value: groupId)
            .eq("status", value: "pending")
            .order("requested_at", ascending: false)
            .execute()
        
        let requestsString = String(data: requestsResponse.data, encoding: .utf8) ?? "No data"
        print("Raw join requests: \(requestsString)")
        
        // Parse the response manually first to debug
        guard let jsonArray = try? JSONSerialization.jsonObject(with: requestsResponse.data) as? [[String: Any]] else {
            print("Failed to parse join requests response")
            return []
        }
        
        print("Parsed manually as array with \(jsonArray.count) items")
        
        // Parse each request manually
        var joinRequests: [JoinRequest] = []
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        for item in jsonArray {
            guard let id = item["id"] as? String,
                  let groupId = item["group_id"] as? String,
                  let userId = item["user_id"] as? String,
                  let status = item["status"] as? String,
                  let requestedAtString = item["requested_at"] as? String else {
                print("Skipping item - missing required fields")
                continue
            }
            
            // Parse dates
            let requestedAt = dateFormatter.date(from: requestedAtString) ?? Date()
            let reviewedAtString = item["reviewed_at"] as? String
            let reviewedAt = reviewedAtString.flatMap { dateFormatter.date(from: $0) }
            let reviewedBy = item["reviewed_by"] as? String
            
            // Now get the user's profile information - FIXED VERSION
            var userName = "Unknown User"
            var userEmail = "No email available"
            
            // Try to get the user's profile WITHOUT .single() - use regular query
            do {
                let profileResponse = try await client
                    .from("profiles")
                    .select("id, name, email")
                    .eq("id", value: userId)
                    .execute()
                
                if let profilesArray = try? JSONSerialization.jsonObject(with: profileResponse.data) as? [[String: Any]],
                   let firstProfile = profilesArray.first {
                    userName = firstProfile["name"] as? String ?? "Unknown User"
                    userEmail = firstProfile["email"] as? String ?? "No email available"
                    print("Found profile for \(userId): \(userName) (\(userEmail))")
                } else {
                    // Instead of just printing "No profile found", actually create one
                    print("No profile found for user ID: \(userId) - creating one")

                    do {
                        // Try to create a profile for this user
                        try await createProfileForExistingUser(userId: userId)
                        
                        // Now try to get the profile again
                        let profileResponse = try await client
                            .from("profiles")
                            .select("id, name, email")
                            .eq("id", value: userId)
                            .single()
                            .execute()
                        
                        if let profileDict = try? JSONSerialization.jsonObject(with: profileResponse.data) as? [String: Any] {
                            userName = profileDict["name"] as? String ?? "User"
                            userEmail = profileDict["email"] as? String ?? "No email"
                            print("Created and retrieved profile for \(userId): \(userName)")
                        }
                    } catch {
                        print("Failed to create profile for \(userId): \(error)")
                        // Use default values
                        userName = "User ID: \(String(userId.prefix(8)))..."
                        userEmail = "No email available"
                    }
                }
            } catch {
                print("Error fetching profile: \(error.localizedDescription)")
                // If we can't get profile, use a fallback
                userName = "User \(String(userId.prefix(8)))"
                userEmail = "user@example.com"
            }
            
            let request = JoinRequest(
                id: id,
                groupId: groupId,
                userId: userId,
                status: status,
                requestedAt: requestedAt,
                reviewedAt: reviewedAt,
                reviewedBy: reviewedBy,
                userName: userName,
                userEmail: userEmail
            )
            joinRequests.append(request)
        }
        
        print("Alternative method returning \(joinRequests.count) requests")
        return joinRequests
    }
    

    // MARK: - Join Requests
    func approveJoinRequest(requestId: String, groupId: String, userId: String) async throws {
        print("Approving join request: \(requestId)")
        
        guard let currentUserId = getCurrentUserId() else {
            throw NSError(domain: "No user logged in", code: 401)
        }
        
        // Get current date as ISO8601 string
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let currentDateString = formatter.string(from: Date())
        
        // 1. Update join request status
        try await client
            .from("join_requests")
            .update([
                "status": "approved",
                "reviewed_at": currentDateString,
                "reviewed_by": currentUserId
            ])
            .eq("id", value: requestId)
            .execute()
        
        // 2. Add user to group_members
        try await addGroupMember(groupId: groupId, userId: userId, isAdmin: false)
        
        print("Join request approved and user added to group")
    }

    func rejectJoinRequest(requestId: String) async throws {
        print("Rejecting join request: \(requestId)")
        
        guard let currentUserId = getCurrentUserId() else {
            throw NSError(domain: "No user logged in", code: 401)
        }
        
        // Get current date as ISO8601 string
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let currentDateString = formatter.string(from: Date())
        
        try await client
            .from("join_requests")
            .update([
                "status": "rejected",
                "reviewed_at": currentDateString,
                "reviewed_by": currentUserId
            ])
            .eq("id", value: requestId)
            .execute()
        
        print("Join request rejected")
    }

    func checkExistingJoinRequest(groupId: String) async throws -> Bool {
        guard let userId = getCurrentUserId() else {
            return false
        }
        
        let response = try await client
            .from("join_requests")
            .select()
            .eq("group_id", value: groupId)
            .eq("user_id", value: userId)
            .eq("status", value: "pending")
            .execute()
        
        let requests = try jsonDecoder.decode([JoinRequest].self, from: response.data)
        return !requests.isEmpty
    }

    func checkIfUserIsMember(groupId: String) async throws -> Bool {
        guard let userId = getCurrentUserId() else {
            return false
        }
        
        let response = try await client
            .from("group_members")
            .select()
            .eq("group_id", value: groupId)
            .eq("user_id", value: userId)
            .execute()
        
        // Check if we got any results
        if let jsonArray = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] {
            return !jsonArray.isEmpty
        }
        
        return false
    }
    
    //MARK: Group Memories
    func getGroupMemories(groupId: String) async throws -> [GroupMemory] {
        do {
            let response = try await client
                .from("group_memories")
                .select("""
                    id,
                    created_at,
                    memories!inner(
                        id,
                        user_id,
                        title,
                        year,
                        category,
                        visibility,
                        release_at,
                        created_at,
                        memory_media!inner(
                            media_url,
                            media_type,
                            text_content
                        ),
                        profiles!inner(name)
                    )
                """)
                .eq("group_id", value: groupId)
                .order("created_at", ascending: false)
                .execute()
            
            print("Group memories raw response: \(String(data: response.data, encoding: .utf8) ?? "")")
            
            // Parse manually
            guard let jsonArray = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] else {
                print("Could not parse group memories response")
                return []
            }
            
            var memories: [GroupMemory] = []
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            for item in jsonArray {
                guard let id = item["id"] as? String,
                      let createdAtString = item["created_at"] as? String,
                      let memoriesDict = item["memories"] as? [String: Any],
                      let memoryId = memoriesDict["id"] as? String,
                      let userId = memoriesDict["user_id"] as? String,
                      let title = memoriesDict["title"] as? String,
                      let memoryCreatedAtString = memoriesDict["created_at"] as? String,
                      let profilesDict = memoriesDict["profiles"] as? [String: Any],
                      let userName = profilesDict["name"] as? String else {
                    print("Skipping invalid memory data - missing basic fields")
                    continue
                }
                
                // Extract content from memory_media
                var content: String? = nil
                var mediaUrl: String? = nil
                var mediaType: String? = nil
                var memoryMediaArray: [SupabaseMemoryMedia] = [] // ADD THIS
                
                if let memoryMediaRawArray = memoriesDict["memory_media"] as? [[String: Any]] {
                    for media in memoryMediaRawArray {
                        // Try to create SupabaseMemoryMedia from the raw data
                        if let mediaUrlValue = media["media_url"] as? String,
                           let mediaTypeValue = media["media_type"] as? String {
                            
                            let textContent = media["text_content"] as? String
                            
                            // Create a SupabaseMemoryMedia object
                            // Note: You'll need to generate UUIDs for id and memoryId
                            let memoryMedia = SupabaseMemoryMedia(
                                id: UUID(), // Generate new UUID
                                memoryId: UUID(uuidString: memoryId) ?? UUID(), // Convert or generate
                                mediaUrl: mediaUrlValue,
                                mediaType: mediaTypeValue,
                                textContent: textContent,
                                sortOrder: 0, // Default value
                                createdAt: Date() // Default value
                            )
                            memoryMediaArray.append(memoryMedia)
                            
                            // Also set content if it's text media
                            if mediaTypeValue == "text",
                               let textContent = textContent,
                               !textContent.isEmpty {
                                content = textContent
                            }
                            
                            // Set first non-text media as primary media
                            if mediaUrl == nil && mediaTypeValue != "text" {
                                mediaUrl = mediaUrlValue
                                mediaType = mediaTypeValue
                            }
                        }
                    }
                }
                
                let year = memoriesDict["year"] as? Int
                let category = memoriesDict["category"] as? String
                
                let createdAt = dateFormatter.date(from: createdAtString) ?? Date()
                let memoryCreatedAt = dateFormatter.date(from: memoryCreatedAtString) ?? Date()
                
                let memory = GroupMemory(
                    id: memoryId,
                    userId: userId,
                    groupId: groupId,
                    title: title,
                    content: content,
                    mediaUrl: mediaUrl,
                    mediaType: mediaType,
                    year: year,
                    category: category,
                    createdAt: memoryCreatedAt,
                    userName: userName,
                    memoryMedia: memoryMediaArray
                )
                memories.append(memory)
            }
            
            print("Successfully parsed \(memories.count) group memories")
            return memories
            
        } catch {
            print("Error fetching group memories: \(error)")
            throw error
        }
    }
    
    // Add this to your SupabaseManager
    func testEverything() async {
        print("\n=== RUNNING COMPREHENSIVE TEST ===")
        
        // Test 1: Check if we can query
        print("\n Testing basic query...")
        do {
            let testResponse = try await client
                .from("groups")
                .select("count")
                .limit(1)
                .execute()
            print(" Basic query works")
        } catch {
            print(" Basic query failed: \(error)")
        }
        
        // Test 2: Try to get groups
        print("\n Testing getMyGroups...")
        let groups = try? await getMyGroups()
        print(" getMyGroups returned \(groups?.count ?? 0) groups")
        
        // Test 3: Create a test group
        print("\n Testing group creation...")
        do {
            let testGroup = try await createGroup(name: "Test Group for Demo")
            print(" Created group: \(testGroup.name) (\(testGroup.code))")
        } catch {
            print(" Group creation failed: \(error)")
        }
        
        print("\n=== TEST COMPLETE ===")
    }
    
    func testDecoding() async {
        print(" TEST: Testing UserGroup decoding...")
        
        // Create a test JSON that matches what Supabase returns
        let testJSON = """
        [
          {
            "id": "4e2fd106-23b3-4042-946a-51fdf6b5cc87",
            "name": "Happy Family",
            "code": "IMJRLO",
            "created_by": "bd2a2f49-e2a7-4c3a-a5fa-903ebc11f06b",
            "admin_id": "bd2a2f49-e2a7-4c3a-a5fa-903ebc11f06b",
            "created_at": "2026-01-12T12:00:24.690154+00:00"
          }
        ]
        """.data(using: .utf8)!
        
        do {
            let groups = try jsonDecoder.decode([UserGroup].self, from: testJSON)
            print(" TEST: Successfully decoded \(groups.count) test groups")
            for group in groups {
                print("   - \(group.name): createdBy=\(group.createdBy), adminId=\(group.adminId)")
            }
        } catch {
            print(" TEST: Failed to decode: \(error)")
            
            // Try without key conversion
            let plainDecoder = JSONDecoder()
            plainDecoder.dateDecodingStrategy = jsonDecoder.dateDecodingStrategy
            
            do {
                struct PlainUserGroup: Codable {
                    let id: String
                    let name: String
                    let code: String
                    let created_by: String
                    let admin_id: String
                    let created_at: Date
                }
                
                let plainGroups = try plainDecoder.decode([PlainUserGroup].self, from: testJSON)
                print(" TEST: Successfully decoded with plain keys")
                for group in plainGroups {
                    print("   - \(group.name): created_by=\(group.created_by), admin_id=\(group.admin_id)")
                }
            } catch {
                print(" TEST: Plain decoding also failed: \(error)")
            }
        }
    }
    
    
    func testGroupDecoding() async {
        print(" TEST: Testing group decoding...")
        
        let testJSON = """
        [{
            "id": "cd26a0c0-3aea-46b4-abab-1abce519f84b",
            "name": "mantosh family",
            "code": "4ECBSH",
            "created_by": "bd2a2f49-e2a7-4c3a-a5fa-903ebc11f06b",
            "admin_id": "bd2a2f49-e2a7-4c3a-a5fa-903ebc11f06b",
            "created_at": "2026-01-12T07:11:08.556524+00:00"
        }]
        """.data(using: .utf8)!
        
        do {
            let groups = try jsonDecoder.decode([UserGroup].self, from: testJSON)
            print(" TEST: Successfully decoded \(groups.count) groups")
            for group in groups {
                print("  - \(group.name), createdBy: \(group.createdBy), adminId: \(group.adminId)")
            }
        } catch {
            print(" TEST: Failed to decode: \(error)")
            
            // Try with a custom decoder
            let customDecoder = JSONDecoder()
            customDecoder.keyDecodingStrategy = .useDefaultKeys
            
            do {
                struct RawUserGroup: Codable {
                    let id: String
                    let name: String
                    let code: String
                    let created_by: String
                    let admin_id: String
                    let created_at: String
                }
                
                let rawGroups = try customDecoder.decode([RawUserGroup].self, from: testJSON)
                print(" TEST: Successfully decoded with raw keys")
                for group in rawGroups {
                    print("  - \(group.name), created_by: \(group.created_by), admin_id: \(group.admin_id)")
                }
            } catch {
                print(" TEST: Raw decoding also failed: \(error)")
            }
        }
    }
    
    func testGroupFetching() async {
        print("\n TEST: Testing group fetching...")
        
        // Test 1: Get current user's groups
        print("\n TEST 1: Fetching user's groups...")
        do {
            let groups = try await getMyGroups()
            print(" TEST 1: Found \(groups.count) groups")
            for group in groups {
                print("  - \(group.name) (Admin: \(group.adminId == getCurrentUserId() ?? ""))")
            }
        } catch {
            print(" TEST 1: Failed: \(error)")
        }
        
        // Test 2: Direct query to groups table
        print("\n TEST 2: Direct query to groups table...")
        do {
            let response = try await client
                .from("groups")
                .select()
                .execute()
            
            let allGroups = try jsonDecoder.decode([UserGroup].self, from: response.data)
            print(" TEST 2: Found \(allGroups.count) total groups in database")
        } catch {
            print(" TEST 2: Failed: \(error)")
        }
        
        // Test 3: Check group_members table
        print("\n TEST 3: Checking group_members table...")
        do {
            let response = try await client
                .from("group_members")
                .select()
                .execute()
            
            print(" TEST 3: Group members response: \(String(data: response.data, encoding: .utf8) ?? "")")
        } catch {
            print(" TEST 3: Failed: \(error)")
        }
    }
    
    func testGroupsQuery() async {
        print(" TEST: Testing groups query...")
        
        guard let userId = getCurrentUserId() else {
            print(" TEST: No user ID")
            return
        }
        
        // Test 1: Direct query
        do {
            let response = try await client
                .from("groups")
                .select("id, name")
                .eq("admin_id", value: userId)
                .execute()
            
            print(" TEST 1: Direct admin query: \(String(data: response.data, encoding: .utf8) ?? "")")
        } catch {
            print(" TEST 1: Failed: \(error)")
        }
        
        // Test 2: Created by query
        do {
            let response = try await client
                .from("groups")
                .select("id, name")
                .eq("created_by", value: userId)
                .execute()
            
            print(" TEST 2: Direct created_by query: \(String(data: response.data, encoding: .utf8) ?? "")")
        } catch {
            print(" TEST 2: Failed: \(error)")
        }
    }
    
    func testFindGroupByCode() async {
        print("\n TEST: Testing group finding...")
        
        // Test with a code that definitely exists
        let testCodes = ["IMJRLO", "TEST123", "B9FLFK", "E7KPNJ"]
        
        for code in testCodes {
            print("\n Testing code: \(code)")
            
            do {
                let response = try await client
                    .from("groups")
                    .select("*")
                    .eq("code", value: code)
                    .single()
                    .execute()
                
                print(" Found group with code \(code)")
                print(" Response: \(String(data: response.data, encoding: .utf8) ?? "No data")")
                
            } catch {
                print(" Failed with code \(code): \(error)")
                
                // Try without .single()
                do {
                    let response = try await client
                        .from("groups")
                        .select("*")
                        .eq("code", value: code)
                        .execute()
                    
                    print(" Query without .single() succeeded")
                    print(" Response: \(String(data: response.data, encoding: .utf8) ?? "No data")")
                    
                } catch {
                    print(" Even without .single() failed: \(error)")
                }
            }
        }
    }
    
    func testJoinRequestCreation() async {
        print("Testing join request creation...")
        
        // Use a test group ID that exists
        let testGroupId = "aa258d88-713c-4429-b248-68be809f9e05" // admin testing 2
        
        print("Current user ID: \(SupabaseManager.shared.getCurrentUserId() ?? "No user")")
        print("Testing with group ID: \(testGroupId)")
        
        do {
            // Try to create a join request
            try await SupabaseManager.shared.createJoinRequest(groupId: testGroupId)
            print("Join request created successfully")
            
            // Check what's in the join_requests table
            let response = try await SupabaseManager.shared.client
                .from("join_requests")
                .select("*")
                .eq("group_id", value: testGroupId)
                .execute()
            
            print("Join requests in table: \(String(data: response.data, encoding: .utf8) ?? "No data")")
            
        } catch {
            print("Error: \(error)")
            
            // Check the exact error
            if let supabaseError = error as? PostgrestError {
                print("Supabase error code: \(supabaseError.code ?? "No code")")
                print("Supabase error message: \(supabaseError.message)")
                print("Supabase error detail: \(supabaseError.detail ?? "No detail")")
            }
        }
    }
    
    func testAdminFlow() async {
        print("\n=== TESTING ADMIN FLOW ===")
        
        // Test group (Happy Family)
        let testGroupId = "4e2fd106-23b3-4042-946a-51fdf6b5cc87"
        print("Testing with group ID: \(testGroupId)")
        
        print("\n1. Checking current user...")
        let currentUserId = SupabaseManager.shared.getCurrentUserId()
        print("   Current user ID: \(currentUserId ?? "No user")")
        
        print("\n2. Getting group info...")
        do {
            let groupResponse = try await client
                .from("groups")
                .select("*")
                .eq("id", value: testGroupId)
                .single()
                .execute()
            
            let group = try jsonDecoder.decode(UserGroup.self, from: groupResponse.data)
            print("   Group name: \(group.name)")
            print("   Group admin ID: \(group.adminId)")
            print("   Is current user admin? \(currentUserId?.lowercased() == group.adminId.lowercased())")
            
            print("\n3. Checking pending join requests...")
            let requests = try await getPendingJoinRequests(groupId: testGroupId)
            print("   Found \(requests.count) pending requests")
            for request in requests {
                print("   - \(request.userName ?? "Unknown"): \(request.userEmail ?? "No email")")
            }
            
            print("\n4. Checking group members...")
            let members = try await getGroupMembers(groupId: testGroupId)
            print("   Found \(members.count) members")
            for member in members {
                print("   - \(member.name): \(member.isAdmin ? "Admin" : "Member")")
            }
            
        } catch {
            print("   Error: \(error)")
        }
        
        print("\n=== TEST COMPLETE ===")
    }
    
    func debugJoinRequestData() async {
        print("\n=== DEBUGGING JOIN REQUEST DATA ===")
        
        // Test with a group that should have join requests
        let testGroupId = "aa258d88-713c-4429-b248-68be809f9e05"
        let testUserId = "b1263034-3827-49ca-ae2a-9e96944679dd"
        
        print("1. Testing join_requests table directly...")
        do {
            let response = try await client
                .from("join_requests")
                .select("*")
                .eq("group_id", value: testGroupId)
                .execute()
            
            print("Join requests in table: \(String(data: response.data, encoding: .utf8) ?? "No data")")
            
            if let jsonArray = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] {
                print("Found \(jsonArray.count) join requests")
                for (index, request) in jsonArray.enumerated() {
                    print("  Request \(index):")
                    for (key, value) in request {
                        print("    \(key): \(value)")
                    }
                }
            }
        } catch {
            print("Error: \(error)")
        }
        
        print("\n2. Testing profiles table for user \(testUserId)...")
        do {
            let response = try await client
                .from("profiles")
                .select("*")
                .eq("id", value: testUserId)
                .single()
                .execute()
            
            print("Profile data: \(String(data: response.data, encoding: .utf8) ?? "No data")")
        } catch {
            print("Error: \(error)")
        }
        
        print("\n=== DEBUG COMPLETE ===")
    }
    
    func debugGroupMembers() async {
        print("\n=== DEBUGGING GROUP MEMBERS ===")
        
        let groupId = "4e2fd106-23b3-4042-946a-51fdf6b5cc87"
        
        print("1. Checking group_members table directly...")
        do {
            let response = try await client
                .from("group_members")
                .select("*")
                .eq("group_id", value: groupId)
                .execute()
            
            print("Group members: \(String(data: response.data, encoding: .utf8) ?? "No data")")
            
            if let jsonArray = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] {
                print("Found \(jsonArray.count) group members")
                for member in jsonArray {
                    print("  - User: \(member["user_id"] ?? "No user"), Admin: \(member["is_admin"] ?? "No admin status")")
                }
            }
        } catch {
            print("Error: \(error)")
        }
        
        print("\n2. Checking current user in group_members...")
        if let currentUserId = SupabaseManager.shared.getCurrentUserId() {
            do {
                let response = try await client
                    .from("group_members")
                    .select("*")
                    .eq("group_id", value: groupId)
                    .eq("user_id", value: currentUserId)
                    .execute()
                
                print("Current user membership: \(String(data: response.data, encoding: .utf8) ?? "No data")")
                
                if let jsonArray = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] {
                    if jsonArray.isEmpty {
                        print("  - Current user is NOT a member of this group!")
                    } else {
                        print("  - Current user IS a member")
                    }
                }
            } catch {
                print("Error: \(error)")
            }
        }
        
        print("\n=== DEBUG COMPLETE ===")
    }
    

    private func generateGroupCode() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in letters.randomElement()! })
    }
    
    
    // MARK: - Internal Structs for Decoding
    private struct RawJoinRequest: Codable {
        let id: String
        let groupId: String
        let userId: String
        let status: String
        let requestedAt: Date
        let reviewedAt: Date?
        let reviewedBy: String?
        
        enum CodingKeys: String, CodingKey {
            case id
            case groupId = "group_id"
            case userId = "user_id"
            case status
            case requestedAt = "requested_at"
            case reviewedAt = "reviewed_at"
            case reviewedBy = "reviewed_by"
        }
    }
}


// MARK: - Storage Management
extension SupabaseManager {
    
    private func getStorageBucket() -> String {
        return "memora-media" // Create this bucket in Supabase Storage
    }
    
    /// Upload an image to Supabase Storage
    func uploadImageToStorage(_ image: UIImage, fileName: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "SupabaseManager", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG"])
        }
        
        let bucket = getStorageBucket()
        let filePath = "images/\(UUID().uuidString)_\(fileName)"
        
        do {
            let _ = try await client.storage
                .from(bucket)
                .upload(
                    path: filePath,
                    file: imageData,
                    options: FileOptions(cacheControl: "3600", contentType: "image/jpeg")
                )
            
            // Get public URL
            let publicURL = try await client.storage
                .from(bucket)
                .getPublicURL(path: filePath)
            
            return publicURL.absoluteString
            
        } catch {
            print("Error uploading image: \(error)")
            throw error
        }
    }
    
    /// Upload an audio file to Supabase Storage
    func uploadAudioToStorage(audioURL: URL, fileName: String) async throws -> String {
        let bucket = getStorageBucket()
        let filePath = "audio/\(UUID().uuidString)_\(fileName)"
        
        do {
            let audioData = try Data(contentsOf: audioURL)
            let fileExtension = audioURL.pathExtension.lowercased()
            let contentType: String
            
            switch fileExtension {
            case "mp3": contentType = "audio/mpeg"
            case "m4a", "mp4": contentType = "audio/mp4"
            case "wav": contentType = "audio/wav"
            default: contentType = "audio/mpeg"
            }
            
            let _ = try await client.storage
                .from(bucket)
                .upload(
                    path: filePath,
                    file: audioData,
                    options: FileOptions(cacheControl: "3600", contentType: contentType)
                )
            
            // Get public URL
            let publicURL = try await client.storage
                .from(bucket)
                .getPublicURL(path: filePath)
            
            return publicURL.absoluteString
            
        } catch {
            print("Error uploading audio: \(error)")
            throw error
        }
    }
    
    /// Upload text content (for text-only memories)
    func uploadTextToStorage(_ text: String, fileName: String) async throws -> String {
        let bucket = getStorageBucket()
        let filePath = "text/\(UUID().uuidString)_\(fileName).txt"
        
        guard let textData = text.data(using: .utf8) else {
            throw NSError(domain: "SupabaseManager", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to encode text"])
        }
        
        do {
            let _ = try await client.storage
                .from(bucket)
                .upload(
                    path: filePath,
                    file: textData,
                    options: FileOptions(cacheControl: "3600", contentType: "text/plain")
                )
            
            let publicURL = try await client.storage
                .from(bucket)
                .getPublicURL(path: filePath)
            
            return publicURL.absoluteString
            
        } catch {
            print("Error uploading text: \(error)")
            throw error
        }
    }
    
    
    func checkSessionStatus() async -> Bool {
        do {
            let session = try await client.auth.session
            self.currentUser = session.user
            print(" Session active for: \(session.user.email ?? "No email")")
            return true
        } catch {
            print(" No active session: \(error)")
            self.currentUser = nil
            return false
        }
    }
}



// MARK: - Memory Creation & Management
extension SupabaseManager {
    
    /// Create a memory in Supabase with media attachments
    func createMemory(
            title: String,
            year: Int? = nil,
            category: String? = nil,
            visibility: MemoryVisibility,
            scheduledDate: Date? = nil,
            images: [UIImage] = [],
            audioFiles: [(url: URL, duration: TimeInterval)] = [],
            textContent: String? = nil
        ) async throws -> SupabaseMemory {
            
            guard let userId = getCurrentUserId() else {
                throw NSError(domain: "SupabaseManager", code: 401,
                              userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            }
            
            guard let userUUID = UUID(uuidString: userId) else {
                throw NSError(domain: "SupabaseManager", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Invalid user ID format"])
            }
            
            // Format the date for Supabase
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            // Step 1: Create the memory record
            let memoryResponse = try await client
                .from("memories")
                .insert([
                    "user_id": AnyJSON.string(userId),
                    "title": AnyJSON.string(title),
                    "year": year.map { AnyJSON.integer($0) } ?? .null,
                    "category": category.map { AnyJSON.string($0) } ?? .null,
                    "visibility": AnyJSON.string(visibility.databaseString), // Fixed: use .databaseString
                    "release_at": scheduledDate.map {
                        AnyJSON.string(dateFormatter.string(from: $0))
                    } ?? .null
                ])
                .select()
                .single()
                .execute()
            
            let memory = try jsonDecoder.decode(SupabaseMemory.self, from: memoryResponse.data)
            print("✅ Memory created with ID: \(memory.id)")
            
            // Step 2: Upload and attach media
            var sortOrder = 0
            
            // Upload images
            for image in images {
                do {
                    let fileName = "image_\(UUID().uuidString).jpg"
                    let mediaUrl = try await uploadImageToStorage(image, fileName: fileName)
                    
                    try await client
                        .from("memory_media")
                        .insert([
                            "memory_id": AnyJSON.string(memory.id.uuidString),
                            "media_url": AnyJSON.string(mediaUrl),
                            "media_type": AnyJSON.string("photo"),
                            "sort_order": AnyJSON.integer(sortOrder)
                        ])
                        .execute()
                    
                    sortOrder += 1
                    print("✅ Image uploaded: \(mediaUrl)")
                    
                } catch {
                    print("⚠️ Failed to upload image: \(error)")
                    // Continue with other uploads
                }
            }
            
            // Upload audio files
            for audioFile in audioFiles {
                do {
                    let fileName = "audio_\(UUID().uuidString).\(audioFile.url.pathExtension)"
                    let mediaUrl = try await uploadAudioToStorage(audioURL: audioFile.url, fileName: fileName)
                    
                    try await client
                        .from("memory_media")
                        .insert([
                            "memory_id": AnyJSON.string(memory.id.uuidString),
                            "media_url": AnyJSON.string(mediaUrl),
                            "media_type": AnyJSON.string("audio"),
                            "sort_order": AnyJSON.integer(sortOrder),
                            "text_content": AnyJSON.string("Audio: \(Int(audioFile.duration)) seconds")
                        ])
                        .execute()
                    
                    sortOrder += 1
                    print("✅ Audio uploaded: \(mediaUrl)")
                    
                } catch {
                    print("⚠️ Failed to upload audio: \(error)")
                    // Continue with other uploads
                }
            }
            
            // Upload text content if provided
            if let text = textContent, !text.isEmpty {
                do {
                    let fileName = "text_\(UUID().uuidString).txt"
                    let mediaUrl = try await uploadTextToStorage(text, fileName: fileName)
                    
                    try await client
                        .from("memory_media")
                        .insert([
                            "memory_id": AnyJSON.string(memory.id.uuidString),
                            "media_url": AnyJSON.string(mediaUrl),
                            "media_type": AnyJSON.string("text"),
                            "sort_order": AnyJSON.integer(sortOrder),
                            "text_content": AnyJSON.string(text)
                        ])
                        .execute()
                    
                    print("✅ Text content uploaded")
                    
                } catch {
                    print("⚠️ Failed to upload text: \(error)")
                }
            }
            
            // Step 3: Also save locally for offline access
            let localAttachments: [MemoryAttachment] = []
            
            MemoryStore.shared.createMemory(
                ownerId: userId,
                title: title,
                body: textContent,
                attachments: localAttachments,
                visibility: visibility,
                scheduledFor: scheduledDate,
                category: category
            ) { result in
                switch result {
                case .success(let localMemory):
                    print("✅ Memory also saved locally: \(localMemory.id)")
                case .failure(let error):
                    print("⚠️ Failed to save memory locally: \(error)")
                }
            }
            
            return memory
        }
    
    /// Share an existing memory with a group
    func shareMemoryWithGroup(memoryId: UUID, groupId: UUID) async throws {
        guard let userId = getCurrentUserId() else {
            throw NSError(domain: "SupabaseManager", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        print("DEBUG: Attempting to share memory \(memoryId) with group \(groupId)")
        print("DEBUG: Current user ID: \(userId)")
        
        // First, verify the user owns the memory
        let memoryCheck = try await client
            .from("memories")
            .select("id, user_id")
            .eq("id", value: memoryId.uuidString)
            .single()
            .execute()
        
        struct MemoryOwnerCheck: Decodable {
            let id: UUID
            let userId: UUID
            
            enum CodingKeys: String, CodingKey {
                case id
                case userId = "user_id"
            }
        }
        
        let memory = try jsonDecoder.decode(MemoryOwnerCheck.self, from: memoryCheck.data)
        
        // Check if current user is the owner
        guard memory.userId.uuidString.lowercased() == userId.lowercased() else {
            print("DEBUG: Permission denied - user \(userId) doesn't own memory \(memory.id)")
            throw NSError(domain: "SupabaseManager", code: 403,
                          userInfo: [NSLocalizedDescriptionKey: "You don't have permission to share this memory"])
        }
        
        print("DEBUG: User owns memory, verifying group membership...")
        
        // Check if user is a member of the group
        let membershipCheck = try await client
            .from("group_members")
            .select("user_id")
            .eq("group_id", value: groupId.uuidString)
            .eq("user_id", value: userId)
            .execute()
        
        if let jsonArray = try? JSONSerialization.jsonObject(with: membershipCheck.data) as? [[String: Any]],
           jsonArray.isEmpty {
            print("DEBUG: User is not a member of group \(groupId)")
            throw NSError(domain: "SupabaseManager", code: 403,
                          userInfo: [NSLocalizedDescriptionKey: "You must be a member of the group to share memories"])
        }
        
        print("DEBUG: User is group member, checking if already shared...")
        
        // Check if already shared with group
        let existingCheck = try await client
            .from("group_memories")
            .select("id")
            .eq("memory_id", value: memoryId.uuidString)
            .eq("group_id", value: groupId.uuidString)
            .execute()
        
        if let jsonArray = try? JSONSerialization.jsonObject(with: existingCheck.data) as? [[String: Any]],
           !jsonArray.isEmpty {
            print("Memory already shared with this group")
            return
        }
        
        // Create group memory link
        print("DEBUG: Creating entry in group_memories...")
        try await client
            .from("group_memories")
            .insert([
                "user_id": AnyJSON.string(userId),
                "group_id": AnyJSON.string(groupId.uuidString),
                "memory_id": AnyJSON.string(memoryId.uuidString)
            ])
            .execute()
        
        print("DEBUG: Created entry in group_memories")
        
        // Now create memory_group_access entry
        print("DEBUG: Creating memory_group_access entry...")
        try await client
            .from("memory_group_access")
            .insert([
                "memory_id": AnyJSON.string(memoryId.uuidString),
                "group_id": AnyJSON.string(groupId.uuidString)
            ])
            .execute()
        
        print("DEBUG: Memory shared with group successfully")
    }
    
    /// Create a memory specifically for a group (group-only memory)
    func createMemoryForGroup(
        groupId: UUID,
        title: String,
        year: Int? = nil,
        category: String? = nil,
        images: [UIImage] = [],
        audioFiles: [(url: URL, duration: TimeInterval)] = [],
        textContent: String? = nil
    ) async throws -> SupabaseMemory {
        
        // Create memory with group visibility
        let memory = try await createMemory(
            title: title,
            year: year,
            category: category,
            visibility: .group, // We'll need to add this to MemoryVisibility
            scheduledDate: nil,
            images: images,
            audioFiles: audioFiles,
            textContent: textContent
        )
        
        // Link to group
        try await shareMemoryWithGroup(memoryId: memory.id, groupId: groupId)
        
        return memory
    }
    
    /// Get memories for a specific group
    func getMemoriesForGroup(groupId: UUID) async throws -> [SupabaseMemory] {
        let response = try await client
            .from("memory_group_access")
            .select("""
                id,
                created_at,
                memories:memories (
                    id,
                    user_id,
                    title,
                    year,
                    category,
                    visibility,
                    release_at,
                    created_at,
                    updated_at,
                    memory_media:memory_media (
                        id,
                        memory_id,       
                        media_url,
                        media_type,
                        text_content,
                        sort_order,
                        created_at 
                    )
                )
            """)
            .eq("group_id", value: groupId.uuidString)
            .order("created_at", ascending: false)
            .execute()
        
        // Parse the response
        struct GroupMemoryAccess: Codable {
            let id: UUID
            let createdAt: Date
            let memories: SupabaseMemory
            
            enum CodingKeys: String, CodingKey {
                case id
                case createdAt = "created_at"
                case memories
            }
        }
        
        let accessList = try jsonDecoder.decode([GroupMemoryAccess].self, from: response.data)
        return accessList.map { $0.memories }
    }
    
    /// Get user's own memories
    func getUserMemories() async throws -> [SupabaseMemory] {
        guard let userId = getCurrentUserId() else {
            return []
        }
        
        let response = try await client
            .from("memories")
            .select("""
                *,
                memory_media (
                    id,
                    memory_id,           
                    media_url,
                    media_type,
                    text_content,
                    sort_order,
                    created_at          
                )
            """)
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
        
        return try jsonDecoder.decode([SupabaseMemory].self, from: response.data)
    }
    
    
}



extension SupabaseManager {
    
    // MARK: - Scheduled Memories
    
    /// Get all scheduled memories for current user
    func getScheduledMemories() async throws -> [ScheduledMemory] {
        guard let userId = getCurrentUserId() else {
            return []
        }
        
        // Use a simpler query that matches your data structure
        let response = try await client
            .from("memories")
            .select("""
                *,
                memory_media (
                    id,
                    memory_id,
                    media_url,
                    media_type,
                    text_content,
                    sort_order,
                    created_at
                )
            """)
            .eq("user_id", value: userId)
            .eq("visibility", value: "scheduled")
            .not("release_at", operator: .is, value: "null")
            .order("release_at", ascending: true)
            .execute()
        
        // First decode as SupabaseMemory array
        let supabaseMemories = try jsonDecoder.decode([SupabaseMemory].self, from: response.data)
        
        // Convert to ScheduledMemory
        return supabaseMemories.compactMap { supabaseMemory in
            guard let releaseAt = supabaseMemory.releaseAt else { return nil }
            
            let previewImageUrl = supabaseMemory.memoryMedia?.first { $0.mediaType == "photo" }?.mediaUrl
            
            return ScheduledMemory(
                id: supabaseMemory.id,
                title: supabaseMemory.title,
                year: supabaseMemory.year,
                category: supabaseMemory.category,
                releaseAt: releaseAt,
                createdAt: supabaseMemory.createdAt,
                userId: supabaseMemory.userId,
                previewImageUrl: previewImageUrl,
                isReadyToOpen: releaseAt <= Date()
            )
        }
    }

    
    /// Open a scheduled memory (change visibility from scheduled to private/everyone)
    func openScheduledMemory(memoryId: UUID) async throws {
        do {
            try await client
                .from("memories")
                .update([
                    "visibility": "private"
                ])
                .eq("id", value: memoryId.uuidString)
                .execute()
            
            print("✅ Memory \(memoryId) opened successfully")
            
        } catch {
            print("Error opening memory: \(error)")
            throw error
        }
    }
    
    /// Check for ready-to-open memories and return them
    func checkForReadyMemories() async throws -> [ScheduledMemory] {
        let allScheduled = try await getScheduledMemories()
        return allScheduled.filter { $0.isReadyToOpen }
    }
    
    /// Schedule a memory for future release

    func scheduleMemory(
        title: String,
        year: Int? = nil,
        category: String? = nil,
        releaseDate: Date,
        images: [UIImage] = [],
        audioFiles: [(url: URL, duration: TimeInterval)] = [],
        textContent: String? = nil
    ) async throws -> ScheduledMemory {
        
        // Create memory with scheduled visibility using the correct case
        let memory = try await createMemory(
            title: title,
            year: year,
            category: category,
            visibility: MemoryVisibility.scheduled,
            scheduledDate: releaseDate,
            images: images,
            audioFiles: audioFiles,
            textContent: textContent
        )
        
        // Convert to ScheduledMemory
        return ScheduledMemory(
            id: memory.id,
            title: memory.title,
            year: memory.year,
            category: memory.category,
            releaseAt: releaseDate,
            createdAt: memory.createdAt,
            userId: memory.userId,
            previewImageUrl: nil, 
            isReadyToOpen: false
        )
    }
    
    
    
    /// Get a specific scheduled memory by ID
    func getScheduledMemory(by id: UUID) async throws -> ScheduledMemory {
        guard let userId = getCurrentUserId() else {
            throw NSError(domain: "SupabaseManager", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        do {
            let response = try await client
                .from("memories")
                .select("""
                    *,
                    memory_media!inner(
                        media_url,
                        media_type
                    )
                """)
                .eq("id", value: id.uuidString)
                .eq("user_id", value: userId)
                .single()
                .execute()
            
            // Parse manually
            guard let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any] else {
                throw NSError(domain: "SupabaseManager", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Could not parse memory data"])
            }
            
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            guard let idString = json["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let userIdString = json["user_id"] as? String,
                  let userId = UUID(uuidString: userIdString),
                  let title = json["title"] as? String,
                  let createdAtString = json["created_at"] as? String,
                  let releaseAtString = json["release_at"] as? String,
                  let createdAt = dateFormatter.date(from: createdAtString),
                  let releaseAt = dateFormatter.date(from: releaseAtString) else {
                throw NSError(domain: "SupabaseManager", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Invalid memory data"])
            }
            
            let year = json["year"] as? Int
            let category = json["category"] as? String
            
            // Extract preview image
            var previewImageUrl: String? = nil
            if let mediaArray = json["memory_media"] as? [[String: Any]] {
                for media in mediaArray {
                    if let mediaType = media["media_type"] as? String,
                       mediaType == "photo",
                       let mediaUrl = media["media_url"] as? String {
                        previewImageUrl = mediaUrl
                        break
                    }
                }
            }
            
            let isReadyToOpen = releaseAt <= Date()
            
            return ScheduledMemory(
                id: id,
                title: title,
                year: year,
                category: category,
                releaseAt: releaseAt,
                createdAt: createdAt,
                userId: userId,
                previewImageUrl: previewImageUrl,
                isReadyToOpen: isReadyToOpen
            )
            
        } catch {
            print("Error fetching scheduled memory: \(error)")
            throw error
        }
    }
    
    /// Get a memory by ID
    func getMemory(by id: UUID) async throws -> SupabaseMemory {
        let response = try await client
            .from("memories")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
        
        return try jsonDecoder.decode(SupabaseMemory.self, from: response.data)
    }
    
    
    /// Delete a memory (only if owned by current user)
    func deleteMemory(memoryId: UUID) async throws {
        guard let userId = getCurrentUserId() else {
            throw NSError(domain: "SupabaseManager", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        print("DEBUG: Attempting to delete memory \(memoryId)")
        print("DEBUG: Current user ID: \(userId)")
        
        // First, verify the user owns this memory
        let memoryCheck = try await client
            .from("memories")
            .select("user_id")
            .eq("id", value: memoryId.uuidString)
            .single()
            .execute()
        
        struct MemoryOwnerCheck: Decodable {
            let userId: UUID
            
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
            }
        }
        
        let memory = try jsonDecoder.decode(MemoryOwnerCheck.self, from: memoryCheck.data)
        
        // Check if current user is the owner
        guard memory.userId.uuidString.lowercased() == userId.lowercased() else {
            print("DEBUG: Permission denied - user \(userId) doesn't own memory \(memoryId)")
            throw NSError(domain: "SupabaseManager", code: 403,
                          userInfo: [NSLocalizedDescriptionKey: "You don't have permission to delete this memory"])
        }
        
        // Delete the memory (cascade should handle memory_media, group_memories, etc.)
        try await client
            .from("memories")
            .delete()
            .eq("id", value: memoryId.uuidString)
            .execute()
        
        print("DEBUG: Memory \(memoryId) deleted successfully")
    }
    
    
    // Add this method to UNshare from a specific group (not delete memory)
    func unshareMemoryFromGroup(memoryId: UUID, groupId: UUID) async throws {
        print("DEBUG: Unsharing memory \(memoryId) from group \(groupId)")
        
        // Remove from group_memories
        try await client
            .from("group_memories")
            .delete()
            .eq("memory_id", value: memoryId.uuidString)
            .eq("group_id", value: groupId.uuidString)
            .execute()
        
        // Remove from memory_group_access
        try await client
            .from("memory_group_access")
            .delete()
            .eq("memory_id", value: memoryId.uuidString)
            .eq("group_id", value: groupId.uuidString)
            .execute()
        
        print("DEBUG: Memory unshared from group")
    }

    // Add this method to share with multiple groups
    func shareMemoryWithGroups(memoryId: UUID, groupIds: [UUID]) async throws {
        for groupId in groupIds {
            try await shareMemoryWithGroup(memoryId: memoryId, groupId: groupId)
        }
    }

    // Add this method to get groups this memory is already shared with
    func getGroupsForMemory(memoryId: UUID) async throws -> [UserGroup] {
        let response = try await client
            .from("group_memories")
            .select("""
                groups!inner (
                    id,
                    name,
                    code,
                    created_by,
                    admin_id,
                    created_at
                )
            """)
            .eq("memory_id", value: memoryId.uuidString)
            .execute()
        
        struct GroupMemoryResponse: Decodable {
            let groups: UserGroup
        }
        
        let responses = try jsonDecoder.decode([GroupMemoryResponse].self, from: response.data)
        return responses.map { $0.groups }
    }
}


extension SupabaseManager {
    
    /// Schedule a memory for groups
    // In SupabaseManager extension - Update the existing scheduleMemoryForGroups method
    func scheduleMemoryForGroups(
        title: String,
        year: Int? = nil,
        category: String? = nil,
        releaseDate: Date,
        groupIds: [UUID],
        images: [UIImage] = [],
        audioFiles: [(url: URL, duration: TimeInterval)] = [],
        textContent: String? = nil
    ) async throws -> ScheduledMemory {
        
        guard let userId = getCurrentUserId() else {
            throw NSError(domain: "SupabaseManager", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // First, create the scheduled memory
        let scheduledMemory = try await scheduleMemory(
            title: title,
            year: year,
            category: category,
            releaseDate: releaseDate,
            images: images,
            audioFiles: audioFiles,
            textContent: textContent
        )
        
        print("DEBUG: Memory scheduled, now linking to \(groupIds.count) groups")
        
        // Create entries in scheduled_memory_groups table for each group
        for groupId in groupIds {
            do {
                let data: [String: AnyJSON] = [
                    "memory_id": .string(scheduledMemory.id.uuidString),
                    "group_id": .string(groupId.uuidString),
                    "is_opened": .bool(false),
                    "scheduled_at": .string(Date().ISO8601Format())
                ]
                
                try await client
                    .from("scheduled_memory_groups")
                    .insert(data)
                    .execute()
                
                print("DEBUG: Linked memory \(scheduledMemory.id) to group \(groupId)")
                
                // Also share with the group (for visibility in group_memories table)
                try await shareMemoryWithGroup(memoryId: scheduledMemory.id, groupId: groupId)
                
            } catch {
                print("DEBUG: Error linking to group \(groupId): \(error)")
                // Continue with other groups even if one fails
            }
        }
        
        print("DEBUG: Successfully scheduled memory for \(groupIds.count) groups")
        return scheduledMemory
    }
    
    /// Create scheduled memory group entry
    private func createScheduledMemoryGroup(memoryId: UUID, groupId: UUID) async throws {
        let data: [String: AnyJSON] = [
            "memory_id": .string(memoryId.uuidString),
            "group_id": .string(groupId.uuidString),
            "is_opened": .bool(false)
        ]
        
        try await client
            .from("scheduled_memory_groups")
            .insert(data)
            .execute()
    }
    
    /// Get group-scheduled memories for a specific group
    // Fix this method - it has incorrect column names
    func getGroupScheduledMemories(groupId: UUID) async throws -> [ScheduledMemoryWithGroups] {
        let response = try await client
            .from("scheduled_memory_groups")
            .select("""
                *,
                memories!inner (
                    *,
                    memory_media (*),
                    profiles!inner (name)
                ),
                groups!inner (*)
            """)
            .eq("group_id", value: groupId.uuidString)
            .eq("is_opened", value: false)
            .order("scheduled_at", ascending: true) // This is the correct column name
            .execute()
        
        print("DEBUG: Group scheduled memories response: \(String(data: response.data, encoding: .utf8) ?? "")")
        
        // First, parse manually to debug
        guard let jsonArray = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] else {
            print("DEBUG: Could not parse scheduled_memory_groups response")
            return []
        }
        
        print("DEBUG: Found \(jsonArray.count) scheduled group entries")
        
        var scheduledMemories: [ScheduledMemoryWithGroups] = []
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        for item in jsonArray {
            // Parse scheduled_memory_groups entry
            guard let id = item["id"] as? String,
                  let idUUID = UUID(uuidString: id),
                  let memoryId = item["memory_id"] as? String,
                  let memoryUUID = UUID(uuidString: memoryId),
                  let groupId = item["group_id"] as? String,
                  let groupUUID = UUID(uuidString: groupId),
                  let scheduledAtString = item["scheduled_at"] as? String,
                  let scheduledAt = dateFormatter.date(from: scheduledAtString),
                  let isOpened = item["is_opened"] as? Bool,
                  let memoriesDict = item["memories"] as? [String: Any],
                  let groupsDict = item["groups"] as? [String: Any] else {
                print("DEBUG: Skipping invalid scheduled memory group entry")
                continue
            }
            
            // Parse memory data
            guard let memoryTitle = memoriesDict["title"] as? String,
                  let memoryUserId = memoriesDict["user_id"] as? String,
                  let memoryUserUUID = UUID(uuidString: memoryUserId),
                  let memoryCreatedAtString = memoriesDict["created_at"] as? String,
                  let memoryCreatedAt = dateFormatter.date(from: memoryCreatedAtString),
                  let releaseAtString = memoriesDict["release_at"] as? String,
                  let releaseAt = dateFormatter.date(from: releaseAtString) else {
                print("DEBUG: Skipping memory - missing required fields")
                continue
            }
            
            let memoryYear = memoriesDict["year"] as? Int
            let memoryCategory = memoriesDict["category"] as? String
            
            // Parse memory media
            var media: [SupabaseMemoryMedia] = []
            if let mediaArray = memoriesDict["memory_media"] as? [[String: Any]] {
                for mediaItem in mediaArray {
                    guard let mediaId = mediaItem["id"] as? String,
                          let mediaUUID = UUID(uuidString: mediaId),
                          let mediaUrl = mediaItem["media_url"] as? String,
                          let mediaType = mediaItem["media_type"] as? String else {
                        continue
                    }
                    
                    let textContent = mediaItem["text_content"] as? String
                    let sortOrder = mediaItem["sort_order"] as? Int ?? 0
                    let mediaCreatedAtString = mediaItem["created_at"] as? String ?? ""
                    let mediaCreatedAt = dateFormatter.date(from: mediaCreatedAtString) ?? Date()
                    
                    let memoryMedia = SupabaseMemoryMedia(
                        id: mediaUUID,
                        memoryId: memoryUUID,
                        mediaUrl: mediaUrl,
                        mediaType: mediaType,
                        textContent: textContent,
                        sortOrder: sortOrder,
                        createdAt: mediaCreatedAt
                    )
                    media.append(memoryMedia)
                }
            }
            
            // Parse group data
            guard let groupName = groupsDict["name"] as? String,
                  let groupCode = groupsDict["code"] as? String,
                  let groupCreatedBy = groupsDict["created_by"] as? String,
                  let groupAdminId = groupsDict["admin_id"] as? String,
                  let groupCreatedAtString = groupsDict["created_at"] as? String,
                  let groupCreatedAt = dateFormatter.date(from: groupCreatedAtString) else {
                print("DEBUG: Skipping group - missing required fields")
                continue
            }
            
            let group = UserGroup(
                id: groupUUID.uuidString,
                name: groupName,
                code: groupCode,
                createdBy: groupCreatedBy,
                adminId: groupAdminId,
                createdAt: groupCreatedAt
            )
            
            // Parse creator info
            var creatorName = "Unknown User"
            if let profilesDict = memoriesDict["profiles"] as? [String: Any],
               let name = profilesDict["name"] as? String {
                creatorName = name
            }
            
            // Create SupabaseMemory
            let supabaseMemory = SupabaseMemory(
                id: memoryUUID,
                userId: memoryUserUUID,
                title: memoryTitle,
                year: memoryYear,
                category: memoryCategory,
                visibility: "scheduled",
                releaseAt: releaseAt,
                createdAt: memoryCreatedAt,
                updatedAt: memoryCreatedAt,
                memoryMedia: media
            )
            
            // Create ScheduledMemoryGroup
            let scheduledMemoryGroup = ScheduledMemoryGroup(
                id: idUUID,
                memoryId: memoryUUID,
                groupId: groupUUID,
                scheduledAt: scheduledAt,
                isOpened: isOpened,
                openedAt: nil,
                memory: supabaseMemory,
                group: group
            )
            
            // Create ScheduledMemory
            let previewImageUrl = media.first { $0.mediaType == "photo" }?.mediaUrl
            
            let scheduledMemory = ScheduledMemory(
                id: memoryUUID,
                title: memoryTitle,
                year: memoryYear,
                category: memoryCategory,
                releaseAt: releaseAt,
                createdAt: memoryCreatedAt,
                userId: memoryUserUUID,
                previewImageUrl: previewImageUrl,
                isReadyToOpen: releaseAt <= Date()
            )
            
            let scheduledMemoryWithGroups = ScheduledMemoryWithGroups(
                scheduledMemory: scheduledMemoryGroup,
                memoryDetails: supabaseMemory,
                media: media,
                scheduledForGroups: [group]
            )
            
            scheduledMemories.append(scheduledMemoryWithGroups)
        }
        
        print("DEBUG: Successfully parsed \(scheduledMemories.count) scheduled memories")
        return scheduledMemories
    }
    
    /// Open a group-scheduled memory
    // Update the openGroupScheduledMemory method
    func openGroupScheduledMemory(memoryId: UUID, groupId: UUID) async throws {
        print("DEBUG: Opening scheduled memory \(memoryId) for group \(groupId)")
        
        // Get current date as ISO8601 string
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let currentDateString = dateFormatter.string(from: Date())
        
        // Update scheduled_memory_groups table
        try await client
            .from("scheduled_memory_groups")
            .update([
                "is_opened": AnyJSON.bool(true),
                "opened_at": AnyJSON.string(currentDateString)
            ])
            .eq("memory_id", value: memoryId.uuidString)
            .eq("group_id", value: groupId.uuidString)
            .execute()
        
        print("DEBUG: Marked as opened in scheduled_memory_groups")
        
        // Update memory visibility from scheduled to private
        try await client
            .from("memories")
            .update([
                "visibility": AnyJSON.string("private")
            ])
            .eq("id", value: memoryId.uuidString)
            .execute()
        
        print("DEBUG: Updated memory visibility to private")
        
        // Ensure it's shared with the group (if not already)
        try await shareMemoryWithGroup(memoryId: memoryId, groupId: groupId)
        
        print("DEBUG: Memory shared with group for immediate viewing")
    }
    
    /// Get all scheduled memories visible to current user across all groups
    func getAllScheduledMemoriesForUser() async throws -> [ScheduledMemoryWithGroups] {
        guard let userId = getCurrentUserId() else {
            return []
        }
        
        // Get all groups user belongs to
        let userGroups = try await getMyGroups()
        var allScheduled: [ScheduledMemoryWithGroups] = []
        
        for group in userGroups {
            if let groupId = UUID(uuidString: group.id) {
                let groupScheduled = try await getGroupScheduledMemories(groupId: groupId)
                allScheduled.append(contentsOf: groupScheduled)
            }
        }
        
        return allScheduled.sorted { $0.memoryDetails.releaseAt ?? Date() < $1.memoryDetails.releaseAt ?? Date() }
    }
    
    // Add this simpler method to SupabaseManager
    func getScheduledMemoriesForGroup(groupId: UUID) async throws -> [ScheduledMemory] {
        print("DEBUG: Fetching scheduled memories for group \(groupId)")
        
        // First, get memory IDs from scheduled_memory_groups table
        let scheduledResponse = try await client
            .from("scheduled_memory_groups")
            .select("memory_id")
            .eq("group_id", value: groupId.uuidString)
            .eq("is_opened", value: false)
            .order("scheduled_at", ascending: true)
            .execute()
        
        // Parse memory IDs
        guard let jsonArray = try? JSONSerialization.jsonObject(with: scheduledResponse.data) as? [[String: Any]] else {
            print("DEBUG: Could not parse scheduled_memory_groups response")
            return []
        }
        
        let memoryIds = jsonArray.compactMap { $0["memory_id"] as? String }
        print("DEBUG: Found \(memoryIds.count) scheduled memory IDs")
        
        if memoryIds.isEmpty {
            return []
        }
        
        // Get the actual memories
        let memoriesResponse = try await client
            .from("memories")
            .select("""
                *,
                memory_media (
                    id,
                    memory_id,
                    media_url,
                    media_type,
                    text_content,
                    sort_order,
                    created_at
                )
            """)
            .in("id", values: memoryIds)
            .order("release_at", ascending: true)
            .execute()
        
        // Parse and convert to ScheduledMemory
        let supabaseMemories = try jsonDecoder.decode([SupabaseMemory].self, from: memoriesResponse.data)
        
        return supabaseMemories.compactMap { supabaseMemory in
            guard let releaseAt = supabaseMemory.releaseAt else { return nil }
            
            let previewImageUrl = supabaseMemory.memoryMedia?.first { $0.mediaType == "photo" }?.mediaUrl
            
            return ScheduledMemory(
                id: supabaseMemory.id,
                title: supabaseMemory.title,
                year: supabaseMemory.year,
                category: supabaseMemory.category,
                releaseAt: releaseAt,
                createdAt: supabaseMemory.createdAt,
                userId: supabaseMemory.userId,
                previewImageUrl: previewImageUrl,
                isReadyToOpen: releaseAt <= Date()
            )
        }
    }
    
    func getMemoryCreatorInfo(memoryId: UUID) async throws -> (name: String, userId: UUID) {
        let response = try await client
            .from("memories")
            .select("""
                user_id,
                profiles!inner(name)
            """)
            .eq("id", value: memoryId.uuidString)
            .single()
            .execute()
        
        // Parse manually
        guard let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
              let userIdString = json["user_id"] as? String,
              let userId = UUID(uuidString: userIdString),
              let profiles = json["profiles"] as? [String: Any],
              let userName = profiles["name"] as? String else {
            throw NSError(domain: "SupabaseManager", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Could not parse creator info"])
        }
        
        return (name: userName, userId: userId)
    }
}


