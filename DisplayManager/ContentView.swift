import SwiftUI
import AppKit

struct DisplayProfile: Codable, Identifiable {
    var id = UUID()
    var name: String
    var arguments: [String]
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "display.2", accessibilityDescription: "Display Manager")
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        popover = NSPopover()
        popover.contentViewController = NSHostingController(rootView: ContentView())
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 280, height: 400)
        
        NSApp.setActivationPolicy(.accessory)
    }
    
    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}

struct ContentView: View {
    @State private var showSaveDialog = false
    @State private var displayArguments: [String] = []
    @State private var profileName = ""
    @State private var savedProfiles: [DisplayProfile] = []
    @State private var selectedProfileID: UUID?
    @State private var showDeleteAlert = false
    @State private var profileToDelete: DisplayProfile?
    @State private var applyingProfileID: UUID?
    @State private var appliedProfileID: UUID?
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "display.2")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Display Manager")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            
            Divider()
            
            Button(action: {
                runDisplayplacerListAndCapture()
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Save Current Setup")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
            
            if !savedProfiles.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Saved Profiles")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let appliedID = appliedProfileID,
                           let appliedProfile = savedProfiles.first(where: { $0.id == appliedID }) {
                            Spacer()
                            Text("Applied: \(appliedProfile.name)")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.horizontal)
                    
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(savedProfiles) { profile in
                                ProfileRow(
                                    profile: profile,
                                    isSelected: selectedProfileID == profile.id,
                                    isApplying: applyingProfileID == profile.id,
                                    isApplied: appliedProfileID == profile.id,
                                    onSelect: { selectedProfileID = profile.id },
                                    onApply: {
                                        applyingProfileID = profile.id
                                        executeProfile(profile)
                                    },
                                    onDelete: {
                                        profileToDelete = profile
                                        showDeleteAlert = true
                                    }
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "display.trianglebadge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No profiles saved")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Save your current display setup to get started")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            
            Divider()
            
            HStack {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.red)
                
                Spacer()
                
                Text("v1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
        .frame(width: 280)
        .padding(.vertical)
        .onAppear {
            savedProfiles = loadProfiles()
            appliedProfileID = loadAppliedProfileID()
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
        .alert("Delete Profile", isPresented: $showDeleteAlert, actions: {
            Button("Delete", role: .destructive) {
                if let profile = profileToDelete {
                    deleteProfile(profile)
                    profileToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                profileToDelete = nil
            }
        }, message: {
            Text("Are you sure you want to delete '\(profileToDelete?.name ?? "")'?")
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
    
    func getAppliedProfileFileURL() -> URL {
        let manager = FileManager.default
        let supportDir = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = supportDir.appendingPathComponent("DisplayManager")
        
        if !manager.fileExists(atPath: appDir.path) {
            try? manager.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        
        return appDir.appendingPathComponent("applied_profile.json")
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
    
    func deleteProfile(_ profile: DisplayProfile) {
        var profiles = loadProfiles()
        profiles.removeAll { $0.id == profile.id }
        
        let url = getProfilesFileURL()
        if let data = try? JSONEncoder().encode(profiles) {
            try? data.write(to: url)
            print("✅ Profile deleted: \(profile.name)")
            savedProfiles = profiles
            
            if selectedProfileID == profile.id {
                selectedProfileID = savedProfiles.first?.id
            }
            
            
            if appliedProfileID == profile.id {
                appliedProfileID = nil
                saveAppliedProfileID(nil)
            }
        }
    }
    
    func executeProfile(_ profile: DisplayProfile) {
        guard let path = Bundle.main.path(forResource: "displayplacer", ofType: "") else {
            print("❌ displayplacer binary not found in bundle")
            applyingProfileID = nil
            return
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = profile.arguments
        
        do {
            try process.run()
            print("✅ Applied profile: \(profile.name)")
            
            
            appliedProfileID = profile.id
            saveAppliedProfileID(profile.id)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                applyingProfileID = nil
            }
        } catch {
            print("❌ Failed to apply profile: \(error)")
            applyingProfileID = nil
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
    
    func saveAppliedProfileID(_ profileID: UUID?) {
        let url = getAppliedProfileFileURL()
        if let profileID = profileID {
            let data = try? JSONEncoder().encode(["appliedProfileID": profileID.uuidString])
            try? data?.write(to: url)
        } else {
            
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    func loadAppliedProfileID() -> UUID? {
        let url = getAppliedProfileFileURL()
        if let data = try? Data(contentsOf: url),
           let dict = try? JSONDecoder().decode([String: String].self, from: data),
           let uuidString = dict["appliedProfileID"] {
            return UUID(uuidString: uuidString)
        }
        return nil
    }
}

struct ProfileRow: View {
    let profile: DisplayProfile
    let isSelected: Bool
    let isApplying: Bool
    let isApplied: Bool
    let onSelect: () -> Void
    let onApply: () -> Void
    let onDelete: () -> Void
    
    @State private var loadingOffset: CGFloat = -300
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(profile.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    
                    if isApplied {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Text("\(profile.arguments.count) display\(profile.arguments.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Button(action: onApply) {
                    if isApplying {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: isApplied ? "checkmark" : "play.fill")
                            .font(.caption)
                            .foregroundColor(isApplied ? .green : .blue)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .help(isApplied ? "Currently applied" : "Apply profile")
                .disabled(isApplying)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Delete profile")
                .disabled(isApplying)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isApplied ? Color.green.opacity(0.1) : Color.gray.opacity(0.05))
        .cornerRadius(6)
        .contentShape(Rectangle())
        .padding(.horizontal, 4)
        .overlay(
            Rectangle()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [.clear, .white.opacity(0.6), .clear]),
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(width: 50)
                .offset(x: loadingOffset)
                .opacity(isApplying ? 1 : 0)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false), value: isApplying)
        )
        .onChange(of: isApplying) { applying in
            if applying {
                loadingOffset = -300
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    loadingOffset = 300
                }
            } else {
                loadingOffset = -300
            }
        }
    }
}
