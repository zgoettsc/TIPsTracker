import SwiftUI

struct EditCycleView: View {
    @ObservedObject var appData: AppData
    @Environment(\.dismiss) var dismiss
    @State private var cycleNumber: Int
    @State private var startDate: Date
    @State private var foodChallengeDate: Date
    @State private var patientName: String
    let cycle: Cycle // The cycle to edit
    
    init(appData: AppData, cycle: Cycle) {
        self.appData = appData
        self.cycle = cycle
        self._cycleNumber = State(initialValue: cycle.number)
        self._startDate = State(initialValue: cycle.startDate)
        self._foodChallengeDate = State(initialValue: cycle.foodChallengeDate)
        self._patientName = State(initialValue: cycle.patientName)
    }
    
    var body: some View {
        Form {
            Picker("Cycle Number", selection: $cycleNumber) {
                ForEach(1...25, id: \.self) { number in
                    Text("\(number)").tag(number)
                }
            }
            TextField("Patient Name", text: $patientName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            DatePicker("Cycle Dosing Start Date", selection: $startDate, displayedComponents: .date)
            DatePicker("Food Challenge Date", selection: $foodChallengeDate, displayedComponents: .date)
        }
        .navigationTitle("Edit Cycle \(cycle.number)")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    let updatedCycle = Cycle(
                        id: cycle.id, // Use the original cycle’s ID
                        number: cycleNumber,
                        patientName: patientName.isEmpty ? "Unnamed" : patientName,
                        startDate: startDate,
                        foodChallengeDate: foodChallengeDate
                    )
                    appData.addCycle(updatedCycle) // Updates existing cycle
                    dismiss()
                }
            }
        }
    }
}

struct EditCycleView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EditCycleView(
                appData: AppData(),
                cycle: Cycle(id: UUID(), number: 1, patientName: "Test Patient", startDate: Date(), foodChallengeDate: Calendar.current.date(byAdding: .weekOfYear, value: 12, to: Date())!)
            )
        }
    }
}
