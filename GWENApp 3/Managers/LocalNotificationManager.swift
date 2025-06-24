//
//  LocalNotificationManager.swift
//  GWENApplicationXCODE
//
//  Created by Luis Velasco on 6/14/25.
//

import Foundation
import UserNotifications

class LocalNotificationManager {
    static let shared = LocalNotificationManager()
    
    private init() {}

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            print("Notification permission granted: \(granted)")
        } catch {
            print("Failed to request notification permission: \(error)")
        }
    }

    func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}

