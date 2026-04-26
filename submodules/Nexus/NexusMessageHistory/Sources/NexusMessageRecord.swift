import Foundation

/// A single recorded version of a message, captured before it was edited
/// or deleted on the server.
public struct NexusMessageRecord: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case deleted
        case edited
    }

    public let messageId: Int64
    public let peerId: Int64
    public let authorId: Int64
    public let text: String
    public let timestamp: Date
    public let kind: Kind

    public init(
        messageId: Int64,
        peerId: Int64,
        authorId: Int64,
        text: String,
        timestamp: Date,
        kind: Kind
    ) {
        self.messageId = messageId
        self.peerId = peerId
        self.authorId = authorId
        self.text = text
        self.timestamp = timestamp
        self.kind = kind
    }
}
