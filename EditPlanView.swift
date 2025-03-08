import SwiftUI

struct EditPlanView: View {
    @ObservedObject var appData: AppData
    @Environment(\.dismiss) var dismiss

    var body: some View {
        List {
            NavigationLink(destination: EditCycleView(
                appData: appData,
                cycle: appData.cycles.last ?? Cycle(
                    id: UUID(),
                    number: 1,
                    patientName: "Unnamed",
                    startDate: Date(),
                    foodChallengeDate: Calendar.current.date(byAdding: .weekOfYear, value: 12, to: Date())!
                )
            )) {
                Text("Edit Cycle")
                    .font(.headline)
            }
            NavigationLink(destination: EditItemsView(appData: appData, cycleId: appData.currentCycleId() ?? UUID())) {
                Text("Edit Items")
                    .font(.headline)
            }
        }
        .navigationTitle("Edit Plan")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Settings") {
                    dismiss()
                }
            }
        }
    }
}

struct EditPlanView_Previews: PreviewProvider {
    static var previews: some View {
        EditPlanView(appData: AppData())
    }
}
