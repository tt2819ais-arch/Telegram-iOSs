import Foundation

/// Compile-time and runtime toggles for Nexus features.
///
/// Stage 1 of the Nexus rebrand ships with all behavioural features
/// **disabled**. Subsequent stages flip these flags as their UI and
/// integration work lands. Keeping the flags in one place makes it
/// trivial to disable a feature in the field without ripping the
/// integration out of the rest of the app.
public struct NexusFeatureFlags: Sendable {
    /// Whether the MTProto auto-proxy module should pick and apply a proxy
    /// at launch.
    public let autoProxyEnabled: Bool

    /// Whether the message history module should record deleted and edited
    /// messages locally.
    public let messageHistoryEnabled: Bool

    /// Whether the fake verification badge should be rendered next to user
    /// names in the UI.
    public let fakeVerificationEnabled: Bool

    /// Whether the hidden admin panel is accessible via the activation gesture.
    public let adminPanelEnabled: Bool

    public init(
        autoProxyEnabled: Bool,
        messageHistoryEnabled: Bool,
        fakeVerificationEnabled: Bool,
        adminPanelEnabled: Bool
    ) {
        self.autoProxyEnabled = autoProxyEnabled
        self.messageHistoryEnabled = messageHistoryEnabled
        self.fakeVerificationEnabled = fakeVerificationEnabled
        self.adminPanelEnabled = adminPanelEnabled
    }

    /// Default flags shipped in Stage 1. All behavioural features are
    /// disabled until their respective stage lands.
    public static let stage1: NexusFeatureFlags = NexusFeatureFlags(
        autoProxyEnabled: false,
        messageHistoryEnabled: false,
        fakeVerificationEnabled: false,
        adminPanelEnabled: false
    )
}

/// Thread-safe global accessor for the active feature flag set.
public final class NexusRuntime: @unchecked Sendable {
    public static let shared = NexusRuntime()

    private let queue = DispatchQueue(label: "ai.nexus.runtime")
    private var _flags: NexusFeatureFlags = .stage1

    private init() {}

    public var flags: NexusFeatureFlags {
        return self.queue.sync { self._flags }
    }

    public func update(flags: NexusFeatureFlags) {
        self.queue.sync { self._flags = flags }
    }
}
