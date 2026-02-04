//
//  NotificationsManager.swift
//  Memora
//
//  Created by user@3 on 03/02/26.
//


// NotificationsManager.swift
import UserNotifications
import UIKit

class NotificationsManager: NSObject {
    static let shared = NotificationsManager()
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestPermissions() {
        let center = UNUserNotificationCenter.current()
        
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification permissions: \(error)")
            }
            
            if granted {
                print("Notification permissions granted")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                
                self.setupNotificationCategories()
            }
        }
    }
    
    private func setupNotificationCategories() {
        let center = UNUserNotificationCenter.current()
        
        let openAction = UNNotificationAction(
            identifier: "OPEN_MEMORY_ACTION",
            title: "Open Now",
            options: [.foreground]
        )
        
        let remindLaterAction = UNNotificationAction(
            identifier: "REMIND_LATER_ACTION",
            title: "Remind in 1 hour",
            options: []
        )
        
        let memoryCategory = UNNotificationCategory(
            identifier: "MEMORY_CAPSULE",
            actions: [openAction, remindLaterAction],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([memoryCategory])
    }
    
    func scheduleMemoryReadyNotification(for memory: ScheduledMemory) {
        let center = UNUserNotificationCenter.current()
        
        // Remove any existing notification for this memory
        center.removePendingNotificationRequests(withIdentifiers: ["capsule_ready_\(memory.id.uuidString)"])
        
        // Only schedule if memory is not ready yet
        guard !memory.isReadyToOpen else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Memory Capsule Ready! 🎁"
        content.body = "Your memory '\(memory.title)' is ready to open!"
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "MEMORY_CAPSULE"
        content.userInfo = ["memoryId": memory.id.uuidString, "memoryTitle": memory.title]
        
        // Schedule notification for when memory is ready
        let triggerDate = memory.releaseAt
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "capsule_ready_\(memory.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                print("Scheduled notification for memory: \(memory.title) at \(triggerDate)")
            }
        }
    }
    
    func cancelMemoryNotification(memoryId: UUID) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["capsule_ready_\(memoryId.uuidString)"])
    }
    
    func scheduleAllScheduledMemories() {
        // Load and schedule notifications for all scheduled memories
        Task {
            do {
                let memories = try await SupabaseManager.shared.getScheduledMemories()
                for memory in memories {
                    scheduleMemoryReadyNotification(for: memory)
                }
                print("Scheduled notifications for \(memories.count) memories")
            } catch {
                print("Error loading scheduled memories for notifications: \(error)")
            }
        }
    }
    
    func handleNotificationAction(identifier: String, userInfo: [AnyHashable: Any]) {
        guard identifier == "OPEN_MEMORY_ACTION",
              let memoryIdString = userInfo["memoryId"] as? String,
              let memoryId = UUID(uuidString: memoryIdString),
              let memoryTitle = userInfo["memoryTitle"] as? String else {
            return
        }
        
        // Open the memory in the app
        DispatchQueue.main.async {
            self.navigateToMemory(memoryId: memoryId, title: memoryTitle)
        }
    }
    
    private func navigateToMemory(memoryId: UUID, title: String) {
        // Find the main window
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        // Navigate to MemoryViewController
        if let tabBarController = rootViewController as? UITabBarController {
            tabBarController.selectedIndex = 0 // Assuming memories tab is first
            
            // If we're in MemoryViewController, show the memory
            if let navController = tabBarController.selectedViewController as? UINavigationController,
               let memoryVC = navController.topViewController as? MemoryViewController {
                // Find and open the memory
                memoryVC.openMemoryFromNotification(memoryId: memoryId)
            }
        }
    }
}

extension NotificationsManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            // User tapped the notification (not an action button)
            handleNotificationAction(identifier: "OPEN_MEMORY_ACTION", userInfo: userInfo)
        } else if response.actionIdentifier == "REMIND_LATER_ACTION" {
            // User tapped "Remind later" - schedule for 1 hour later
            if let memoryIdString = userInfo["memoryId"] as? String,
               let memoryId = UUID(uuidString: memoryIdString) {
                scheduleReminderForLater(memoryId: memoryId)
            }
        } else {
            handleNotificationAction(identifier: response.actionIdentifier, userInfo: userInfo)
        }
        
        completionHandler()
    }
    
    private func scheduleReminderForLater(memoryId: UUID) {
        let center = UNUserNotificationCenter.current()
        
        // Get the original notification
        center.getPendingNotificationRequests { requests in
            guard let originalRequest = requests.first(where: { $0.identifier == "capsule_ready_\(memoryId.uuidString)" }) else {
                return
            }
            
            let content = originalRequest.content.mutableCopy() as! UNMutableNotificationContent
            content.title = "Reminder: Memory Capsule Ready! 🎁"
            
            // Schedule for 1 hour later
            let oneHourLater = Date().addingTimeInterval(3600)
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: oneHourLater)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            
            let request = UNNotificationRequest(
                identifier: "capsule_reminder_\(memoryId.uuidString)_\(Date().timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )
            
            center.add(request) { error in
                if let error = error {
                    print("Error scheduling reminder: \(error)")
                }
            }
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
}
