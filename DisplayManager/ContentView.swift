import SwiftUI
import AppKit
import CoreGraphics

struct DisplayProfile: Codable, Identifiable {
    var id = UUID()
    var name: String
    var arguments: [String]
    var idToDisplayType: [String: String]?

}

struct DisplayRect: Identifiable {
    let id = UUID()
    var origin: CGPoint
    var size: CGSize
    var displayName: String?
}

private extension String {
    func capturedGroups(withRegex pattern: String) -> [String]? {
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: self, range: NSRange(location: 0, length: (self as NSString).length))
        else { return nil }
        return (1..<match.numberOfRanges).compactMap {
            let range = match.range(at: $0)
            guard range.location != NSNotFound else { return nil }
            return (self as NSString).substring(with: range)
        }
    }
}

//private func parseDisplayRect(from token: String) -> DisplayRect? {
//    guard
//        let res = token.capturedGroups(withRegex: #"res:(\d+)x(\d+)"#),
//        let org = token.capturedGroups(withRegex: #"origin:\(([-\d]+),([-\d]+)\)"#),
//        let w = Double(res[0]), let h = Double(res[1]),
//        let x = Double(org[0]), let y = Double(org[1])
//    else { return nil }
//    let displayName = token.capturedGroups(withRegex: #"id:([A-F0-9-]+)"#)?[0] ?? "Display"
//    return DisplayRect(
//        origin: .init(x: x, y: y),
//        size: .init(width: w, height: h),
//        displayName: displayName
//    )
//}
private func parseDisplayRect(from token: String, idToType: [String: String]) -> DisplayRect? {
    guard
        let res = token.capturedGroups(withRegex: #"res:(\d+)x(\d+)"#),
        let org = token.capturedGroups(withRegex: #"origin:\(([-\d]+),([-\d]+)\)"#),
        let w = Double(res[0]), let h = Double(res[1]),
        let x = Double(org[0]), let y = Double(org[1])
    else { return nil }
    let id = token.capturedGroups(withRegex: #"id:([A-F0-9-]+)"#)?[0]
    let displayName = id.flatMap { idToType[$0] } ?? "Display"
    return DisplayRect(
        origin: .init(x: x, y: y),
        size: .init(width: w, height: h),
        displayName: displayName
    )
}

func parseDisplayTypes(from fullOutput: String) -> [String: String] {
    var result: [String: String] = [:]
    let blocks = fullOutput.components(separatedBy: "Persistent screen id:").dropFirst()
    for block in blocks {
        let trimmedBlock = block.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = trimmedBlock.capturedGroups(withRegex: #"^([A-F0-9-]+)"#)?.first
        let type = trimmedBlock.capturedGroups(withRegex: #"Type:\s*(.+)"#)?.first
        if let id, let type {
            result[id] = type
        }
    }
    return result
}



private func normalisedRects(from rects: [DisplayRect], target: CGSize) -> [(rect: CGRect, name: String)] {
    guard !rects.isEmpty else { return [] }
    let minX = rects.map { $0.origin.x }.min()!
    let minY = rects.map { $0.origin.y }.min()!
    let shifted = rects.map { r in
        CGRect(origin: .init(x: r.origin.x - minX, y: r.origin.y - minY), size: r.size)
    }
    let union = shifted.reduce(CGRect.zero) { $0.union($1) }
    let scale = min(target.width / union.width, target.height / union.height)
    let scaledUnion = CGRect(x: 0, y: 0, width: union.width * scale, height: union.height * scale)
    let offsetX = (target.width - scaledUnion.width) / 2
    let offsetY = (target.height - scaledUnion.height) / 2
    return zip(shifted, rects).map { (shiftedRect, originalRect) in
        let scaledRect = CGRect(
            x: shiftedRect.minX * scale + offsetX,
            y: shiftedRect.minY * scale + offsetY,
            width: shiftedRect.width * scale,
            height: shiftedRect.height * scale
        )
        let displayName = originalRect.displayName ?? "Display"
        return (rect: scaledRect, name: displayName)
    }
}

struct ArrangementPreview: View {

    let rectsWithNames: [(rect: CGRect, name: String)]
    let frameSize: CGSize
    var body: some View {
        ZStack {
            ForEach(rectsWithNames.indices, id: \.self) { i in
                let item = rectsWithNames[i]
                Rectangle()
                    .stroke(Color.accentColor, lineWidth: 1)
                    .background(Color.accentColor.opacity(0.15))
                    .frame(width: item.rect.width, height: item.rect.height)
                    .position(x: item.rect.midX, y: item.rect.midY)
                    .overlay(
                        VStack(spacing: 2) {
                            Text("\(i + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.primary)
                            Text(shortenDisplayName(item.name))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .position(x: item.rect.midX, y: item.rect.midY)
                    )
            }
        }
        .frame(width: frameSize.width, height: frameSize.height)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(4)
    }
    private func shortenDisplayName(_ name: String) -> String {
        if name.count > 8 && name.contains("-") {
            return String(name.prefix(8))
        }
        return name.count > 10 ? String(name.prefix(10)) + "..." : name
    }
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
    func popoverDidClose(_ notification: Notification) {
            print("Popover closed: \(notification.userInfo ?? [:])")
    }
    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            DispatchQueue.main.async {
                self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }

}

struct ContentView: View {
    @State private var showSaveDialog = false
    @State private var displayArguments: [String] = []
    @State private var displayplacerFullOutput: String? = nil
    @State private var profileName = ""
    @State private var savedProfiles: [DisplayProfile] = []
    @State private var selectedProfileID: UUID?
    @State private var showDeleteAlert = false
    @State private var profileToDelete: DisplayProfile?
    @State private var applyingProfileID: UUID?
    @State private var appliedProfileID: UUID?
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "display.2")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Display Manager").font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            Divider()
            Button(action: runDisplayplacerListAndCapture) {
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
                Button("Quit") { NSApplication.shared.terminate(nil) }
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
            selectedProfileID = savedProfiles.first?.id
        }
        .alert("Save as Profile", isPresented: $showSaveDialog) {
            TextField("Profile Name", text: $profileName)
            Button("Save") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.showSaveDialog = false
                    self.saveProfile(name: self.profileName, arguments: self.displayArguments)
                    self.profileName = ""
                    self.displayplacerFullOutput = nil
                    self.savedProfiles = self.loadProfiles()
                }
            }
            Button("Cancel", role: .cancel) { }
        }

        .alert("Error", isPresented: $showErrorAlert) {
                Button("OK") {
                    showErrorAlert = false
                    errorMessage = ""
                }
            } message: {
                Text(errorMessage)
            }
        .alert("Delete Profile", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let profile = profileToDelete { deleteProfile(profile) }
            }
            Button("Cancel", role: .cancel) { profileToDelete = nil }
        } message: {
            Text("Are you sure you want to delete '\(profileToDelete?.name ?? "")'?")
        }
    }
    
    private func runDisplayplacerListAndCapture() {
        guard let path = Bundle.main.path(forResource: "displayplacer", ofType: "") else {
            DispatchQueue.main.async {
                self.errorMessage = "displayplacer binary not found."
                self.showErrorAlert = true
            }
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
            process.waitUntilExit()  // Ensure completion before reading
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(decoding: data, as: UTF8.self)
            DispatchQueue.main.async {
                self.displayArguments = self.extractDisplayplacerCommand(from: output)
                self.displayplacerFullOutput = output
                self.showSaveDialog = true
            }
        } catch {
            DispatchQueue.main.async {
                print(error.localizedDescription)
                self.errorMessage = "Something went wrong!"
                self.showErrorAlert = true
            }
        }
    }

//    private func runDisplayplacerListAndCapture() {
//        guard let path = Bundle.main.path(forResource: "displayplacer", ofType: "") else {
//            print("❌ displayplacer binary not found")
//            return
//        }
//        let process = Process()
//        process.executableURL = URL(fileURLWithPath: path)
//        process.arguments = ["list"]
//        let pipe = Pipe()
//        process.standardOutput = pipe
//        process.standardError = pipe
//        do    { try process.run() }
//        catch { print("❌ Failed to run displayplacer: \(error)"); return }
//        process.terminationHandler = { _ in
//            let data = pipe.fileHandleForReading.readDataToEndOfFile()
//            let output = String(decoding: data, as: UTF8.self)
//            DispatchQueue.main.async {
//                self.displayArguments = self.extractDisplayplacerCommand(from: output)
//                self.displayplacerFullOutput = output
//                self.showSaveDialog = true
//            }
//        }
//    }
    private func extractDisplayplacerCommand(from output: String) -> [String] {
        output
            .components(separatedBy: .newlines)
            .compactMap { line -> [String]? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("displayplacer ") else { return nil }
                let argString = trimmed.replacingOccurrences(of: "displayplacer ", with: "")
                return parseDisplayplacerArguments(argString)
            }
            .first ?? []
    }
    private func parseDisplayplacerArguments(_ argString: String) -> [String] {
        var args: [String] = []
        var current = "", insideQuotes = false
        for char in argString {
            if char == "\""         { insideQuotes.toggle() }
            else if char == " " && !insideQuotes {
                if !current.isEmpty { args.append(current); current = "" }
            } else { current.append(char) }
        }
        if !current.isEmpty { args.append(current) }
        return args
    }
    private func appSupportURL() -> URL {
        let manager = FileManager.default
        let dir = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = dir.appendingPathComponent("DisplayManager")
        if !manager.fileExists(atPath: appDir.path) {
            try? manager.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        return appDir
    }
    private func getProfilesFileURL()        -> URL { appSupportURL().appendingPathComponent("profiles.json") }
    private func getAppliedProfileFileURL()  -> URL { appSupportURL().appendingPathComponent("applied_profile.json") }
    private func saveProfile(name: String, arguments: [String]) {
        let idToType = displayplacerFullOutput.map(parseDisplayTypes)
        let new = DisplayProfile(name: name, arguments: arguments, idToDisplayType: idToType)
        var profiles = loadProfiles()
        profiles.append(new)
        if let data = try? JSONEncoder().encode(profiles) {
            try? data.write(to: getProfilesFileURL())
            print("Profile saved to: \(getProfilesFileURL().path)")
        }
    }
    private func deleteProfile(_ profile: DisplayProfile) {
        var profiles = loadProfiles()
        profiles.removeAll { $0.id == profile.id }
        if let data = try? JSONEncoder().encode(profiles) {
            try? data.write(to: getProfilesFileURL())
            savedProfiles = profiles
            if selectedProfileID == profile.id { selectedProfileID = savedProfiles.first?.id }
            if appliedProfileID  == profile.id { appliedProfileID = nil; saveAppliedProfileID(nil) }
            print("✅ Profile deleted: \(profile.name)")
        }
    }
    private func executeProfile(_ profile: DisplayProfile) {
        guard let path = Bundle.main.path(forResource: "displayplacer", ofType: "") else {
            print("❌ displayplacer binary not found")
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { applyingProfileID = nil }
        } catch {
            print("❌ Failed to apply profile: \(error)")
            applyingProfileID = nil
        }
    }
    private func loadProfiles() -> [DisplayProfile] {
        guard
            let data = try? Data(contentsOf: getProfilesFileURL()),
            let profiles = try? JSONDecoder().decode([DisplayProfile].self, from: data)
        else { return [] }
        return profiles
    }
    private func saveAppliedProfileID(_ id: UUID?) {
        let url = getAppliedProfileFileURL()
        if let id = id {
            let data = try? JSONEncoder().encode(["appliedProfileID": id.uuidString])
            try? data?.write(to: url)
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }
    private func loadAppliedProfileID() -> UUID? {
        guard
            let data = try? Data(contentsOf: getAppliedProfileFileURL()),
            let dict = try? JSONDecoder().decode([String: String].self, from: data),
            let uuid = dict["appliedProfileID"]
        else { return nil }
        return UUID(uuidString: uuid)
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
    @State private var showPreview = false
    @State private var cachedRects: [(rect: CGRect, name: String)]? = nil
//    private var previewRectsWithNames: [(rect: CGRect, name: String)] {
//        let dRects = profile.arguments.compactMap(parseDisplayRect)
//        return normalisedRects(from: dRects, target: CGSize(width: 320, height: 200))
//    }
    private var previewRectsWithNames: [(rect: CGRect, name: String)] {
        if let cached = cachedRects {
            return cached
        }
        let idToType = profile.idToDisplayType ?? [:]
        let dRects = profile.arguments.compactMap { parseDisplayRect(from: $0, idToType: idToType) }
        let result = normalisedRects(from: dRects, target: CGSize(width: 320, height: 200))
        cachedRects = result
        return result
    }


    var body: some View {
        HStack(spacing: 8) {
            Button(action: {
//                print(profile.fullOutput)
                showPreview.toggle()
            }) {

                Image(systemName: "eye")
                    .foregroundColor(.primary)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Preview layout")
            .popover(isPresented: $showPreview) {
                ArrangementPreview(rectsWithNames: previewRectsWithNames, frameSize: CGSize(width: 320, height: 200))
                    .padding()
            }
            .onAppear {
                if cachedRects == nil {
                    let idToType = profile.idToDisplayType ?? [:]
                    let dRects = profile.arguments.compactMap { parseDisplayRect(from: $0, idToType: idToType) }
                    cachedRects = normalisedRects(from: dRects, target: CGSize(width: 320, height: 200))
                }
            }


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
                .fill(LinearGradient(gradient: Gradient(colors: [.clear, .white.opacity(0.6), .clear]), startPoint: .leading, endPoint: .trailing))
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
        .onTapGesture(perform: onSelect)
    }
}

