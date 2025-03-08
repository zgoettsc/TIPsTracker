import SwiftUI

struct SettingsView: View {
    @ObservedObject var appData: AppData
    @State private var showingRoomCodeSheet = false
    @State private var newRoomCode = ""
    @State private var showingConfirmation = false
    @State private var showingShareSheet = false
    @State private var selectedUser: User? // For editing other users' roles
    @State private var showingEditNameSheet = false // New state for editing current user's name
    @State private var editedName = "" // New state for name input
    
    var body: some View {
        List {
            if appData.currentUser?.isAdmin ?? false {
                NavigationLink(destination: EditPlanView(appData: appData)) {
                    Text("Edit Plan")
                        .font(.headline)
                }
            }
            NavigationLink(destination: RemindersView(appData: appData)) {
                Text("Reminders")
                    .font(.headline)
            }
            NavigationLink(destination: TreatmentFoodTimerView(appData: appData)) {
                Text("Treatment Food Timer")
                    .font(.headline)
            }
            if appData.currentUser?.isAdmin ?? false {
                NavigationLink(destination: EditUnitsView(appData: appData)) {
                    Text("Edit Units")
                        .font(.headline)
                }
            }
            NavigationLink(destination: HistoryView(appData: appData)) {
                Text("History")
                    .font(.headline)
            }
            Section(header: Text("Room Code")) {
                Text("Current Room Code: \(appData.roomCode ?? "None")")
                    .contextMenu {
                        Button("Copy to Clipboard") {
                            UIPasteboard.general.string = appData.roomCode
                        }
                    }
                Button("Change Room Code") {
                    newRoomCode = appData.roomCode ?? ""
                    showingRoomCodeSheet = true
                }
                if appData.currentUser?.isAdmin ?? false {
                    Button("Generate New Room Code") {
                        newRoomCode = UUID().uuidString
                        showingConfirmation = true
                    }
                    Button("Share Room Code") {
                        showingShareSheet = true
                    }
                }
            }
            if appData.currentUser?.isAdmin ?? false {
                Section(header: Text("User Management")) {
                    ForEach(appData.users) { user in
                        HStack {
                            Text(user.name)
                            Spacer()
                            Text(user.isAdmin ? "Admin" : "Log-Only")
                            if user.id == appData.currentUser?.id {
                                Button(action: {
                                    editedName = user.name // Pre-fill with current name
                                    showingEditNameSheet = true
                                }) {
                                    Text("Edit Name")
                                }
                            } else {
                                Button(action: {
                                    selectedUser = user
                                }) {
                                    Text("Edit Role")
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingRoomCodeSheet) {
            NavigationView {
                Form {
                    TextField("Room Code", text: $newRoomCode)
                }
                .navigationTitle("Enter Room Code")
                .navigationBarItems(
                    leading: Button("Cancel") { showingRoomCodeSheet = false },
                    trailing: Button("Save") {
                        appData.roomCode = newRoomCode
                        if let currentUser = appData.currentUser {
                            let updatedUser = User(id: currentUser.id, name: currentUser.name, isAdmin: currentUser.isAdmin)
                            appData.addUser(updatedUser)
                        }
                        showingRoomCodeSheet = false
                    }
                )
            }
        }
        .alert("Confirm New Room Code", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Confirm") {
                appData.roomCode = newRoomCode
                if let currentUser = appData.currentUser {
                    let updatedUser = User(id: currentUser.id, name: currentUser.name, isAdmin: currentUser.isAdmin)
                    appData.addUser(updatedUser)
                }
            }
        } message: {
            Text("This will switch to a new data set.")
        }
        .sheet(isPresented: $showingShareSheet) {
            ActivityViewController(activityItems: [
                "Join my TIPs App room: \(appData.roomCode ?? "No code available")\nDownload TIPs App: https://example.com/tipsapp"
            ])
        }
        .sheet(item: $selectedUser) { user in
            NavigationView {
                Form {
                    Text("User: \(user.name)")
                    Toggle("Admin Access", isOn: Binding(
                        get: { user.isAdmin },
                        set: { newValue in
                            let updatedUser = User(id: user.id, name: user.name, isAdmin: newValue)
                            appData.addUser(updatedUser)
                            selectedUser = nil
                        }
                    ))
                }
                .navigationTitle("Edit User Role")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { selectedUser = nil }
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditNameSheet) { // New sheet for editing name
            NavigationView {
                Form {
                    TextField("Your Name", text: $editedName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .navigationTitle("Edit Your Name")
                .navigationBarItems(
                    leading: Button("Cancel") { showingEditNameSheet = false },
                    trailing: Button("Save") {
                        if let currentUser = appData.currentUser, !editedName.isEmpty {
                            let updatedUser = User(id: currentUser.id, name: editedName, isAdmin: currentUser.isAdmin)
                            appData.addUser(updatedUser)
                            appData.currentUser = updatedUser // Update local currentUser
                        }
                        showingEditNameSheet = false
                    }
                    .disabled(editedName.isEmpty)
                )
            }
        }
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
