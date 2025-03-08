import SwiftUI

struct AddUnitFromItemView: View {
    @ObservedObject var appData: AppData
    @Binding var selectedUnit: Unit?
    @State private var unitName = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Unit Name", text: $unitName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .navigationTitle("Add Unit")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        guard !unitName.isEmpty else { return }
                        let newUnit = Unit(name: unitName)
                        appData.addUnit(newUnit)
                        selectedUnit = newUnit
                        dismiss()
                    }
                    .disabled(unitName.isEmpty)
                }
            }
        }
    }
}
