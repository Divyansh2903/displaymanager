
import SwiftUI

struct DisplayProfile: Codable, Identifiable {
    var id = UUID()
    var name: String
    var arguments: [String]
}

struct ContentView: View {
    @State private var showSaveDialog = false
    @State private var displayArguments: [String] = []
    @State private var profileName = ""
    @State private var savedProfiles: [DisplayProfile] = []
    @State private var selectedProfileID: UUID?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Display Manager")
                .font(.title)

            Button("Save Current Display Setup") {
                runDisplayplacerListAndCapture()
            }

            if !savedProfiles.isEmpty {
                Picker("Select Profile", selection: $selectedProfileID) {
                    ForEach(savedProfiles) { profile in
                        Text(profile.name).tag(profile.id as UUID?)
                    }
                }
                .pickerStyle(PopUpButtonPickerStyle())
                .frame(width: 200)

                Button("Apply Selected Profile") {
                    applySelectedProfile()
                }
            }
        }
        .frame(width: 300, height: 150)
        .padding()
        .onAppear {
            savedProfiles = loadProfiles()
            if let first = savedProfiles.first {
                selectedProfileID = first.id
            }
        }
        .alert("Save as Profile", isPresented: $showSaveDialog, actions: {
            TextField("Profile Name", text: $profileName)
            Button("Save") {
                saveProfile(name: profileName, arguments: displayArguments)
                profileName = ""
                savedProfiles = loadProfiles()
            }
            Button("Cancel", role: .cancel) { }
        })
    }
    
    func runDisplayplacerListAndCapture() {
        guard let path = Bundle.main.path(forResource: "displayplacer", ofType: "") else {
            print("❌ displayplacer binary not found in bundle")
            return
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["list"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
        } catch {
            print("❌ Failed to run displayplacer: \(error)")
            return
        }
        
        process.terminationHandler = { _ in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            DispatchQueue.main.async {
                self.displayArguments = self.extractDisplayplacerCommand(from: output)
                self.showSaveDialog = true
            }
        }
    }

    func extractDisplayplacerCommand(from output: String) -> [String] {
        let lines = output.components(separatedBy: .newlines)
        
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.hasPrefix("displayplacer ") {
            
                let argumentString = trimmedLine.replacingOccurrences(of: "displayplacer ", with: "")
                return parseDisplayplacerArguments(argumentString)
            }
        }
        
        return []
    }
    
    func parseDisplayplacerArguments(_ argumentString: String) -> [String] {
        var arguments: [String] = []
        var currentArg = ""
        var insideQuotes = false
        
        for char in argumentString {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == " " && !insideQuotes {
                if !currentArg.isEmpty {
                    arguments.append(currentArg)
                    currentArg = ""
                }
            } else {
                currentArg.append(char)
            }
        }
        
        if !currentArg.isEmpty {
            arguments.append(currentArg)
        }
        
        return arguments
    }
    
    func getProfilesFileURL() -> URL {
        let manager = FileManager.default
        let supportDir = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = supportDir.appendingPathComponent("DisplayManager")
        
        if !manager.fileExists(atPath: appDir.path) {
            try? manager.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        
        return appDir.appendingPathComponent("profiles.json")
    }
    
    func saveProfile(name: String, arguments: [String]) {
        let newProfile = DisplayProfile(name: name, arguments: arguments)
        var profiles = loadProfiles()
        profiles.append(newProfile)
        
        let url = getProfilesFileURL()
        if let data = try? JSONEncoder().encode(profiles) {
            try? data.write(to: url)
            print("✅ Profile saved: \(name)")
        }
    }
    
    func applySelectedProfile() {
        guard let id = selectedProfileID,
              let profile = savedProfiles.first(where: { $0.id == id }) else {
            print("❌ No profile selected")
            return
        }

        executeProfile(profile)
    }
    
    func executeProfile(_ profile: DisplayProfile) {
        guard let path = Bundle.main.path(forResource: "displayplacer", ofType: "") else {
            print("❌ displayplacer binary not found in bundle")
            return
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = profile.arguments
        
        do {
            try process.run()
            print("✅ Applied profile: \(profile.name)")
        } catch {
            print("❌ Failed to apply profile: \(error)")
        }
    }
    
    func loadProfiles() -> [DisplayProfile] {
        let url = getProfilesFileURL()
        if let data = try? Data(contentsOf: url),
           let profiles = try? JSONDecoder().decode([DisplayProfile].self, from: data) {
            return profiles
        }
        return []
    }
}
