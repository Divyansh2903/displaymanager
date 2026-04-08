import Foundation
import CoreGraphics

enum DisplayManagerError: LocalizedError {
    case processTimedOut(seconds: TimeInterval)
    case processFailed(code: Int32, details: String)
    case invalidDisplayplacerOutput
    case missingBundledBinary
    case invalidProfileName
    case duplicateProfileName
    case missingDisplays(screenIDs: [String])

    var errorDescription: String? {
        switch self {
        case .processTimedOut(let seconds):
            return "displayplacer timed out after \(Int(seconds)) seconds."
        case .processFailed(let code, let details):
            let trimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "displayplacer failed with exit code \(code)."
            }
            return "displayplacer failed with exit code \(code): \(trimmed)"
        case .invalidDisplayplacerOutput:
            return "Could not parse current display layout. Please try again."
        case .missingBundledBinary:
            return "displayplacer binary not found in app bundle."
        case .invalidProfileName:
            return "Please enter a profile name."
        case .duplicateProfileName:
            return "A profile with this name already exists."
        case .missingDisplays(let screenIDs):
            if screenIDs.isEmpty {
                return "Some displays from this profile are not currently connected. Reconnect them and try again, or save the current setup as a new profile."
            }
            let previewIDs = screenIDs.prefix(2).joined(separator: ", ")
            let suffix = screenIDs.count > 2 ? " (+\(screenIDs.count - 2) more)" : ""
            return "Some displays from this profile are not currently connected (\(previewIDs)\(suffix)). Reconnect them and try again, or save the current setup as a new profile."
        }
    }
}

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
    func capturedGroups(using regex: NSRegularExpression) -> [String]? {
        guard let match = regex.firstMatch(in: self, range: NSRange(location: 0, length: (self as NSString).length)) else {
            return nil
        }
        return (1..<match.numberOfRanges).compactMap {
            let range = match.range(at: $0)
            guard range.location != NSNotFound else { return nil }
            return (self as NSString).substring(with: range)
        }
    }
}

private enum RegexCache {
    static let displayRes = try! NSRegularExpression(pattern: #"res:\s*(\d+)x(\d+)"#)
    static let displayOrigin = try! NSRegularExpression(pattern: #"origin:\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)"#)
    static let displayID = try! NSRegularExpression(pattern: #"id:\s*([A-Fa-f0-9-]+)"#)
    static let screenID = try! NSRegularExpression(pattern: #"^([A-Fa-f0-9-]+)"#)
    static let displayType = try! NSRegularExpression(pattern: #"Type:\s*(.+)"#)
}

func parseDisplayRect(from token: String, idToType: [String: String]) -> DisplayRect? {
    guard
        let res = token.capturedGroups(using: RegexCache.displayRes),
        let org = token.capturedGroups(using: RegexCache.displayOrigin),
        let w = Double(res[0]), let h = Double(res[1]),
        let x = Double(org[0]), let y = Double(org[1])
    else { return nil }
    let id = token.capturedGroups(using: RegexCache.displayID)?[0]
    let displayName = id.flatMap { idToType[$0] } ?? "Display"
    return DisplayRect(origin: .init(x: x, y: y), size: .init(width: w, height: h), displayName: displayName)
}

func parseDisplayTypes(from fullOutput: String) -> [String: String] {
    var result: [String: String] = [:]
    let blocks = fullOutput.components(separatedBy: "Persistent screen id:").dropFirst()
    for block in blocks {
        let trimmedBlock = block.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = trimmedBlock.capturedGroups(using: RegexCache.screenID)?.first
        let type = trimmedBlock.capturedGroups(using: RegexCache.displayType)?.first
        if let id, let type {
            result[id] = type
        }
    }
    return result
}

func normalisedRects(from rects: [DisplayRect], target: CGSize) -> [(rect: CGRect, name: String)] {
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
        return (rect: scaledRect, name: originalRect.displayName ?? "Display")
    }
}

final class DisplayManagerService {
    func captureCurrentLayout() throws -> (arguments: [String], fullOutput: String) {
        let output = try runDisplayplacer(arguments: ["list"], timeout: 8)
        let arguments = extractDisplayplacerCommand(from: output)
        guard !arguments.isEmpty else { throw DisplayManagerError.invalidDisplayplacerOutput }
        return (arguments, output)
    }

    func applyProfile(_ profile: DisplayProfile) throws {
        _ = try runDisplayplacer(arguments: profile.arguments, timeout: 12)
    }

    func loadProfiles() throws -> [DisplayProfile] {
        do {
            let data = try Data(contentsOf: getProfilesFileURL())
            return try JSONDecoder().decode([DisplayProfile].self, from: data)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            return []
        }
    }

    func saveProfile(name: String, arguments: [String], fullOutput: String?) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw DisplayManagerError.invalidProfileName }

        var profiles = try loadProfiles()
        if profiles.contains(where: { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
            throw DisplayManagerError.duplicateProfileName
        }

        let idToType = fullOutput.map(parseDisplayTypes)
        let new = DisplayProfile(name: trimmedName, arguments: arguments, idToDisplayType: idToType)
        profiles.append(new)
        try saveProfiles(profiles)
    }

    func deleteProfile(_ profile: DisplayProfile) throws -> [DisplayProfile] {
        var profiles = try loadProfiles()
        profiles.removeAll { $0.id == profile.id }
        try saveProfiles(profiles)
        return profiles
    }

    func loadAppliedProfileID() throws -> UUID? {
        do {
            let data = try Data(contentsOf: getAppliedProfileFileURL())
            let dict = try JSONDecoder().decode([String: String].self, from: data)
            guard let uuid = dict["appliedProfileID"] else { return nil }
            return UUID(uuidString: uuid)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            return nil
        }
    }

    func saveAppliedProfileID(_ id: UUID?) throws {
        let url = try getAppliedProfileFileURL()
        if let id {
            let data = try JSONEncoder().encode(["appliedProfileID": id.uuidString])
            try data.write(to: url)
        } else {
            do {
                try FileManager.default.removeItem(at: url)
            } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError {
                return
            }
        }
    }

    private func appSupportURL() throws -> URL {
        let manager = FileManager.default
        let dir = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = dir.appendingPathComponent("DisplayManager")
        if !manager.fileExists(atPath: appDir.path) {
            try manager.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        return appDir
    }

    private func getProfilesFileURL() throws -> URL { try appSupportURL().appendingPathComponent("profiles.json") }
    private func getAppliedProfileFileURL() throws -> URL { try appSupportURL().appendingPathComponent("applied_profile.json") }

    private func saveProfiles(_ profiles: [DisplayProfile]) throws {
        let data = try JSONEncoder().encode(profiles)
        try data.write(to: getProfilesFileURL())
    }

    private func runDisplayplacer(arguments: [String], timeout: TimeInterval) throws -> String {
        guard let path = Bundle.main.path(forResource: "displayplacer", ofType: "") else {
            throw DisplayManagerError.missingBundledBinary
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }

        if process.isRunning {
            process.terminate()
            throw DisplayManagerError.processTimedOut(seconds: timeout)
        }

        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self)
        if process.terminationStatus != 0 {
            let missingIDs = extractMissingScreenIDs(from: output)
            if !missingIDs.isEmpty {
                throw DisplayManagerError.missingDisplays(screenIDs: missingIDs)
            }
            throw DisplayManagerError.processFailed(code: process.terminationStatus, details: output)
        }
        return output
    }

    private func extractMissingScreenIDs(from output: String) -> [String] {
        var ids: [String] = []
        let pattern = #"Unable to find screen\s+([A-Fa-f0-9-]{8,})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(output.startIndex..., in: output)
        let matches = regex.matches(in: output, range: range)
        for match in matches {
            guard
                let idRange = Range(match.range(at: 1), in: output)
            else { continue }
            let id = String(output[idRange]).uppercased()
            if !ids.contains(id) {
                ids.append(id)
            }
        }
        return ids
    }

    private func extractDisplayplacerCommand(from output: String) -> [String] {
        output
            .components(separatedBy: .newlines)
            .compactMap { line -> [String]? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("displayplacer ") else { return nil }
                return parseDisplayplacerArguments(trimmed.replacingOccurrences(of: "displayplacer ", with: ""))
            }
            .first ?? []
    }

    private func parseDisplayplacerArguments(_ argString: String) -> [String] {
        var args: [String] = []
        var current = ""
        var insideQuotes = false
        for char in argString {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == " " && !insideQuotes {
                if !current.isEmpty {
                    args.append(current)
                    current = ""
                }
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty {
            args.append(current)
        }
        return args
    }
}
