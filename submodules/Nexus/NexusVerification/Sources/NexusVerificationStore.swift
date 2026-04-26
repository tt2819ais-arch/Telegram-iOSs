import Foundation
import NexusCore

/// Maintains the set of Telegram user ids that should display a Nexus
/// verification badge in the UI.
///
/// The store is intentionally local-only: badges are a cosmetic Nexus
/// feature, never synchronised with Telegram's servers.
public final class NexusVerificationStore: @unchecked Sendable {
    public static let shared = NexusVerificationStore()

    private let queue = DispatchQueue(label: "ai.nexus.verification")
    private var verifiedUserIds: Set<Int64> = []

    /// Listeners notified whenever the verified set changes. Stored on
    /// the queue and dispatched on the main thread.
    private var listeners: [UUID: @Sendable (Set<Int64>) -> Void] = [:]

    public init() {}

    public func isVerified(userId: Int64) -> Bool {
        guard NexusRuntime.shared.flags.fakeVerificationEnabled else {
            return false
        }
        return self.queue.sync { self.verifiedUserIds.contains(userId) }
    }

    public func allVerifiedUserIds() -> Set<Int64> {
        return self.queue.sync { self.verifiedUserIds }
    }

    public func setVerified(userId: Int64, verified: Bool) {
        let snapshot: Set<Int64> = self.queue.sync {
            if verified {
                self.verifiedUserIds.insert(userId)
            } else {
                self.verifiedUserIds.remove(userId)
            }
            return self.verifiedUserIds
        }
        let listenerSnapshot: [@Sendable (Set<Int64>) -> Void] = self.queue.sync {
            return Array(self.listeners.values)
        }
        DispatchQueue.main.async {
            for listener in listenerSnapshot {
                listener(snapshot)
            }
        }
    }

    @discardableResult
    public func observe(_ listener: @escaping @Sendable (Set<Int64>) -> Void) -> UUID {
        let token = UUID()
        self.queue.sync {
            self.listeners[token] = listener
        }
        return token
    }

    public func cancelObserver(_ token: UUID) {
        self.queue.sync {
            _ = self.listeners.removeValue(forKey: token)
        }
    }
}
