import SwiftUI

struct TreatmentFoodTimerView: View {
    @ObservedObject var appData: AppData
    @State private var timerDurationInMinutes: Double // Local state for slider in minutes
    
    init(appData: AppData) {
        self.appData = appData
        _timerDurationInMinutes = State(initialValue: appData.treatmentTimerDuration / 60.0) // Initialize from seconds to minutes
    }
    
    var body: some View {
        Form {
            Section(header: Text("Treatment Food Timer")) {
                Toggle("Enable Timer", isOn: $appData.treatmentFoodTimerEnabled)
                    .onChange(of: appData.treatmentFoodTimerEnabled) { _, newValue in
                        if !newValue {
                            cancelAllTreatmentTimers()
                        }
                    }
                
                Slider(
                    value: $timerDurationInMinutes,
                    in: 1...30, // Range: 1 to 30 minutes
                    step: 1, // Step by 1 minute
                    minimumValueLabel: Text("1 min"),
                    maximumValueLabel: Text("30 min")
                ) {
                    Text("Duration")
                }
                .disabled(!appData.treatmentFoodTimerEnabled) // Disable slider if timer is off
                .onChange(of: timerDurationInMinutes) { newValue in
                    let durationInSeconds = newValue * 60.0
                    appData.treatmentTimerDuration = durationInSeconds
                    print("Slider set duration to: \(durationInSeconds) seconds")
                }
                
                Text("Current Duration: \(Int(timerDurationInMinutes)) minutes")
                    .foregroundColor(.gray)
                
                Text("15 minutes is the recommended time between treatment doses.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Text("When enabled, a notification will be sent after the set duration following each Treatment Food logged, until all are logged for the day.")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .navigationTitle("Treatment Food Timer")
    }
    
    func cancelAllTreatmentTimers() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

struct TreatmentFoodTimerView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TreatmentFoodTimerView(appData: AppData())
        }
    }
}
