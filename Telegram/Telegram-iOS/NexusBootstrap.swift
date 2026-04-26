import Foundation
import NexusCore
import NexusAutoProxy
import NexusMessageHistory
import NexusVerification

/// Single entry point that wires up the Nexus modules during application
/// launch. Stage 1 only configures defaults — every Nexus feature flag
/// stays disabled until the corresponding stage lands.
@objc public final class NexusBootstrap: NSObject {
    @objc public static let shared = NexusBootstrap()

    @objc public private(set) var productName: String = NexusBranding.productName

    private let autoProxyController: NexusAutoProxyController

    private override init() {
        self.autoProxyController = NexusAutoProxyController()
        super.init()
    }

    @objc public func bootstrap() {
        NexusRuntime.shared.update(flags: .stage1)
        // Touch the singletons so the link-time symbols of every Nexus
        // module are referenced from the main app target. The instances
        // are no-ops at Stage 1.
        _ = NexusMessageHistoryStore.shared
        _ = NexusVerificationStore.shared
        self.autoProxyController.start()
    }
}
