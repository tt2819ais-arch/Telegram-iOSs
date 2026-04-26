import Foundation
import NexusCore

/// Local-only store for `NexusMessageRecord` entries.
///
/// The Stage 1 implementation keeps records in memory and never touches
/// disk. Stage 5 will replace the in-memory store with an SQLite-backed
/// implementation rooted under the Nexus app group container.
public final class NexusMessageHistoryStore: @unchecked Sendable {
    public static let shared = NexusMessageHistoryStore()

    private let queue = DispatchQueue(label: "ai.nexus.messageHistory")
    private var records: [Int64: [NexusMessageRecord]] = [:]

    public init() {}

    /// Append a new record for `messageId`. No-op when the message-history
    /// feature flag is disabled.
    public func append(_ record: NexusMessageRecord) {
        guard NexusRuntime.shared.flags.messageHistoryEnabled else {
            return
        }
        self.queue.sync {
            self.records[record.messageId, default: []].append(record)
        }
    }

    /// Return every recorded version of `messageId`, oldest first.
    public func versions(of messageId: Int64) -> [NexusMessageRecord] {
        return self.queue.sync { self.records[messageId] ?? [] }
    }

    /// Wipe the entire local history. Exposed in the Nexus settings screen.
    public func clear() {
        self.queue.sync { self.records.removeAll() }
    }
}
