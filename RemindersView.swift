import SwiftUI
import UserNotifications

struct RemindersView: View {
    @ObservedObject var appData: AppData
    
    var body: some View {
        Form {
            Section {
                Text("Set daily reminders for each category. If items in a category are not logged by the selected time, a notification will be sent.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            ForEach(Category.allCases, id: \.self) { category in
                Section(header: Text(category.rawValue)) {
                    Toggle("Daily Reminder", isOn: Binding(
                        get: { appData.remindersEnabled[category] ?? false },
                        set: { newValue in
                            appData.remindersEnabled[category] = newValue
                            if newValue {
                                scheduleReminder(for: category)
                            } else {
                                cancelReminder(for: category)
                            }
                        }
                    ))
                    if appData.remindersEnabled[category] ?? false {
                        DatePicker("Time", selection: Binding(
                            get: { appData.reminderTimes[category] ?? Date() },
                            set: { newValue in
                                appData.reminderTimes[category] = newValue
                                if appData.remindersEnabled[category] ?? false {
                                    scheduleReminder(for: category)
                                }
                            }
                        ), displayedComponents: .hourAndMinute)
                    }
                }
            }
        }
        .navigationTitle("Reminders")
        .onAppear {
            requestNotificationPermission()
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Error requesting notification permission: \(error)")
            }
        }
    }
    
    func scheduleReminder(for category: Category) {
        guard let time = appData.reminderTimes[category] else { return }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        
        let content = UNMutableNotificationContent()
        content.title = "Reminder: \(category.rawValue)"
        content.body = "Have you consumed all items in \(category.rawValue) yet?"
        content.sound = .default
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: "\(category.rawValue)_daily",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling reminder: \(error)")
            }
        }
    }
    
    func cancelReminder(for category: Category) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["\(category.rawValue)_daily"])
    }
}

struct RemindersView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            RemindersView(appData: AppData())
        }
    }
}
