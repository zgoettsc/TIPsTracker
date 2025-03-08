import SwiftUI

struct EditItemView: View {
    @ObservedObject var appData: AppData
    @State var item: Item
    let cycleId: UUID
    @State private var name: String
    @State private var dose: String
    @State private var selectedUnit: Unit?
    @State private var selectedCategory: Category
    @State private var showingDeleteConfirmation = false
    @Environment(\.dismiss) var dismiss
    
    init(appData: AppData, item: Item, cycleId: UUID) {
        self.appData = appData
        self._item = State(initialValue: item)
        self.cycleId = cycleId
        self._name = State(initialValue: item.name)
        self._dose = State(initialValue: item.dose.map { String($0) } ?? "")
        self._selectedUnit = State(initialValue: appData.units.first { $0.name == item.unit })
        self._selectedCategory = State(initialValue: item.category)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Item Details")) {
                TextField("Item Name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                HStack {
                    TextField("Dose", text: $dose)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Picker("Unit", selection: $selectedUnit) {
                        Text("Select Unit").tag(nil as Unit?)
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
            
            Section(header: Text("Category")) {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(Category.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Section {
                Button("Delete Item", role: .destructive) {
                    showingDeleteConfirmation = true
                }
                .alert("Delete \(name)?", isPresented: $showingDeleteConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) {
                        appData.removeItem(item.id, fromCycleId: cycleId)
                        dismiss()
                    }
                } message: {
                    Text("This action cannot be undone.")
                }
            }
        }
        .navigationTitle("Edit Item")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    guard let doseValue = Double(dose), !name.isEmpty else { return }
                    let updatedItem = Item(
                        id: item.id,
                        name: name,
                        category: selectedCategory,
                        dose: doseValue,
                        unit: selectedUnit?.name,
                        weeklyDoses: nil
                    )
                    appData.addItem(updatedItem, toCycleId: cycleId) { success in
                        if success {
                            DispatchQueue.main.async {
                                dismiss()
                            }
                        }
                    }
                }
                .disabled(name.isEmpty || dose.isEmpty || Double(dose) == nil || selectedUnit == nil)
            }
        }
    }
}

struct EditItemView_Previews: PreviewProvider {
    static var previews: some View {
        EditItemView(appData: AppData(), item: Item(name: "Test", category: .medicine), cycleId: UUID())
    }
}
