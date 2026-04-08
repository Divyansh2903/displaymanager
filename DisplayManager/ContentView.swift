import SwiftUI
import AppKit
import CoreGraphics

struct ArrangementPreview: View {
    let rectsWithNames: [(rect: CGRect, name: String)]
    let frameSize: CGSize

    var body: some View {
        ZStack {
            ForEach(rectsWithNames.indices, id: \.self) { i in
                let item = rectsWithNames[i]
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.accentColor.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 1.5)
                    )
                    .frame(width: item.rect.width, height: item.rect.height)
                    .position(x: item.rect.midX, y: item.rect.midY)
                    .overlay(
                        VStack(spacing: 2) {
                            Text("\(i + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.primary)
                            Text(shortenDisplayName(item.name))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .position(x: item.rect.midX, y: item.rect.midY)
                    )
            }
        }
        .frame(width: frameSize.width, height: frameSize.height)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func shortenDisplayName(_ name: String) -> String {
        if name.count > 8 && name.contains("-") {
            return String(name.prefix(8))
        }
        return name.count > 10 ? String(name.prefix(10)) + "…" : name
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.applicationIconImage = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "display.2", accessibilityDescription: "Display Manager")
            button.action = #selector(togglePopover)
            button.target = self
        }
        popover = NSPopover()
        popover.contentViewController = NSHostingController(rootView: ContentView())
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 440)
        NSApp.setActivationPolicy(.accessory)
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
    private let service = DisplayManagerService()
    @State private var showSaveDialog = false
    @State private var displayArguments: [String] = []
    @State private var displayplacerFullOutput: String? = nil
    @State private var profileName = ""
    @State private var savedProfiles: [DisplayProfile] = []
    @State private var showDeleteAlert = false
    @State private var profileToDelete: DisplayProfile?
    @State private var applyingProfileID: UUID?
    @State private var appliedProfileID: UUID?
    @State private var isApplyingAnyProfile = false
    @State private var isCapturingLayout = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            saveButton
                .padding(.horizontal, 16)
                .padding(.top, 16)
            profileSection
                .padding(.top, 16)
            Spacer(minLength: 0)
            Divider()
            footer
        }
        .frame(width: 320)
        .padding(.vertical, 12)
        .onAppear {
            do {
                savedProfiles = try service.loadProfiles()
                appliedProfileID = try service.loadAppliedProfileID()
            } catch {
                presentError(error)
            }
        }
        .alert("Name This Profile", isPresented: $showSaveDialog) {
            TextField("e.g. Work – Dual Monitor", text: $profileName)
            Button("Save") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.showSaveDialog = false
                    do {
                        try service.saveProfile(
                            name: self.profileName,
                            arguments: self.displayArguments,
                            fullOutput: self.displayplacerFullOutput
                        )
                    } catch {
                        self.presentError(error)
                    }
                    self.profileName = ""
                    self.clearCaptureBuffers()
                    do {
                        self.savedProfiles = try self.service.loadProfiles()
                    } catch {
                        self.presentError(error)
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                clearCaptureBuffers()
            }
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
            Text("Delete \"\(profileToDelete?.name ?? "")\"? This cannot be undone.")
        }
        .dialogIcon(Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "display.2")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text("Display Manager")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .padding(.top, 4)
    }

    private var saveButton: some View {
        Button(action: runDisplayplacerListAndCapture) {
            HStack(spacing: 6) {
                if isCapturingLayout {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(isCapturingLayout ? "Capturing..." : "Save Current Layout")
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(.white)
            .background(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: Color.accentColor.opacity(0.2), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .disabled(isCapturingLayout || isApplyingAnyProfile)
    }

    @ViewBuilder
    private var profileSection: some View {
        if savedProfiles.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Saved Profiles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                    if let appliedID = appliedProfileID,
                       let name = savedProfiles.first(where: { $0.id == appliedID })?.name {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 6, height: 6)
                            Text(name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)

                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(savedProfiles) { profile in
                            ProfileRow(
                                profile: profile,
                                isApplying: applyingProfileID == profile.id,
                                isApplied: appliedProfileID == profile.id,
                                isInteractionDisabled: isApplyingAnyProfile || isCapturingLayout,
                                onApply: {
                                    guard !isApplyingAnyProfile else { return }
                                    isApplyingAnyProfile = true
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
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
                .frame(maxHeight: 260)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "display.trianglebadge.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            VStack(spacing: 6) {
                Text("No Profiles Yet")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Save your current display setup\nto get started.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var footer: some View {
        HStack {
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.red.opacity(0.9))
            Spacer()
            Text("v1.1")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private func runDisplayplacerListAndCapture() {
        guard !isCapturingLayout else { return }
        isCapturingLayout = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try service.captureCurrentLayout()
                DispatchQueue.main.async {
                    self.displayArguments = result.arguments
                    self.displayplacerFullOutput = result.fullOutput
                    self.showSaveDialog = true
                    self.isCapturingLayout = false
                }
            } catch {
                DispatchQueue.main.async { self.isCapturingLayout = false }
                presentError(error)
            }
        }
    }

    private func clearCaptureBuffers() {
        displayArguments = []
        displayplacerFullOutput = nil
    }

    private func presentError(_ error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = error.localizedDescription
            self.showErrorAlert = true
        }
    }

    private func deleteProfile(_ profile: DisplayProfile) {
        do {
            let profiles = try service.deleteProfile(profile)
            savedProfiles = profiles
            if appliedProfileID == profile.id {
                appliedProfileID = nil
                try service.saveAppliedProfileID(nil)
            }
        } catch {
            presentError(error)
        }
    }

    private func executeProfile(_ profile: DisplayProfile) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try service.applyProfile(profile)
                DispatchQueue.main.async {
                    appliedProfileID = profile.id
                    do {
                        try service.saveAppliedProfileID(profile.id)
                    } catch {
                        presentError(error)
                    }
                    applyingProfileID = nil
                    isApplyingAnyProfile = false
                }
            } catch {
                DispatchQueue.main.async {
                    applyingProfileID = nil
                    isApplyingAnyProfile = false
                }
                presentError(error)
            }
        }
    }
}

struct ProfileRow: View {
    let profile: DisplayProfile
    let isApplying: Bool
    let isApplied: Bool
    let isInteractionDisabled: Bool
    let onApply: () -> Void
    let onDelete: () -> Void

    @State private var showPreview = false
    @State private var isHovering = false
    @State private var isLoadingPreview = false
    @State private var cachedRects: [(rect: CGRect, name: String)] = []
    @State private var shimmerOffset: CGFloat = -200
    @State private var previewCleanupWorkItem: DispatchWorkItem?

    var body: some View {
        HStack(spacing: 12) {
            Button {
                showPreview.toggle()
            } label: {
                Image(systemName: showPreview ? "eye.fill" : "eye")
                    .font(.system(size: 14))
                    .foregroundStyle(isHovering ? .primary : .secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Preview layout")
            .popover(isPresented: $showPreview, arrowEdge: .trailing) {
                Group {
                    if isLoadingPreview {
                        VStack(spacing: 10) {
                            ProgressView()
                                .controlSize(.regular)
                            Text("Loading preview...")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 300, height: 180)
                    } else if cachedRects.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "display")
                                .font(.system(size: 18))
                                .foregroundStyle(.tertiary)
                            Text("Preview unavailable")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 300, height: 180)
                    } else {
                        ArrangementPreview(
                            rectsWithNames: cachedRects,
                            frameSize: CGSize(width: 300, height: 180)
                        )
                    }
                }
                .padding(12)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(profile.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isApplied ? Color.accentColor : .primary)
                }
                Text("\(profile.arguments.count) display\(profile.arguments.count == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                if isApplying {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                } else if isApplied {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 16, height: 16)
                } else if isHovering {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 16, height: 16)
                }

                if isHovering {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundStyle(.red.opacity(0.8))
                            .frame(width: 16, height: 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Delete profile")
                    .disabled(isApplying || isInteractionDisabled)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(rowBackground)
        .overlay(shimmer)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            if !isApplying && !isApplied && !isInteractionDisabled {
                onApply()
            }
        }
        .onChange(of: showPreview) { _, isOpen in
            if isOpen && cachedRects.isEmpty {
                previewCleanupWorkItem?.cancel()
                previewCleanupWorkItem = nil
                loadPreviewIfNeeded()
            } else if !isOpen {
                schedulePreviewCacheCleanup()
            }
        }
        .onChange(of: isApplying) { _, applying in
            if applying {
                shimmerOffset = -200
                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    shimmerOffset = 300
                }
            } else {
                withAnimation(.default) {
                    shimmerOffset = -200
                }
            }
        }
    }

    private func loadPreviewIfNeeded() {
        guard !isLoadingPreview, cachedRects.isEmpty else { return }
        isLoadingPreview = true
        let args = profile.arguments
        let idToType = profile.idToDisplayType ?? [:]

        DispatchQueue.global(qos: .userInitiated).async {
            let dRects = args.compactMap { parseDisplayRect(from: $0, idToType: idToType) }
            let normalized = normalisedRects(from: dRects, target: CGSize(width: 300, height: 180))
            DispatchQueue.main.async {
                cachedRects = normalized
                isLoadingPreview = false
            }
        }
    }

    private func schedulePreviewCacheCleanup() {
        previewCleanupWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            if !showPreview {
                cachedRects = []
            }
        }
        previewCleanupWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: workItem)
    }

    @ViewBuilder
    private var rowBackground: some View {
        let fillColor = isApplied ? Color.accentColor.opacity(0.12) : (isHovering ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04))
        let strokeColor = isApplied ? Color.accentColor.opacity(0.3) : (isHovering ? Color.primary.opacity(0.1) : Color.clear)
        
        RoundedRectangle(cornerRadius: 8)
            .fill(fillColor)
            .background {
                if isApplied {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.thickMaterial)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(strokeColor, lineWidth: 1)
            )
    }

    @ViewBuilder
    private var shimmer: some View {
        if isApplying {
            LinearGradient(
                colors: [.clear, .white.opacity(0.3), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 60)
            .offset(x: shimmerOffset)
            .blendMode(.plusLighter)
        }
    }
}
