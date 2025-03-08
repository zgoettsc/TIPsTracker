import Foundation
import SwiftUI
import FirebaseDatabase

class AppData: ObservableObject {
    @Published var cycles: [Cycle] = []
    @Published var cycleItems: [UUID: [Item]] = [:]
    @Published var units: [Unit] = []
    @Published var consumptionLog: [UUID: [UUID: [LogEntry]]] = [:]
    @Published var remindersEnabled: [Category: Bool] = [:]
    @Published var reminderTimes: [Category: Date] = [:]
    @Published var treatmentFoodTimerEnabled: Bool = false
    @Published var lastResetDate: Date?
    @Published var treatmentTimerEnd: Date? {
        didSet { setTreatmentTimerEnd(treatmentTimerEnd) }
    }
    @Published var treatmentTimerDuration: TimeInterval = 900 {
        didSet {
            if treatmentTimerDuration != lastSetTreatmentDuration {
                setTreatmentTimerDuration(treatmentTimerDuration)
            }
        }
    }
    @Published var users: [User] = []
    @Published var currentUser: User?
    @Published var categoryCollapsed: [String: Bool] = [:]
    @Published var roomCode: String? {
        didSet {
            if let roomCode = roomCode {
                UserDefaults.standard.set(roomCode, forKey: "roomCode")
                dbRef = Database.database().reference().child("rooms").child(roomCode)
                loadFromFirebase()
            } else {
                UserDefaults.standard.removeObject(forKey: "roomCode")
                dbRef = nil
            }
        }
    }
    @Published var syncError: String?
    
    private var dbRef: DatabaseReference?
    private var isAddingCycle = false
    private var lastSetTreatmentDuration: TimeInterval?

    init() {
        if let savedRoomCode = UserDefaults.standard.string(forKey: "roomCode") {
            self.roomCode = savedRoomCode
        }
        units = [Unit(name: "mg"), Unit(name: "g")]
        if let userIdStr = UserDefaults.standard.string(forKey: "currentUserId"),
           let userId = UUID(uuidString: userIdStr) {
        }
        loadCachedData()
        checkAndResetIfNeeded()
    }

    private func loadCachedData() {
        if let cycleData = UserDefaults.standard.data(forKey: "cachedCycles"),
           let decodedCycles = try? JSONDecoder().decode([Cycle].self, from: cycleData) {
            self.cycles = decodedCycles
        }
        if let itemsData = UserDefaults.standard.data(forKey: "cachedCycleItems"),
           let decodedItems = try? JSONDecoder().decode([UUID: [Item]].self, from: itemsData) {
            self.cycleItems = decodedItems
        }
        if let logData = UserDefaults.standard.data(forKey: "cachedConsumptionLog"),
           let decodedLog = try? JSONDecoder().decode([UUID: [UUID: [LogEntry]]].self, from: logData) {
            self.consumptionLog = decodedLog
        }
    }

    private func saveCachedData() {
        if let cycleData = try? JSONEncoder().encode(cycles) {
            UserDefaults.standard.set(cycleData, forKey: "cachedCycles")
        }
        if let itemsData = try? JSONEncoder().encode(cycleItems) {
            UserDefaults.standard.set(itemsData, forKey: "cachedCycleItems")
        }
        if let logData = try? JSONEncoder().encode(consumptionLog) {
            UserDefaults.standard.set(logData, forKey: "cachedConsumptionLog")
        }
    }

    private func loadFromFirebase() {
        guard let dbRef = dbRef else {
            print("No database reference available.")
            syncError = "No room code set."
            return
        }

        dbRef.child("cycles").observe(.value) { snapshot, _ in
            if self.isAddingCycle { return }
            var newCycles: [Cycle] = []
            var newCycleItems: [UUID: [Item]] = self.cycleItems
            
            print("Firebase snapshot received: \(snapshot)")
            
            if snapshot.exists(), let value = snapshot.value as? [String: [String: Any]] {
                for (key, dict) in value {
                    var mutableDict = dict
                    mutableDict["id"] = key
                    guard let cycle = Cycle(dictionary: mutableDict) else { continue }
                    newCycles.append(cycle)

                    if let itemsDict = dict["items"] as? [String: [String: Any]], !itemsDict.isEmpty {
                        let firebaseItems = itemsDict.compactMap { (itemKey, itemDict) -> Item? in
                            var mutableItemDict = itemDict
                            mutableItemDict["id"] = itemKey
                            return Item(dictionary: mutableItemDict)
                        }.sorted { $0.order < $1.order }
                        
                        if let localItems = newCycleItems[cycle.id] {
                            var mergedItems = localItems.map { localItem in
                                firebaseItems.first(where: { $0.id == localItem.id }) ?? localItem
                            }
                            let newFirebaseItems = firebaseItems.filter { firebaseItem in
                                !mergedItems.contains(where: { mergedItem in mergedItem.id == firebaseItem.id })
                            }
                            mergedItems.append(contentsOf: newFirebaseItems)
                            newCycleItems[cycle.id] = mergedItems.sorted { $0.order < $1.order }
                        } else {
                            newCycleItems[cycle.id] = firebaseItems
                        }
                        print("Updated items for cycle \(cycle.id): \(newCycleItems[cycle.id]?.map { "\($0.name) - order: \($0.order)" } ?? [])")
                    } else if newCycleItems[cycle.id] == nil {
                        newCycleItems[cycle.id] = []
                        print("No items in Firebase for cycle \(cycle.id), initialized empty")
                    }
                }
                DispatchQueue.main.async {
                    self.cycles = newCycles.sorted { $0.startDate < $1.startDate }
                    self.cycleItems = newCycleItems
                    self.saveCachedData()
                    self.syncError = nil
                    print("Synced cycleItems: \(self.cycleItems)")
                }
            } else {
                DispatchQueue.main.async {
                    self.cycles = []
                    if self.cycleItems.isEmpty {
                        self.syncError = "No cycles found in Firebase or data is malformed."
                    } else {
                        self.syncError = nil
                    }
                    print("Firebase cycles empty, cycleItems retained: \(self.cycleItems)")
                }
            }
        } withCancel: { error in
            DispatchQueue.main.async {
                self.syncError = "Failed to sync cycles: \(error.localizedDescription)"
                print("Sync error: \(error.localizedDescription)")
            }
        }

        dbRef.child("units").observe(.value) { snapshot, _ in
            if snapshot.exists(), let value = snapshot.value as? [String: [String: Any]] {
                let units = value.compactMap { (key, dict) -> Unit? in
                    var mutableDict = dict
                    mutableDict["id"] = key
                    return Unit(dictionary: mutableDict)
                }
                DispatchQueue.main.async {
                    self.units = units.isEmpty ? [Unit(name: "mg"), Unit(name: "g")] : units
                }
            }
        }

        dbRef.child("users").observe(.value) { snapshot, _ in
            if snapshot.exists(), let value = snapshot.value as? [String: [String: Any]] {
                let users = value.compactMap { (key, dict) -> User? in
                    var mutableDict = dict
                    mutableDict["id"] = key
                    return User(dictionary: mutableDict)
                }
                DispatchQueue.main.async {
                    self.users = users
                    if let userIdStr = UserDefaults.standard.string(forKey: "currentUserId"),
                       let userId = UUID(uuidString: userIdStr) {
                        self.currentUser = users.first(where: { $0.id == userId })
                    }
                }
            }
        }

        dbRef.child("consumptionLog").observe(.value) { snapshot, _ in
            if snapshot.exists(), let value = snapshot.value as? [String: [String: [[String: String]]]] {
                var newLog: [UUID: [UUID: [LogEntry]]] = [:]
                let formatter = ISO8601DateFormatter()
                for (cycleIdStr, itemsLog) in value {
                    guard let cycleId = UUID(uuidString: cycleIdStr) else { continue }
                    var cycleLog: [UUID: [LogEntry]] = [:]
                    for (itemIdStr, entries) in itemsLog {
                        guard let itemId = UUID(uuidString: itemIdStr) else { continue }
                        cycleLog[itemId] = entries.compactMap { entry in
                            guard let timestamp = entry["timestamp"],
                                  let date = formatter.date(from: timestamp),
                                  let userIdStr = entry["userId"],
                                  let userId = UUID(uuidString: userIdStr) else { return nil }
                            return LogEntry(date: date, userId: userId)
                        }
                    }
                    newLog[cycleId] = cycleLog
                }
                DispatchQueue.main.async {
                    self.consumptionLog = newLog
                    self.saveCachedData()
                }
            }
        }

        dbRef.child("categoryCollapsed").observe(.value) { snapshot, _ in
            if snapshot.exists(), let value = snapshot.value as? [String: Bool] {
                DispatchQueue.main.async {
                    self.categoryCollapsed = value
                }
            }
        }

        dbRef.child("treatmentTimerEnd").observe(.value) { snapshot, _ in
            let formatter = ISO8601DateFormatter()
            DispatchQueue.main.async {
                if snapshot.exists(), let timestamp = snapshot.value as? String,
                   let date = formatter.date(from: timestamp) {
                    if self.treatmentTimerEnd == nil || date > self.treatmentTimerEnd! {
                        self.treatmentTimerEnd = date
                        print("Firebase updated treatmentTimerEnd to: \(date)")
                    }
                } else if self.treatmentTimerEnd != nil && self.treatmentTimerEnd! <= Date() {
                    self.treatmentTimerEnd = nil
                    print("Firebase cleared treatmentTimerEnd as it’s past")
                }
            }
        }

        dbRef.child("treatmentTimerDuration").observe(.value) { snapshot, _ in
            DispatchQueue.main.async {
                if snapshot.exists(), let duration = snapshot.value as? Double {
                    if duration != self.lastSetTreatmentDuration {
                        self.treatmentTimerDuration = duration
                        print("Firebase updated treatmentTimerDuration to: \(duration)")
                    }
                } else if self.treatmentTimerDuration != 900 {
                    self.treatmentTimerDuration = 900
                    print("Firebase reset treatmentTimerDuration to default: 900")
                }
            }
        }
    }

    func setLastResetDate(_ date: Date) {
        guard let dbRef = dbRef else { return }
        dbRef.child("lastResetDate").setValue(ISO8601DateFormatter().string(from: date))
        lastResetDate = date
    }

    func setTreatmentTimerEnd(_ date: Date?) {
        guard let dbRef = dbRef else { return }
        if let date = date {
            dbRef.child("treatmentTimerEnd").setValue(ISO8601DateFormatter().string(from: date))
            print("Set treatmentTimerEnd to: \(date)")
        } else {
            dbRef.child("treatmentTimerEnd").removeValue()
            print("Cleared treatmentTimerEnd")
        }
    }

    func setTreatmentTimerDuration(_ duration: TimeInterval) {
        guard let dbRef = dbRef else { return }
        lastSetTreatmentDuration = duration
        dbRef.child("treatmentTimerDuration").setValue(duration)
        print("Set treatmentTimerDuration to: \(duration)")
    }

    func addUnit(_ unit: Unit) {
        guard let dbRef = dbRef else { return }
        dbRef.child("units").child(unit.id.uuidString).setValue(unit.toDictionary())
    }

    func addItem(_ item: Item, toCycleId: UUID, completion: @escaping (Bool) -> Void = { _ in }) {
        guard let dbRef = dbRef, cycles.contains(where: { $0.id == toCycleId }), currentUser?.isAdmin == true else {
            completion(false)
            return
        }
        let currentItems = cycleItems[toCycleId] ?? []
        let newOrder = item.order == 0 ? currentItems.count : item.order
        let updatedItem = Item(
            id: item.id,
            name: item.name,
            category: item.category,
            dose: item.dose,
            unit: item.unit,
            weeklyDoses: item.weeklyDoses,
            order: newOrder
        )
        let itemRef = dbRef.child("cycles").child(toCycleId.uuidString).child("items").child(updatedItem.id.uuidString)
        itemRef.setValue(updatedItem.toDictionary()) { error, _ in
            if let error = error {
                print("Error adding item \(updatedItem.id) to Firebase: \(error)")
                completion(false)
            } else {
                print("Successfully saved item \(updatedItem.id) to cycle \(toCycleId) in Firebase")
                dbRef.child("cycles").child(toCycleId.uuidString).child("items").observeSingleEvent(of: .value) { snapshot, _ in
                    if let itemsDict = snapshot.value as? [String: [String: Any]] {
                        print("Firebase items for \(toCycleId) after save: \(itemsDict)")
                    } else {
                        print("Firebase items for \(toCycleId) empty or missing after save")
                    }
                } withCancel: { error in
                    print("Error verifying Firebase items for \(toCycleId): \(error)")
                }
                
                DispatchQueue.main.async {
                    if var items = self.cycleItems[toCycleId] {
                        if let index = items.firstIndex(where: { $0.id == updatedItem.id }) {
                            items[index] = updatedItem
                        } else {
                            items.append(updatedItem)
                        }
                        self.cycleItems[toCycleId] = items.sorted { $0.order < $1.order }
                    } else {
                        self.cycleItems[toCycleId] = [updatedItem]
                    }
                    self.saveCachedData()
                    self.objectWillChange.send()
                    completion(true)
                }
            }
        }
    }

    func saveItems(_ items: [Item], toCycleId: UUID, completion: @escaping (Bool) -> Void = { _ in }) {
        guard let dbRef = dbRef, cycles.contains(where: { $0.id == toCycleId }) else {
            print("Cannot save items: no dbRef or cycle not found")
            completion(false)
            return
        }
        let itemsDict = Dictionary(uniqueKeysWithValues: items.map { ($0.id.uuidString, $0.toDictionary()) })
        dbRef.child("cycles").child(toCycleId.uuidString).child("items").setValue(itemsDict) { error, _ in
            if let error = error {
                print("Error saving items to Firebase: \(error)")
                completion(false)
            } else {
                print("Successfully saved items to Firebase: \(items.map { "\($0.name) - order: \($0.order)" })")
                DispatchQueue.main.async {
                    self.cycleItems[toCycleId] = items.sorted { $0.order < $1.order }
                    self.saveCachedData()
                    self.objectWillChange.send()
                    completion(true)
                }
            }
        }
    }

    func removeItem(_ itemId: UUID, fromCycleId: UUID) {
        guard let dbRef = dbRef, cycles.contains(where: { $0.id == fromCycleId }), currentUser?.isAdmin == true else { return }
        dbRef.child("cycles").child(fromCycleId.uuidString).child("items").child(itemId.uuidString).removeValue()
        if var items = cycleItems[fromCycleId] {
            items.removeAll { $0.id == itemId }
            cycleItems[fromCycleId] = items
            saveCachedData()
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    func addCycle(_ cycle: Cycle, copyItemsFromCycleId: UUID? = nil) {
        guard let dbRef = dbRef, currentUser?.isAdmin == true else { return }
        if cycles.contains(where: { $0.id == cycle.id }) {
            print("Cycle \(cycle.id) already exists, updating instead")
            saveCycleToFirebase(cycle, withItems: cycleItems[cycle.id] ?? [], previousCycleId: copyItemsFromCycleId)
            return
        }
        
        isAddingCycle = true
        cycles.append(cycle)
        var copiedItems: [Item] = []
        
        let effectiveCopyId = copyItemsFromCycleId ?? (cycles.count > 1 ? cycles[cycles.count - 2].id : nil)
        
        if let fromCycleId = effectiveCopyId {
            dbRef.child("cycles").child(fromCycleId.uuidString).child("items").observeSingleEvent(of: .value) { snapshot, _ in
                if let itemsDict = snapshot.value as? [String: [String: Any]] {
                    let itemsToCopy = itemsDict.compactMap { (itemKey, itemDict) -> Item? in
                        var mutableItemDict = itemDict
                        mutableItemDict["id"] = itemKey
                        return Item(dictionary: mutableItemDict)
                    }
                    copiedItems = itemsToCopy.map { item in
                        Item(
                            id: UUID(),
                            name: item.name,
                            category: item.category,
                            dose: item.dose,
                            unit: item.unit,
                            weeklyDoses: item.weeklyDoses,
                            order: item.order
                        )
                    }
                }
                DispatchQueue.main.async {
                    self.cycleItems[cycle.id] = copiedItems
                    self.saveCycleToFirebase(cycle, withItems: copiedItems, previousCycleId: effectiveCopyId)
                }
            } withCancel: { error in
                DispatchQueue.main.async {
                    self.cycleItems[cycle.id] = copiedItems
                    self.saveCycleToFirebase(cycle, withItems: copiedItems, previousCycleId: effectiveCopyId)
                }
            }
        } else {
            cycleItems[cycle.id] = []
            saveCycleToFirebase(cycle, withItems: copiedItems, previousCycleId: effectiveCopyId)
        }
    }

    private func saveCycleToFirebase(_ cycle: Cycle, withItems items: [Item], previousCycleId: UUID?) {
        guard let dbRef = dbRef else { return }
        var cycleDict = cycle.toDictionary()
        let cycleRef = dbRef.child("cycles").child(cycle.id.uuidString)
        
        cycleRef.updateChildValues(cycleDict) { error, _ in
            if let error = error {
                print("Error updating cycle metadata \(cycle.id): \(error)")
                DispatchQueue.main.async {
                    if let index = self.cycles.firstIndex(where: { $0.id == cycle.id }) {
                        self.cycles.remove(at: index)
                        self.cycleItems.removeValue(forKey: cycle.id)
                    }
                    self.isAddingCycle = false
                    self.objectWillChange.send()
                }
                return
            }
            
            if !items.isEmpty {
                let itemsDict = Dictionary(uniqueKeysWithValues: items.map { ($0.id.uuidString, $0.toDictionary()) })
                cycleRef.child("items").updateChildValues(itemsDict) { error, _ in
                    if let error = error {
                        print("Error adding items to cycle \(cycle.id): \(error)")
                    }
                }
            }
            
            if let prevId = previousCycleId, let prevItems = self.cycleItems[prevId], !prevItems.isEmpty {
                let prevCycleRef = dbRef.child("cycles").child(prevId.uuidString)
                prevCycleRef.child("items").observeSingleEvent(of: .value) { snapshot, _ in
                    if snapshot.value == nil || (snapshot.value as? [String: [String: Any]])?.isEmpty ?? true {
                        let prevItemsDict = Dictionary(uniqueKeysWithValues: prevItems.map { ($0.id.uuidString, $0.toDictionary()) })
                        prevCycleRef.child("items").updateChildValues(prevItemsDict)
                    }
                }
            }
            
            DispatchQueue.main.async {
                if self.cycleItems[cycle.id] == nil || self.cycleItems[cycle.id]!.isEmpty {
                    self.cycleItems[cycle.id] = items
                }
                self.saveCachedData()
                self.isAddingCycle = false
                self.objectWillChange.send()
            }
        }
    }

    func addUser(_ user: User) {
        guard let dbRef = dbRef else { return }
        dbRef.child("users").child(user.id.uuidString).setValue(user.toDictionary())
    }

    func logConsumption(itemId: UUID, cycleId: UUID, date: Date = Date()) {
        guard let dbRef = dbRef, let userId = currentUser?.id, cycles.contains(where: { $0.id == cycleId }) else { return }
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: date)
        dbRef.child("consumptionLog").child(cycleId.uuidString).child(itemId.uuidString).observeSingleEvent(of: .value) { snapshot, _ in
            var entries = snapshot.value as? [[String: String]] ?? []
            let newEntry = ["timestamp": timestamp, "userId": userId.uuidString]
            if !entries.contains(where: { $0["timestamp"] == timestamp && $0["userId"] == userId.uuidString }) {
                entries.append(newEntry)
                dbRef.child("consumptionLog").child(cycleId.uuidString).child(itemId.uuidString).setValue(entries)
            }
        }
    }

    func removeConsumption(itemId: UUID, cycleId: UUID, date: Date) {
        guard let dbRef = dbRef, let userId = currentUser?.id else { return }
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: date)
        dbRef.child("consumptionLog").child(cycleId.uuidString).child(itemId.uuidString).observeSingleEvent(of: .value) { snapshot, _ in
            if var entries = snapshot.value as? [[String: String]] {
                entries.removeAll { $0["timestamp"] == timestamp && $0["userId"] == userId.uuidString }
                dbRef.child("consumptionLog").child(cycleId.uuidString).child(itemId.uuidString).setValue(entries.isEmpty ? nil : entries)
            }
        }
    }

    func setConsumptionLog(itemId: UUID, cycleId: UUID, entries: [LogEntry]) {
        guard let dbRef = dbRef else { return }
        let formatter = ISO8601DateFormatter()
        let entryDicts = entries.map { ["timestamp": formatter.string(from: $0.date), "userId": $0.userId.uuidString] }
        dbRef.child("consumptionLog").child(cycleId.uuidString).child(itemId.uuidString).setValue(entryDicts.isEmpty ? nil : entryDicts)
    }

    func setCategoryCollapsed(_ category: Category, isCollapsed: Bool) {
        guard let dbRef = dbRef else { return }
        categoryCollapsed[category.rawValue] = isCollapsed
        dbRef.child("categoryCollapsed").child(category.rawValue).setValue(isCollapsed)
    }

    func resetDaily() {
        let today = Calendar.current.startOfDay(for: Date())
        setLastResetDate(today)
        
        for (cycleId, itemLogs) in consumptionLog {
            var updatedItemLogs = itemLogs
            for (itemId, logs) in itemLogs {
                updatedItemLogs[itemId] = logs.filter { !Calendar.current.isDate($0.date, inSameDayAs: today) }
                if updatedItemLogs[itemId]?.isEmpty ?? false {
                    updatedItemLogs.removeValue(forKey: itemId)
                }
            }
            if let dbRef = dbRef {
                let formatter = ISO8601DateFormatter()
                let updatedLogDict = updatedItemLogs.mapValues { entries in
                    entries.map { ["timestamp": formatter.string(from: $0.date), "userId": $0.userId.uuidString] }
                }
                dbRef.child("consumptionLog").child(cycleId.uuidString).setValue(updatedLogDict.isEmpty ? nil : updatedLogDict)
            }
            consumptionLog[cycleId] = updatedItemLogs.isEmpty ? nil : updatedItemLogs
        }
        
        Category.allCases.forEach { category in
            setCategoryCollapsed(category, isCollapsed: false)
        }
        
        if let endDate = treatmentTimerEnd, endDate > Date() {
            print("Preserving active timer ending at: \(endDate)")
        } else {
            treatmentTimerEnd = nil
            print("Cleared treatmentTimerEnd during reset as it’s past or nil")
        }
        
        saveCachedData()
        print("Reset daily data for \(today), preserved historical logs: \(consumptionLog)")
    }

    func checkAndResetIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        if lastResetDate == nil || !Calendar.current.isDate(lastResetDate!, inSameDayAs: today) {
            resetDaily()
        }
    }

    func currentCycleId() -> UUID? {
        cycles.last?.id
    }

    func verifyFirebaseState() {
        guard let dbRef = dbRef else { return }
        dbRef.child("cycles").observeSingleEvent(of: .value) { snapshot, _ in
            if let value = snapshot.value as? [String: [String: Any]] {
                print("Final Firebase cycles state: \(value)")
            } else {
                print("Final Firebase cycles state is empty or missing")
            }
        }
    }
}
