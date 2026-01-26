//
//  AuthState.swift
//  Memora
//
//  Created by user@3 on 20/01/26.
//



import Foundation
import Combine

@MainActor
class AuthState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userProfile: UserProfile?
    
    static let shared = AuthState()
    
    private init() {
        checkAuthStatus()
    }
    
    func checkAuthStatus() {
        isAuthenticated = SupabaseManager.shared.isUserLoggedIn()
        
        if isAuthenticated {
            Task {
                await loadUserProfile()
            }
        }
    }
    
    func loadUserProfile() async {
        do {
            userProfile = try await SupabaseManager.shared.getUserProfile()
        } catch {
            print("Failed to load user profile: \(error)")
        }
    }
    
    func signUp(name: String, email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            // 1. Create auth account
            try await SupabaseManager.shared.signUp(name: name, email: email, password: password)
            
            // 2. Sign in to get session
            try await SupabaseManager.shared.signIn(email: email, password: password)
            
            // 3. Get the user ID
            guard let userId = SupabaseManager.shared.getCurrentUserId() else {
                errorMessage = "Failed to get user ID"
                return false
            }
            
            // 4. Create profile with userId
            try await SupabaseManager.shared.createUserProfile(userId: userId, name: name, email: email)
            
            // 5. Update state
            isAuthenticated = true
            await loadUserProfile()
            
            return true
        } catch {
            errorMessage = error.localizedDescription
            print("Sign up error: \(error)")
            return false
        }
    }
    
    func signIn(email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            try await SupabaseManager.shared.signIn(email: email, password: password)
            isAuthenticated = true
            await loadUserProfile()
            return true
        } catch {
            errorMessage = error.localizedDescription
            print("Sign in error: \(error)")
            return false
        }
    }
    
    func signOut() async {
        do {
            try await SupabaseManager.shared.signOut()
            isAuthenticated = false
            userProfile = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            print("Sign out error: \(error)")
        }
    }
}
