import Foundation
import Postbox
import SwiftSignalKit

/// A snapshot of a single message captured immediately before it was deleted on the server.
public struct ArchivedDeletedMessage: Codable, Equatable {
    public let peerId: Int64
    public let namespace: Int32
    public let id: Int32
    public let text: String
    public let messageTimestamp: Int32
    public let archivedTimestamp: Int32
    public let authorPeerId: Int64?
    public let authorName: String?
    public let mediaSummary: String?

    public init(peerId: Int64, namespace: Int32, id: Int32, text: String, messageTimestamp: Int32, archivedTimestamp: Int32, authorPeerId: Int64?, authorName: String?, mediaSummary: String?) {
        self.peerId = peerId
        self.namespace = namespace
        self.id = id
        self.text = text
        self.messageTimestamp = messageTimestamp
        self.archivedTimestamp = archivedTimestamp
        self.authorPeerId = authorPeerId
        self.authorName = authorName
        self.mediaSummary = mediaSummary
    }
}

/// A record of one message edit, capturing both the previous and the new text.
public struct ArchivedMessageEdit: Codable, Equatable {
    public let peerId: Int64
    public let namespace: Int32
    public let id: Int32
    public let previousText: String
    public let newText: String
    public let editTimestamp: Int32
    public let archivedTimestamp: Int32

    public init(peerId: Int64, namespace: Int32, id: Int32, previousText: String, newText: String, editTimestamp: Int32, archivedTimestamp: Int32) {
        self.peerId = peerId
        self.namespace = namespace
        self.id = id
        self.previousText = previousText
        self.newText = newText
        self.editTimestamp = editTimestamp
        self.archivedTimestamp = archivedTimestamp
    }
}

/// On-disk representation of all archived deleted messages and edits for one account.
public struct EnhancedFeaturesArchiveSnapshot: Codable, Equatable {
    public var deletedMessages: [ArchivedDeletedMessage]
    public var editedMessages: [ArchivedMessageEdit]

    public static var empty: EnhancedFeaturesArchiveSnapshot {
        return EnhancedFeaturesArchiveSnapshot(deletedMessages: [], editedMessages: [])
    }

    public init(deletedMessages: [ArchivedDeletedMessage], editedMessages: [ArchivedMessageEdit]) {
        self.deletedMessages = deletedMessages
        self.editedMessages = editedMessages
    }
}

/// Runtime flags read by the archiving hooks. Mirrors the user-facing toggles
/// in `EnhancedFeaturesSettings`. Persisted to a small sidecar file inside
/// `<basePath>/enhanced_features/runtime_flags_v1.json` so the hooks (which run
/// inside `TelegramCore` and cannot import `TelegramUIPreferences`) can honor
/// them without a module dependency.
public struct EnhancedFeaturesRuntimeFlags: Codable, Equatable {
    public var saveDeletedMessages: Bool
    public var saveEditedMessages: Bool

    public static var `default`: EnhancedFeaturesRuntimeFlags {
        return EnhancedFeaturesRuntimeFlags(saveDeletedMessages: true, saveEditedMessages: true)
    }

    public init(saveDeletedMessages: Bool, saveEditedMessages: Bool) {
        self.saveDeletedMessages = saveDeletedMessages
        self.saveEditedMessages = saveEditedMessages
    }
}

/// Thread-safe archive of deleted/edited messages, persisted as JSON next to
/// the account's media box. Use `shared(basePath:)` to obtain the per-account
/// instance; the same `basePath` always returns the same instance.
public final class EnhancedFeaturesArchive {
    private static let registryQueue = DispatchQueue(label: "EnhancedFeaturesArchive.registry")
    private static var registry: [String: EnhancedFeaturesArchive] = [:]

    public static let maxDeletedEntries: Int = 5000
    public static let maxEditEntries: Int = 5000

    public static func shared(basePath: String) -> EnhancedFeaturesArchive {
        return registryQueue.sync {
            if let existing = registry[basePath] {
                return existing
            }
            let archive = EnhancedFeaturesArchive(basePath: basePath)
            registry[basePath] = archive
            return archive
        }
    }

    private let queue: DispatchQueue
    private let directoryPath: String
    private let archivePath: String
    private let flagsPath: String
    private var loadedSnapshot: EnhancedFeaturesArchiveSnapshot?
    private let flagsLock = NSLock()
    private var cachedFlags: EnhancedFeaturesRuntimeFlags?

    private init(basePath: String) {
        self.queue = DispatchQueue(label: "EnhancedFeaturesArchive.\(basePath)")
        self.directoryPath = basePath + "/enhanced_features"
        self.archivePath = self.directoryPath + "/archive_v1.json"
        self.flagsPath = self.directoryPath + "/runtime_flags_v1.json"
    }

    /// Current runtime flags (saveDeletedMessages / saveEditedMessages).
    /// Lazily loads from disk on first access and caches the value.
    /// Safe to call from any thread; readers and writers use a single NSLock.
    public var currentFlags: EnhancedFeaturesRuntimeFlags {
        self.flagsLock.lock()
        if let cached = self.cachedFlags {
            self.flagsLock.unlock()
            return cached
        }
        self.flagsLock.unlock()
        let loaded: EnhancedFeaturesRuntimeFlags
        if let data = try? Data(contentsOf: URL(fileURLWithPath: self.flagsPath)),
           let decoded = try? JSONDecoder().decode(EnhancedFeaturesRuntimeFlags.self, from: data) {
            loaded = decoded
        } else {
            loaded = .default
        }
        self.flagsLock.lock()
        if let cached = self.cachedFlags {
            // A concurrent updateFlags() ran in the meantime; keep its value.
            self.flagsLock.unlock()
            return cached
        }
        self.cachedFlags = loaded
        self.flagsLock.unlock()
        return loaded
    }

    public func updateFlags(_ flags: EnhancedFeaturesRuntimeFlags) {
        self.flagsLock.lock()
        self.cachedFlags = flags
        self.flagsLock.unlock()
        self.queue.async {
            do {
                try FileManager.default.createDirectory(atPath: self.directoryPath, withIntermediateDirectories: true, attributes: nil)
                let data = try JSONEncoder().encode(flags)
                // Data.write(options: .atomic) already writes to a system temp file and renames
                // into place, so the destination is never absent during the swap.
                try data.write(to: URL(fileURLWithPath: self.flagsPath), options: .atomic)
            } catch {
            }
        }
    }

    private func loadLocked() -> EnhancedFeaturesArchiveSnapshot {
        if let snapshot = self.loadedSnapshot {
            return snapshot
        }
        if let data = try? Data(contentsOf: URL(fileURLWithPath: self.archivePath)),
           let decoded = try? JSONDecoder().decode(EnhancedFeaturesArchiveSnapshot.self, from: data) {
            self.loadedSnapshot = decoded
            return decoded
        }
        let empty = EnhancedFeaturesArchiveSnapshot.empty
        self.loadedSnapshot = empty
        return empty
    }

    private func persistLocked(_ snapshot: EnhancedFeaturesArchiveSnapshot) {
        self.loadedSnapshot = snapshot
        do {
            try FileManager.default.createDirectory(atPath: self.directoryPath, withIntermediateDirectories: true, attributes: nil)
            let data = try JSONEncoder().encode(snapshot)
            // Data.write(options: .atomic) already writes to a system temp file and renames
            // into place, so the destination is never absent during the swap.
            try data.write(to: URL(fileURLWithPath: self.archivePath), options: .atomic)
        } catch {
        }
    }

    public func appendDeletedMessages(_ entries: [ArchivedDeletedMessage]) {
        if entries.isEmpty {
            return
        }
        self.queue.async {
            var snapshot = self.loadLocked()
            snapshot.deletedMessages.append(contentsOf: entries)
            if snapshot.deletedMessages.count > EnhancedFeaturesArchive.maxDeletedEntries {
                let overflow = snapshot.deletedMessages.count - EnhancedFeaturesArchive.maxDeletedEntries
                snapshot.deletedMessages.removeFirst(overflow)
            }
            self.persistLocked(snapshot)
        }
    }

    public func appendEditedMessages(_ entries: [ArchivedMessageEdit]) {
        if entries.isEmpty {
            return
        }
        self.queue.async {
            var snapshot = self.loadLocked()
            snapshot.editedMessages.append(contentsOf: entries)
            if snapshot.editedMessages.count > EnhancedFeaturesArchive.maxEditEntries {
                let overflow = snapshot.editedMessages.count - EnhancedFeaturesArchive.maxEditEntries
                snapshot.editedMessages.removeFirst(overflow)
            }
            self.persistLocked(snapshot)
        }
    }

    public func snapshot() -> Signal<EnhancedFeaturesArchiveSnapshot, NoError> {
        return Signal { subscriber in
            self.queue.async {
                let snapshot = self.loadLocked()
                subscriber.putNext(snapshot)
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }

    public func clearAll() {
        self.queue.async {
            self.persistLocked(.empty)
        }
    }

    public func removeDeletedMessage(peerId: Int64, namespace: Int32, id: Int32) {
        self.queue.async {
            var snapshot = self.loadLocked()
            snapshot.deletedMessages.removeAll(where: { $0.peerId == peerId && $0.namespace == namespace && $0.id == id })
            self.persistLocked(snapshot)
        }
    }
}

/// Archive the messages identified by `ids` before they are wiped from the
/// postbox. Looks up each message via the supplied transaction and skips any
/// that cannot be resolved (already gone, secret chat, etc.). Becomes a no-op
/// when the user has disabled `saveDeletedMessages`.
public func archiveDeletedMessagesIfNeeded(transaction: Transaction, mediaBox: MediaBox, ids: [MessageId]) {
    if ids.isEmpty {
        return
    }
    let archive = EnhancedFeaturesArchive.shared(basePath: mediaBox.basePath)
    if !archive.currentFlags.saveDeletedMessages {
        return
    }
    var entries: [ArchivedDeletedMessage] = []
    let now = Int32(Date().timeIntervalSince1970)
    for id in ids {
        guard let message = transaction.getMessage(id) else {
            continue
        }
        let mediaSummary = enhancedFeaturesMediaSummary(for: message.media)
        let authorName: String? = message.author.flatMap { peer -> String? in
            let title = enhancedFeaturesPeerDisplayTitle(peer)
            return title.isEmpty ? nil : title
        }
        let entry = ArchivedDeletedMessage(
            peerId: id.peerId.toInt64(),
            namespace: id.namespace,
            id: id.id,
            text: message.text,
            messageTimestamp: message.timestamp,
            archivedTimestamp: now,
            authorPeerId: message.author?.id.toInt64(),
            authorName: authorName,
            mediaSummary: mediaSummary
        )
        entries.append(entry)
    }
    if !entries.isEmpty {
        archive.appendDeletedMessages(entries)
    }
}

/// Archive the previous version of `id` before its text is overwritten by
/// `newMessage`. The edit timestamp is read from the new message's
/// `EditedMessageAttribute` if present. Becomes a no-op when the user has
/// disabled `saveEditedMessages` or when the text has not actually changed.
public func archiveMessageEditIfNeeded(transaction: Transaction, mediaBox: MediaBox, id: MessageId, newMessage: StoreMessage) {
    let archive = EnhancedFeaturesArchive.shared(basePath: mediaBox.basePath)
    if !archive.currentFlags.saveEditedMessages {
        return
    }
    guard let previousMessage = transaction.getMessage(id) else {
        return
    }
    let newText = newMessage.text
    if previousMessage.text == newText {
        return
    }
    let now = Int32(Date().timeIntervalSince1970)
    let editTimestamp: Int32
    if let editAttribute = newMessage.attributes.compactMap({ $0 as? EditedMessageAttribute }).first {
        editTimestamp = editAttribute.date
    } else {
        editTimestamp = now
    }
    let entry = ArchivedMessageEdit(
        peerId: id.peerId.toInt64(),
        namespace: id.namespace,
        id: id.id,
        previousText: previousMessage.text,
        newText: newText,
        editTimestamp: editTimestamp,
        archivedTimestamp: now
    )
    archive.appendEditedMessages([entry])
}

private func enhancedFeaturesMediaSummary(for media: [Media]) -> String? {
    if media.isEmpty {
        return nil
    }
    var components: [String] = []
    for item in media {
        let typeName = String(describing: type(of: item))
        components.append(typeName)
    }
    return components.joined(separator: ", ")
}

private func enhancedFeaturesPeerDisplayTitle(_ peer: Peer) -> String {
    switch peer.indexName {
    case let .title(title, _):
        return title
    case let .personName(first, last, _, _):
        let trimmed = "\(first) \(last)".trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed
    }
}
