import SwiftUI

struct EditItemsView: View {
    @ObservedObject var appData: AppData
    let cycleId: UUID
    @State private var showingAddItem = false
    @State private var showingAddTreatmentFood = false
    @State private var showingEditItem: Item? = nil
    @State private var selectedCategory: Category?
    @State private var isEditing = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        List {
            ForEach(Category.allCases, id: \.self) { category in
                CategorySectionView(
                    appData: appData,
                    category: category,
                    items: currentItems().filter { $0.category == category },
                    onAddAction: {
                        if category == .treatment {
                            showingAddTreatmentFood = true
                        } else {
                            selectedCategory = category
                            showingAddItem = true
                        }
                    },
                    onEditAction: { item in
                        showingEditItem = item
                    },
                    isEditing: isEditing,
                    onMove: { source, destination in
                        moveItems(from: source, to: destination, in: category)
                    }
                )
            }
        }
        .navigationTitle("Edit Items")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button(isEditing ? "Done" : "Edit Order") {
                    isEditing.toggle()
                }
            }
        }
        .environment(\.editMode, .constant(isEditing ? EditMode.active : EditMode.inactive))
        .sheet(isPresented: $showingAddItem) {
            NavigationView {
                AddItemView(appData: appData, category: selectedCategory ?? .medicine, cycleId: cycleId)
            }
        }
        .sheet(isPresented: $showingAddTreatmentFood) {
            NavigationView {
                EditTreatmentFoodView(appData: appData, item: nil, cycleId: cycleId)
            }
        }
        .sheet(item: $showingEditItem) { item in
            NavigationView {
                if item.category == .treatment {
                    EditTreatmentFoodView(appData: appData, item: item, cycleId: cycleId)
                } else {
                    EditItemView(appData: appData, item: item, cycleId: cycleId)
                }
            }
        }
        .onDisappear {
            saveReorderedItems()
            print("EditItemsView dismissed, saved reordered items")
        }
    }
    
    private func currentItems() -> [Item] {
        return (appData.cycleItems[cycleId] ?? []).sorted { $0.order < $1.order }
    }
    
    private func moveItems(from source: IndexSet, to destination: Int, in category: Category) {
        guard var allItems = appData.cycleItems[cycleId]?.sorted(by: { $0.order < $1.order }) else { return }
        
        var categoryItems = allItems.filter { $0.category == category }
        let nonCategoryItems = allItems.filter { $0.category != category }
        
        categoryItems.move(fromOffsets: source, toOffset: destination)
        
        let reorderedCategoryItems = categoryItems.enumerated().map { index, item in
            Item(id: item.id, name: item.name, category: item.category, dose: item.dose, unit: item.unit, weeklyDoses: item.weeklyDoses, order: index)
        }
        
        var updatedItems = nonCategoryItems
        updatedItems.append(contentsOf: reorderedCategoryItems)
        
        appData.cycleItems[cycleId] = updatedItems.sorted { $0.order < $1.order }
        print("Reordered items locally: \(updatedItems.map { "\($0.name) - order: \($0.order)" })")
    }
    
    private func saveReorderedItems() {
        guard let items = appData.cycleItems[cycleId] else { return }
        appData.saveItems(items, toCycleId: cycleId) { success in
            if !success {
                print("Failed to save reordered items")
            }
        }
    }
}

struct CategorySectionView: View {
    @ObservedObject var appData: AppData
    let category: Category
    let items: [Item]
    let onAddAction: () -> Void
    let onEditAction: (Item) -> Void
    let isEditing: Bool
    let onMove: (IndexSet, Int) -> Void
    
    var body: some View {
        Section(header: Text(category.rawValue)) {
            if items.isEmpty {
                Text("No items added")
                    .foregroundColor(.gray)
            } else {
                ForEach(items) { item in
                    Button(action: {
                        onEditAction(item)
                    }) {
                        Text(itemDisplayText(item: item))
                            .foregroundColor(.primary)
                    }
                }
                .onMove(perform: isEditing ? onMove : nil)
            }
            Button(action: onAddAction) {
                Text(category == .treatment ? "Add Treatment Food" : "Add Item")
                    .foregroundColor(.blue)
            }
        }
    }
    
    private func itemDisplayText(item: Item) -> String {
        if let dose = item.dose, let unit = item.unit {
            return "\(item.name) - \(String(format: "%.1f", dose)) \(unit)"
        } else if item.category == .treatment, let unit = item.unit {
            let week = currentWeek()
            if let weeklyDose = item.weeklyDoses?[week] {
                return "\(item.name) - \(String(format: "%.1f", weeklyDose)) \(unit) (Week \(week))"
            } else if let firstWeek = item.weeklyDoses?.keys.min(), let firstDose = item.weeklyDoses?[firstWeek] {
                return "\(item.name) - \(String(format: "%.1f", firstDose)) \(unit) (Week \(firstWeek))"
            }
        }
        return item.name
    }
    
    private func currentWeek() -> Int {
        guard let currentCycle = appData.cycles.last else { return 1 }
        let calendar = Calendar.current
        let daysSinceStart = calendar.dateComponents([.day], from: currentCycle.startDate, to: Date()).day ?? 0
        return (daysSinceStart / 7) + 1
    }
}

struct EditItemsView_Previews: PreviewProvider {
    static var previews: some View {
        EditItemsView(appData: AppData(), cycleId: UUID())
    }
}
