import Foundation

// Define the LogEntry struct
struct LogEntry: Equatable, Codable {
    let date: Date
    let userId: UUID
    
    enum CodingKeys: String, CodingKey {
        case date = "timestamp"
        case userId
    }
    
    init(date: Date, userId: UUID) {
        self.date = date
        self.userId = userId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dateString = try container.decode(String.self, forKey: .date)
        guard let decodedDate = ISO8601DateFormatter().date(from: dateString) else {
            throw DecodingError.dataCorruptedError(forKey: .date, in: container, debugDescription: "Invalid ISO8601 date string")
        }
        self.date = decodedDate
        self.userId = try container.decode(UUID.self, forKey: .userId)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let dateString = ISO8601DateFormatter().string(from: date)
        try container.encode(dateString, forKey: .date)
        try container.encode(userId, forKey: .userId)
    }
}

// Cycle conforms to Equatable and Codable
struct Cycle: Equatable, Codable {
    let id: UUID
    let number: Int
    let patientName: String
    let startDate: Date
    let foodChallengeDate: Date
    
    init(id: UUID = UUID(), number: Int, patientName: String, startDate: Date, foodChallengeDate: Date) {
        self.id = id
        self.number = number
        self.patientName = patientName
        self.startDate = startDate
        self.foodChallengeDate = foodChallengeDate
    }
    
    init?(dictionary: [String: Any]) {
        guard let idStr = dictionary["id"] as? String, let id = UUID(uuidString: idStr),
              let number = dictionary["number"] as? Int,
              let patientName = dictionary["patientName"] as? String,
              let startDateStr = dictionary["startDate"] as? String,
              let startDate = ISO8601DateFormatter().date(from: startDateStr),
              let foodChallengeDateStr = dictionary["foodChallengeDate"] as? String,
              let foodChallengeDate = ISO8601DateFormatter().date(from: foodChallengeDateStr) else { return nil }
        self.id = id
        self.number = number
        self.patientName = patientName
        self.startDate = startDate
        self.foodChallengeDate = foodChallengeDate
    }
    
    func toDictionary() -> [String: Any] {
        [
            "id": id.uuidString,
            "number": number,
            "patientName": patientName,
            "startDate": ISO8601DateFormatter().string(from: startDate),
            "foodChallengeDate": ISO8601DateFormatter().string(from: foodChallengeDate)
        ]
    }
    
    static func == (lhs: Cycle, rhs: Cycle) -> Bool {
        return lhs.id == rhs.id &&
               lhs.number == rhs.number &&
               lhs.patientName == rhs.patientName &&
               lhs.startDate == rhs.startDate &&
               lhs.foodChallengeDate == rhs.foodChallengeDate
    }
    
    enum CodingKeys: String, CodingKey {
        case id, number, patientName, startDate, foodChallengeDate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        number = try container.decode(Int.self, forKey: .number)
        patientName = try container.decode(String.self, forKey: .patientName)
        let startDateString = try container.decode(String.self, forKey: .startDate)
        guard let decodedStartDate = ISO8601DateFormatter().date(from: startDateString) else {
            throw DecodingError.dataCorruptedError(forKey: .startDate, in: container, debugDescription: "Invalid ISO8601 date string")
        }
        startDate = decodedStartDate
        let foodChallengeDateString = try container.decode(String.self, forKey: .foodChallengeDate)
        guard let decodedFoodChallengeDate = ISO8601DateFormatter().date(from: foodChallengeDateString) else {
            throw DecodingError.dataCorruptedError(forKey: .foodChallengeDate, in: container, debugDescription: "Invalid ISO8601 date string")
        }
        foodChallengeDate = decodedFoodChallengeDate
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(number, forKey: .number)
        try container.encode(patientName, forKey: .patientName)
        try container.encode(ISO8601DateFormatter().string(from: startDate), forKey: .startDate)
        try container.encode(ISO8601DateFormatter().string(from: foodChallengeDate), forKey: .foodChallengeDate)
    }
}

// Item conforms to Identifiable and Codable
struct Item: Identifiable, Codable {
    let id: UUID
    let name: String
    let category: Category
    let dose: Double?
    let unit: String?
    let weeklyDoses: [Int: Double]?
    let order: Int // New field to track order
    
    init(id: UUID = UUID(), name: String, category: Category, dose: Double? = nil, unit: String? = nil, weeklyDoses: [Int: Double]? = nil, order: Int = 0) {
        self.id = id
        self.name = name
        self.category = category
        self.dose = dose
        self.unit = unit
        self.weeklyDoses = weeklyDoses
        self.order = order
    }
    
    init?(dictionary: [String: Any]) {
        guard let idStr = dictionary["id"] as? String, let id = UUID(uuidString: idStr),
              let name = dictionary["name"] as? String,
              let categoryStr = dictionary["category"] as? String,
              let category = Category(rawValue: categoryStr) else { return nil }
        self.id = id
        self.name = name
        self.category = category
        self.dose = dictionary["dose"] as? Double
        self.unit = dictionary["unit"] as? String
        if let weeklyDosesDict = dictionary["weeklyDoses"] as? [String: Double] {
            self.weeklyDoses = weeklyDosesDict.reduce(into: [Int: Double]()) { result, pair in
                if let week = Int(pair.key) {
                    result[week] = pair.value
                }
            }
        } else {
            self.weeklyDoses = nil
        }
        self.order = dictionary["order"] as? Int ?? 0 // Default to 0 if not present
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "name": name,
            "category": category.rawValue,
            "order": order // Include order in dictionary
        ]
        if let dose = dose { dict["dose"] = dose }
        if let unit = unit { dict["unit"] = unit }
        if let weeklyDoses = weeklyDoses {
            let stringKeyedDoses = weeklyDoses.mapKeys { String($0) }
            dict["weeklyDoses"] = stringKeyedDoses
        }
        return dict
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, category, dose, unit, weeklyDoses, order
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let categoryString = try container.decode(String.self, forKey: .category)
        guard let decodedCategory = Category(rawValue: categoryString) else {
            throw DecodingError.dataCorruptedError(forKey: .category, in: container, debugDescription: "Invalid category value")
        }
        category = decodedCategory
        dose = try container.decodeIfPresent(Double.self, forKey: .dose)
        unit = try container.decodeIfPresent(String.self, forKey: .unit)
        if let weeklyDosesDict = try container.decodeIfPresent([String: Double].self, forKey: .weeklyDoses) {
            weeklyDoses = weeklyDosesDict.reduce(into: [Int: Double]()) { result, pair in
                if let week = Int(pair.key) {
                    result[week] = pair.value
                }
            }
        } else {
            weeklyDoses = nil
        }
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0 // Default to 0 if missing
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(category.rawValue, forKey: .category)
        try container.encodeIfPresent(dose, forKey: .dose)
        try container.encodeIfPresent(unit, forKey: .unit)
        if let weeklyDoses = weeklyDoses {
            let stringKeyedDoses = weeklyDoses.mapKeys { String($0) }
            try container.encode(stringKeyedDoses, forKey: .weeklyDoses)
        }
        try container.encode(order, forKey: .order)
    }
}

// Unit conforms to Hashable, Identifiable, and Codable
struct Unit: Hashable, Identifiable, Codable {
    let id: UUID
    let name: String
    
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
    
    init?(dictionary: [String: Any]) {
        guard let idStr = dictionary["id"] as? String, let id = UUID(uuidString: idStr),
              let name = dictionary["name"] as? String else { return nil }
        self.id = id
        self.name = name
    }
    
    func toDictionary() -> [String: Any] {
        ["id": id.uuidString, "name": name]
    }
    
    static func == (lhs: Unit, rhs: Unit) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
    }
}

// User conforms to Identifiable, Equatable, and Codable
struct User: Identifiable, Equatable, Codable {
    let id: UUID
    let name: String
    let isAdmin: Bool
    
    init(id: UUID = UUID(), name: String, isAdmin: Bool = false) {
        self.id = id
        self.name = name
        self.isAdmin = isAdmin
    }
    
    init?(dictionary: [String: Any]) {
        guard let idStr = dictionary["id"] as? String, let id = UUID(uuidString: idStr),
              let name = dictionary["name"] as? String,
              let isAdmin = dictionary["isAdmin"] as? Bool else { return nil }
        self.id = id
        self.name = name
        self.isAdmin = isAdmin
    }
    
    func toDictionary() -> [String: Any] {
        ["id": id.uuidString, "name": name, "isAdmin": isAdmin]
    }
    
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name && lhs.isAdmin == rhs.isAdmin
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, isAdmin
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isAdmin = try container.decode(Bool.self, forKey: .isAdmin)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(isAdmin, forKey: .isAdmin)
    }
}

enum Category: String, CaseIterable {
    case medicine = "Medicine"
    case maintenance = "Maintenance"
    case treatment = "Treatment"
    case recommended = "Recommended"
}

// Helper extension to transform dictionary keys
extension Dictionary {
    func mapKeys<T>(transform: (Key) -> T) -> [T: Value] {
        return reduce(into: [T: Value]()) { result, pair in
            result[transform(pair.key)] = pair.value
        }
    }
}
