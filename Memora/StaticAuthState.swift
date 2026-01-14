//
//  AuthState.swift
//  Memora
//
//  Created by user@3 on 14/01/26.
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
        isAuthenticated = StaticDataManager.shared.isUserLoggedIn()
        
        if isAuthenticated {
            Task {
                await loadUserProfile()
            }
        }
    }
    
    func loadUserProfile() async {
        do {
            userProfile = try await StaticDataManager.shared.getUserProfile()
        } catch {
            print("Failed to load user profile: \(error)")
        }
    }
    
    func signUp(name: String, email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            try await StaticDataManager.shared.signUp(name: name, email: email, password: password)
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
            try await StaticDataManager.shared.signIn(email: email, password: password)
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
            try await StaticDataManager.shared.signOut()
            isAuthenticated = false
            userProfile = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            print("Sign out error: \(error)")
        }
    }
    
    // Helper function for quick demo login
    func demoLogin() async -> Bool {
        return await signIn(email: "john@example.com", password: "password123")
    }
}
