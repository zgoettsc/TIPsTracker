import SwiftUI

struct NewCycleSetupView: View {
    @ObservedObject var appData: AppData
    @Environment(\.dismiss) var dismiss
    @Binding var isNewCycleSetupActive: Bool
    @State private var step = 1
    @State private var cycleNumber: Int
    @State private var startDate: Date
    @State private var foodChallengeDate: Date
    @State private var patientName: String
    @State private var userName: String
    @State private var newCycleId: UUID? // Track the new cycle ID
    
    init(appData: AppData, isNewCycleSetupActive: Binding<Bool>) {
        self.appData = appData
        self._isNewCycleSetupActive = isNewCycleSetupActive
        if let lastCycle = appData.cycles.last {
            self._cycleNumber = State(initialValue: lastCycle.number + 1)
            self._startDate = State(initialValue: lastCycle.foodChallengeDate.addingTimeInterval(3 * 24 * 3600))
            self._foodChallengeDate = State(initialValue: Calendar.current.date(byAdding: .weekOfYear, value: 12, to: lastCycle.foodChallengeDate.addingTimeInterval(3 * 24 * 3600))!)
            self._patientName = State(initialValue: lastCycle.patientName)
        } else {
            self._cycleNumber = State(initialValue: 1)
            self._startDate = State(initialValue: Date())
            self._foodChallengeDate = State(initialValue: Calendar.current.date(byAdding: .weekOfYear, value: 12, to: Date())!)
            self._patientName = State(initialValue: "")
        }
        self._userName = State(initialValue: appData.currentUser?.name ?? "")
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if step == 1 {
                    Form {
                        TextField("Your Name", text: $userName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(true)
                        TextField("Patient Name", text: $patientName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Picker("Cycle Number", selection: $cycleNumber) {
                            ForEach(1...25, id: \.self) { number in
                                Text("\(number)").tag(number)
                            }
                        }
                        DatePicker("Cycle Dosing Start Date", selection: $startDate, displayedComponents: .date)
                        DatePicker("Food Challenge Date", selection: $foodChallengeDate, displayedComponents: .date)
                    }
                } else if step == 2 {
                    EditItemsView(appData: appData, cycleId: newCycleId ?? UUID())
                } else if step == 3 {
                    RemindersView(appData: appData)
                } else if step == 4 {
                    TreatmentFoodTimerView(appData: appData)
                }
            }
            .navigationTitle(getNavigationTitle())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if step > 1 {
                        Button("Previous") {
                            step -= 1
                        }
                    } else if step == 1 {
                        Button("Cancel") {
                            isNewCycleSetupActive = false
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(getNextButtonTitle()) {
                        if step == 1 {
                            let effectivePatientName = patientName.isEmpty ? "Unnamed" : patientName
                            let newCycle = Cycle(
                                id: UUID(),
                                number: cycleNumber,
                                patientName: effectivePatientName,
                                startDate: startDate,
                                foodChallengeDate: foodChallengeDate
                            )
                            newCycleId = newCycle.id
                            let previousCycleId = appData.cycles.last?.id
                            appData.addCycle(newCycle, copyItemsFromCycleId: previousCycleId)
                            step = 2
                        } else if step == 4 {
                            isNewCycleSetupActive = false
                            dismiss()
                        } else {
                            step += 1
                        }
                    }
                }
            }
        }
    }
    
    private func getNavigationTitle() -> String {
        switch step {
        case 1: return "Setup New Cycle"
        case 2: return "Edit Items"
        case 3: return "Reminders"
        case 4: return "Treatment Timer"
        default: return "Setup"
        }
    }
    
    private func getNextButtonTitle() -> String {
        return step == 4 ? "Finish" : "Next"
    }
}

struct NewCycleSetupView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NewCycleSetupView(appData: AppData(), isNewCycleSetupActive: .constant(true))
        }
    }
}
