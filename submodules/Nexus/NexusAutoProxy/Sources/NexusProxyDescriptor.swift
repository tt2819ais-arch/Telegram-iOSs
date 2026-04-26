import Foundation

/// A single MTProto proxy entry, in the form Nexus consumes them.
///
/// Mirrors the shape of `MTSocksProxySettings` from MtProtoKit but lives
/// in a dependency-free module so that proxy lists can be parsed and
/// ranked without pulling in the network stack.
public struct NexusProxyDescriptor: Hashable, Codable, Sendable {
    public let host: String
    public let port: UInt16
    public let secret: Data

    public init(host: String, port: UInt16, secret: Data) {
        self.host = host
        self.port = port
        self.secret = secret
    }
}

/// Result of pinging a single proxy.
public struct NexusProxyPing: Hashable, Sendable {
    public let descriptor: NexusProxyDescriptor
    /// Round-trip latency in seconds, or `nil` if the proxy did not respond
    /// within the timeout window.
    public let latency: TimeInterval?

    public init(descriptor: NexusProxyDescriptor, latency: TimeInterval?) {
        self.descriptor = descriptor
        self.latency = latency
    }
}

/// Persisted state for the auto-proxy feature.
public struct NexusAutoProxyState: Codable, Sendable {
    public var proxies: [NexusProxyDescriptor]
    public var lastUpdate: Date?
    public var selected: NexusProxyDescriptor?

    public init(
        proxies: [NexusProxyDescriptor] = [],
        lastUpdate: Date? = nil,
        selected: NexusProxyDescriptor? = nil
    ) {
        self.proxies = proxies
        self.lastUpdate = lastUpdate
        self.selected = selected
    }
}
