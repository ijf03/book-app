import Foundation
import Observation
import SwiftUI
import UserNotifications
import UIKit

struct ReadingReminderPreferences: Codable, Equatable {
    var isEnabled = false
    var hour = 20
    var minute = 0
    var isValid: Bool { (0...23).contains(hour) && (0...59).contains(minute) }
}

enum ReminderPermission { case notDetermined, allowed, denied }

@MainActor protocol ReadingNotificationScheduling {
    func permission() async -> ReminderPermission
    func requestPermission() async throws -> Bool
    func schedule(hour: Int, minute: Int) async throws
    func cancel()
}

@MainActor final class LocalReadingNotificationService: ReadingNotificationScheduling {
    static let identifier = "daily-reading-reminder"
    private let center = UNUserNotificationCenter.current()
    func permission() async -> ReminderPermission {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .allowed
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }
    func requestPermission() async throws -> Bool { try await center.requestAuthorization(options: [.alert, .sound]) }
    static func request(hour: Int, minute: Int) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Time to read"
        content.body = "Take a little time for your next chapter."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: minute), repeats: true)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }
    func schedule(hour: Int, minute: Int) async throws {
        // Adding the same identifier replaces the old pending request.
        try await center.add(Self.request(hour: hour, minute: minute))
    }
    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.identifier])
    }
}

@MainActor @Observable final class ReadingRemindersViewModel {
    private(set) var preferences = ReadingReminderPreferences()
    private(set) var isSaving = false
    private(set) var permissionDenied = false
    private(set) var canSave = true
    var errorMessage: String?
    private let repository: LocalJSONRepository<ReadingReminderPreferences>
    private let notifications: any ReadingNotificationScheduling
    init(repository: LocalJSONRepository<ReadingReminderPreferences> = .init(fileName: "reading-reminders.json"), notifications: (any ReadingNotificationScheduling)? = nil) {
        self.repository = repository; self.notifications = notifications ?? LocalReadingNotificationService()
        do {
            let loaded = try repository.load(default: ReadingReminderPreferences())
            guard loaded.isValid else { throw CocoaError(.coderReadCorrupt) }
            preferences = loaded
        } catch { canSave = false; errorMessage = "Your reminder preferences couldn’t be loaded. The saved file has been preserved." }
    }
    func reconcile() async {
        guard canSave, !isSaving else { return }
        isSaving = true; defer { isSaving = false }
        let permission = await notifications.permission()
        permissionDenied = permission == .denied
        do {
            if preferences.isEnabled && permission == .allowed { try await notifications.schedule(hour: preferences.hour, minute: preferences.minute) }
            else { notifications.cancel() }
        } catch { errorMessage = "Your reminder couldn’t be scheduled. Please try saving it again." }
    }
    @discardableResult func update(enabled: Bool, hour: Int, minute: Int) async -> Bool {
        let updated = ReadingReminderPreferences(isEnabled: enabled, hour: hour, minute: minute)
        guard canSave, updated.isValid, !isSaving else { return false }
        isSaving = true; defer { isSaving = false }
        let previous = preferences
        do {
            if enabled {
                var permission = await notifications.permission()
                if permission == .notDetermined { permission = try await notifications.requestPermission() ? .allowed : .denied }
                permissionDenied = permission == .denied
                guard permission == .allowed else {
                    notifications.cancel()
                    errorMessage = "Notifications are disabled for this app. Open System Settings to allow reading reminders."
                    return false
                }
                try await notifications.schedule(hour: hour, minute: minute)
            } else { notifications.cancel() }
            do { try repository.save(updated) }
            catch {
                let permission = await notifications.permission()
                if previous.isEnabled && permission == .allowed { try await notifications.schedule(hour: previous.hour, minute: previous.minute) }
                else { notifications.cancel() }
                throw error
            }
            preferences = updated; errorMessage = nil
            return true
        } catch {
            errorMessage = "Your reminder changes couldn’t be saved. Check notification settings and try again."
            return false
        }
    }
}

struct ReadingRemindersSettingsView: View {
    @State private var model = ReadingRemindersViewModel()
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    private var time: Date {
        Calendar.current.date(bySettingHour: model.preferences.hour, minute: model.preferences.minute, second: 0, of: Date()) ?? Date()
    }
    var body: some View {
        Form {
            Section("Daily Reading Reminder") {
                Toggle("Enable Reminders", isOn: Binding(get: { model.preferences.isEnabled && !model.permissionDenied }, set: { value in
                    Task { await model.update(enabled: value, hour: model.preferences.hour, minute: model.preferences.minute) }
                })).tint(Color.appAccent)
                DatePicker("Reminder Time", selection: Binding(get: { time }, set: { value in
                    let parts = Calendar.current.dateComponents([.hour, .minute], from: value)
                    Task { await model.update(enabled: model.preferences.isEnabled, hour: parts.hour ?? 20, minute: parts.minute ?? 0) }
                }), displayedComponents: .hourAndMinute)
                Text("A daily local notification at your chosen time. Your device’s Focus and notification settings can affect delivery.")
                    .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
            }.disabled(model.isSaving || !model.canSave)
            if model.isSaving { SwiftUI.ProgressView("Updating reminder…") }
            if model.permissionDenied {
                Section {
                    Text("Notifications are disabled. Allow notifications for this app in System Settings, then enable your reminder.")
                        .font(AppTypography.body)
                    Button("Open System Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } }
                }
            }
        }
        .scrollContentBackground(.hidden).background(Color.surfaceSecondary)
        .navigationTitle("Reading Reminders").navigationBarTitleDisplayMode(.inline)
        .task { await model.reconcile() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await model.reconcile() } } }
        .alert("Reading Reminders", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(model.errorMessage ?? "Please try again.") }
    }
}
