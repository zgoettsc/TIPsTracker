import SwiftUI

struct InitialSetupView: View {
    @ObservedObject var appData: AppData
    @Environment(\.dismiss) var dismiss
    @Binding var isInitialSetupActive: Bool
    @State private var step = 0
    @State private var isLogOnly = false
    @State private var cycleNumber: Int
    @State private var startDate: Date
    @State private var foodChallengeDate: Date
    @State private var patientName: String
    @State private var roomCodeInput = ""
    @State private var showingRoomCodeError = false
    @State private var userName: String
    @State private var newCycleId: UUID? // Track the new cycle ID
    
    init(appData: AppData, isInitialSetupActive: Binding<Bool>) {
        self.appData = appData
        self._isInitialSetupActive = isInitialSetupActive
        let lastCycle = appData.cycles.last
        self._cycleNumber = State(initialValue: (lastCycle?.number ?? 0) + 1)
        self._startDate = State(initialValue: lastCycle?.foodChallengeDate.addingTimeInterval(3 * 24 * 3600) ?? Date())
        self._foodChallengeDate = State(initialValue: Calendar.current.date(byAdding: .weekOfYear, value: 12, to: lastCycle?.foodChallengeDate.addingTimeInterval(3 * 24 * 3600) ?? Date())!)
        self._patientName = State(initialValue: lastCycle?.patientName ?? "")
        self._userName = State(initialValue: appData.currentUser?.name ?? "")
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if step == 0 {
                    Text("Welcome to TIPs App!")
                        .font(.title)
                        .padding()
                    Text("Were you invited with a room code?")
                        .font(.subheadline)
                        .padding(.bottom, 20)
                    Button(action: {
                        isLogOnly = true
                        step = 1
                    }) {
                        Text("Yes, I have a room code")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 10)
                    
                    Button(action: {
                        isLogOnly = false
                        step = 1
                    }) {
                        Text("No, I’m setting it up myself")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 40)
                } else if step == 1 && isLogOnly {
                    Text("Enter Your Room Code")
                        .font(.title)
                        .padding()
                    TextField("Your Name", text: $userName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                    TextField("Room Code", text: $roomCodeInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                        .submitLabel(.done)
                    if showingRoomCodeError {
                        Text("Invalid or empty room code. Please try again.")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                } else if step == 1 && !isLogOnly {
                    Form {
                        TextField("Your Name", text: $userName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(appData.currentUser != nil)
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
                } else if step == 2 && isLogOnly {
                    RemindersView(appData: appData)
                } else if step == 2 && !isLogOnly {
                    EditItemsView(appData: appData, cycleId: newCycleId ?? UUID())
                } else if step == 3 && isLogOnly {
                    TreatmentFoodTimerView(appData: appData)
                } else if step == 3 && !isLogOnly {
                    RemindersView(appData: appData)
                } else if step == 4 && !isLogOnly {
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
                    } else if step == 1 && !isLogOnly {
                        Button("Back") {
                            step = 0
                        }
                    } else {
                        EmptyView()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if step == 0 {
                        EmptyView()
                    } else {
                        Button(getNextButtonTitle()) {
                            if isLogOnly && step == 1 {
                                if !roomCodeInput.isEmpty && !userName.isEmpty {
                                    appData.roomCode = roomCodeInput
                                    let newUser = User(id: UUID(), name: userName, isAdmin: false)
                                    appData.addUser(newUser)
                                    appData.currentUser = newUser
                                    UserDefaults.standard.set(newUser.id.uuidString, forKey: "currentUserId")
                                    step = 2
                                } else {
                                    showingRoomCodeError = true
                                }
                            } else if !isLogOnly && step == 1 {
                                if !userName.isEmpty {
                                    let newRoomCode = appData.roomCode ?? UUID().uuidString
                                    appData.roomCode = newRoomCode
                                    if appData.currentUser == nil {
                                        let newUser = User(id: UUID(), name: userName, isAdmin: true)
                                        appData.addUser(newUser)
                                        appData.currentUser = newUser
                                        UserDefaults.standard.set(newUser.id.uuidString, forKey: "currentUserId")
                                    }
                                    let effectivePatientName = patientName.isEmpty ? "Unnamed" : patientName
                                    let newCycle = Cycle(
                                        id: UUID(),
                                        number: cycleNumber,
                                        patientName: effectivePatientName,
                                        startDate: startDate,
                                        foodChallengeDate: foodChallengeDate
                                    )
                                    newCycleId = newCycle.id
                                    appData.addCycle(newCycle)
                                    step = 2
                                }
                            } else if (isLogOnly && step == 3) || (!isLogOnly && step == 4) {
                                UserDefaults.standard.set(true, forKey: "hasCompletedSetup")
                                isInitialSetupActive = false
                                dismiss()
                            } else {
                                step += 1
                            }
                        }
                        .disabled(isNextDisabled())
                    }
                }
            }
        }
    }
    
    private func getNavigationTitle() -> String {
        switch step {
        case 0: return "Welcome"
        case 1: return isLogOnly ? "Join Room" : "Setup Cycle"
        case 2: return isLogOnly ? "Reminders" : "Edit Items"
        case 3: return isLogOnly ? "Treatment Timer" : "Reminders"
        case 4: return "Treatment Timer"
        default: return "Setup"
        }
    }
    
    private func getNextButtonTitle() -> String {
        if (isLogOnly && step == 3) || (!isLogOnly && step == 4) {
            return "Finish"
        }
        return "Next"
    }
    
    private func isNextDisabled() -> Bool {
        if step == 1 && isLogOnly {
            return roomCodeInput.isEmpty || userName.isEmpty
        } else if step == 1 && !isLogOnly {
            return userName.isEmpty
        }
        return false
    }
}

struct InitialSetupView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            InitialSetupView(appData: AppData(), isInitialSetupActive: .constant(true))
        }
    }
}
