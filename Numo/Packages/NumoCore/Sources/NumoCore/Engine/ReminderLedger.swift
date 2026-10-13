import Foundation

/// Persistent memory of what has already been shown, snoozed or acted on. It is what stops a
/// relaunch, a wake or a calendar refresh from alerting twice, and what makes snoozes survive.
///
/// Two layers:
/// - per-reminder state (`presented`, `snoozed`, `expired`), keyed by occurrence + lead time
/// - per-occurrence resolution (`joined`, `dismissed`), which silences every reminder of the meeting
public struct ReminderLedger: Codable, Sendable, Equatable {
    public enum ReminderState: Codable, Sendable, Equatable {
        case presented
        case snoozed(until: Date)
        case expired
    }

    public enum Resolution: String, Codable, Sendable {
        case joined
        case dismissed
    }

    private struct ReminderEntry: Codable, Equatable {
        var key: ReminderKey
        var state: ReminderState
        var meetingEnd: Date
    }

    private struct ResolutionEntry: Codable, Equatable {
        var occurrence: OccurrenceKey
        var resolution: Resolution
        var meetingEnd: Date
    }

    public static let currentVersion = 1

    private var reminders: [ReminderKey: ReminderEntry] = [:]
    private var resolutions: [OccurrenceKey: ResolutionEntry] = [:]

    public init() {}

    public var isEmpty: Bool { reminders.isEmpty && resolutions.isEmpty }

    public func state(for key: ReminderKey) -> ReminderState? {
        reminders[key]?.state
    }

    public func resolution(for occurrence: OccurrenceKey) -> Resolution? {
        resolutions[occurrence]?.resolution
    }

    public mutating func setState(_ state: ReminderState, for key: ReminderKey, meetingEnd: Date) {
        reminders[key] = ReminderEntry(key: key, state: state, meetingEnd: meetingEnd)
    }

    public mutating func resolve(_ occurrence: OccurrenceKey, as resolution: Resolution, meetingEnd: Date) {
        resolutions[occurrence] = ResolutionEntry(occurrence: occurrence, resolution: resolution, meetingEnd: meetingEnd)
    }

    /// Drops everything about meetings that ended before `cutoff`.
    public mutating func prune(before cutoff: Date) {
        reminders = reminders.filter { $0.value.meetingEnd >= cutoff }
        resolutions = resolutions.filter { $0.value.meetingEnd >= cutoff }
    }

    // MARK: Codable (dictionaries with struct keys are stored as arrays of entries)

    private enum CodingKeys: String, CodingKey {
        case version, reminders, resolutions
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let reminderEntries = try c.decodeIfPresent([ReminderEntry].self, forKey: .reminders) ?? []
        let resolutionEntries = try c.decodeIfPresent([ResolutionEntry].self, forKey: .resolutions) ?? []
        reminders = Dictionary(reminderEntries.map { ($0.key, $0) }, uniquingKeysWith: { _, new in new })
        resolutions = Dictionary(resolutionEntries.map { ($0.occurrence, $0) }, uniquingKeysWith: { _, new in new })
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.currentVersion, forKey: .version)
        try c.encode(Array(reminders.values), forKey: .reminders)
        try c.encode(Array(resolutions.values), forKey: .resolutions)
    }
}

public protocol LedgerStore: Sendable {
    func load() async -> ReminderLedger
    func save(_ ledger: ReminderLedger) async
}

/// JSON file store. A missing or corrupt file yields an empty ledger instead of a crash:
/// at worst a just-shown reminder may appear once more, never a silent failure to start.
public struct FileLedgerStore: LedgerStore {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func load() async -> ReminderLedger {
        guard let data = try? Data(contentsOf: url) else { return ReminderLedger() }
        return (try? JSONDecoder().decode(ReminderLedger.self, from: data)) ?? ReminderLedger()
    }

    public func save(_ ledger: ReminderLedger) async {
        guard let data = try? JSONEncoder().encode(ledger) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
