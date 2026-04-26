import Foundation
import NexusCore

/// Entry point used by the application launch sequence to wire up the
/// auto-proxy feature. The Stage 1 implementation is intentionally inert
/// — it merely records that the controller was instantiated and reads the
/// feature flag. The full pipeline (list fetch, ping, selection, fallback)
/// is implemented in Stage 2.
public final class NexusAutoProxyController {
    public struct Configuration: Sendable {
        /// URL of the JSON list of proxies. The default points at a
        /// well-known community-maintained list and can be overridden at
        /// runtime via the Nexus settings screen.
        public let proxyListURL: URL
        /// How often the list should be refreshed in the background.
        public let refreshInterval: TimeInterval

        public init(
            proxyListURL: URL,
            refreshInterval: TimeInterval = 6 * 60 * 60
        ) {
            self.proxyListURL = proxyListURL
            self.refreshInterval = refreshInterval
        }

        public static let `default`: Configuration = Configuration(
            proxyListURL: URL(string: "https://mtpro.xyz/api/?type=mtproto")!,
            refreshInterval: 6 * 60 * 60
        )
    }

    public let configuration: Configuration
    public private(set) var state: NexusAutoProxyState

    public init(configuration: Configuration = .default) {
        self.configuration = configuration
        self.state = NexusAutoProxyState()
    }

    /// Boot the auto-proxy controller. Returns immediately when the feature
    /// is disabled (Stage 1 default). Stage 2 will kick off the refresh
    /// pipeline here.
    public func start() {
        guard NexusRuntime.shared.flags.autoProxyEnabled else {
            return
        }
        // Stage 2: schedule list fetch + ping + selection.
    }

    /// Force a refresh of the proxy list. Stage 1: no-op.
    public func refresh() {
        // Stage 2: download `configuration.proxyListURL`, parse, ping all,
        // pick the fastest, persist to disk, apply via TelegramCore.
    }

    /// Apply a specific proxy. Stage 1: no-op.
    public func apply(_ descriptor: NexusProxyDescriptor) {
        _ = descriptor
        // Stage 2: bridge through to MtProtoKit.
    }
}
