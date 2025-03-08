import SwiftUI

struct AddItemView: View {
    @ObservedObject var appData: AppData
    let category: Category
    let cycleId: UUID
    @State private var item: Item?
    @State private var itemName: String
    @State private var dose: String
    @State private var selectedUnit: Unit?
    @Environment(\.dismiss) var dismiss
    
    init(appData: AppData, category: Category, cycleId: UUID, item: Item? = nil) {
        self.appData = appData
        self.category = category
        self.cycleId = cycleId
        self._item = State(initialValue: item)
        self._itemName = State(initialValue: item?.name ?? "")
        self._dose = State(initialValue: item?.dose.map { String($0) } ?? "")
        self._selectedUnit = State(initialValue: item != nil ? appData.units.first { $0.name == item!.unit } : nil)
    }
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Item Name", text: $itemName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                HStack {
                    TextField("Dose", text: $dose)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Picker("Unit", selection: $selectedUnit) {
                        Text("Pick one").tag(nil as Unit?)
                        ForEach(appData.units, id: \.self) { unit in
                            Text(unit.name).tag(unit as Unit?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                NavigationLink(destination: AddUnitFromItemView(appData: appData, selectedUnit: $selectedUnit)) {
                    Text("Add a Unit")
                }
            }
            .navigationTitle(item == nil ? "Add Item" : "Edit Item")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        guard !itemName.isEmpty, let doseValue = Double(dose), let unit = selectedUnit else { return }
                        let newItem = Item(
                            id: item?.id ?? UUID(),
                            name: itemName,
                            category: category,
                            dose: doseValue,
                            unit: unit.name,
                            weeklyDoses: nil
                        )
                        appData.addItem(newItem, toCycleId: cycleId) { success in
                            if success {
                                DispatchQueue.main.async {
                                    dismiss()
                                }
                            }
                        }
                    }
                    .disabled(itemName.isEmpty || dose.isEmpty || Double(dose) == nil || selectedUnit == nil)
                }
            }
        }
    }
}

struct AddItemView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AddItemView(appData: AppData(), category: .medicine, cycleId: UUID())
        }
    }
}
