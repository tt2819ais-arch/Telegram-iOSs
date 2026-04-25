import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext

private final class EnhancedFeaturesArchiveArguments {
    let removeEntry: (String) -> Void

    init(removeEntry: @escaping (String) -> Void) {
        self.removeEntry = removeEntry
    }
}

private enum EnhancedFeaturesArchiveSection: Int32 {
    case main
}

private struct DeletedArchiveEntry: ItemListNodeEntry {
    let index: Int
    let entry: ArchivedDeletedMessage

    var section: ItemListSectionId {
        return EnhancedFeaturesArchiveSection.main.rawValue
    }

    var stableId: Int32 {
        return Int32(self.index)
    }

    static func ==(lhs: DeletedArchiveEntry, rhs: DeletedArchiveEntry) -> Bool {
        return lhs.index == rhs.index && lhs.entry == rhs.entry
    }

    static func <(lhs: DeletedArchiveEntry, rhs: DeletedArchiveEntry) -> Bool {
        return lhs.entry.archivedTimestamp > rhs.entry.archivedTimestamp
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! EnhancedFeaturesArchiveArguments
        let title = !self.entry.text.isEmpty ? self.entry.text : (self.entry.mediaSummary ?? "(empty message)")
        let subtitle = formatArchiveSubtitle(authorName: self.entry.authorName, peerId: self.entry.peerId, timestamp: self.entry.messageTimestamp)
        let key = "\(self.entry.peerId):\(self.entry.namespace):\(self.entry.id)"
        return ItemListDisclosureItem(presentationData: presentationData, title: title, label: subtitle, sectionId: self.section, style: .blocks, action: {
            arguments.removeEntry(key)
        })
    }
}

private struct EditArchiveEntry: ItemListNodeEntry {
    let index: Int
    let entry: ArchivedMessageEdit

    var section: ItemListSectionId {
        return EnhancedFeaturesArchiveSection.main.rawValue
    }

    var stableId: Int32 {
        return Int32(self.index)
    }

    static func ==(lhs: EditArchiveEntry, rhs: EditArchiveEntry) -> Bool {
        return lhs.index == rhs.index && lhs.entry == rhs.entry
    }

    static func <(lhs: EditArchiveEntry, rhs: EditArchiveEntry) -> Bool {
        return lhs.entry.archivedTimestamp > rhs.entry.archivedTimestamp
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let title = "From: \(self.entry.previousText.prefix(80))"
        let subtitle = "To: \(self.entry.newText.prefix(80))"
        return ItemListDisclosureItem(presentationData: presentationData, title: title, label: subtitle, sectionId: self.section, style: .blocks, action: {
        })
    }
}

private func formatArchiveSubtitle(authorName: String?, peerId: Int64, timestamp: Int32) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .short
    dateFormatter.timeStyle = .short
    let dateString = dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    if let authorName = authorName {
        return "\(authorName) · \(dateString)"
    }
    return dateString
}

/// Builds the screen that lists every locally-archived deleted message,
/// most recent first, including author and timestamp metadata.
public func deletedMessagesArchiveController(context: AccountContext) -> ViewController {
    let archive = EnhancedFeaturesArchive.shared(basePath: context.account.postbox.mediaBox.basePath)
    let snapshotPromise = Promise<EnhancedFeaturesArchiveSnapshot>()
    snapshotPromise.set(archive.snapshot())

    let arguments = EnhancedFeaturesArchiveArguments(removeEntry: { key in
        let parts = key.split(separator: ":")
        guard parts.count == 3,
              let peerId = Int64(parts[0]),
              let namespace = Int32(parts[1]),
              let id = Int32(parts[2])
        else {
            return
        }
        archive.removeDeletedMessage(peerId: peerId, namespace: namespace, id: id)
        snapshotPromise.set(archive.snapshot())
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        snapshotPromise.get()
    )
    |> map { presentationData, snapshot -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Deleted messages"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let entries: [DeletedArchiveEntry] = snapshot.deletedMessages.enumerated().map { index, entry in
            return DeletedArchiveEntry(index: index, entry: entry)
        }
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            emptyStateItem: snapshot.deletedMessages.isEmpty ? ItemListTextEmptyStateItem(text: "No archived deleted messages yet.") : nil,
            animateChanges: false
        )
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    return controller
}

/// Builds the screen that lists every captured message edit, showing both the
/// previous and the new text. Most recent first.
public func editedMessagesHistoryController(context: AccountContext) -> ViewController {
    let archive = EnhancedFeaturesArchive.shared(basePath: context.account.postbox.mediaBox.basePath)
    let snapshotPromise = Promise<EnhancedFeaturesArchiveSnapshot>()
    snapshotPromise.set(archive.snapshot())

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        snapshotPromise.get()
    )
    |> map { presentationData, snapshot -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Edit history"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let entries: [EditArchiveEntry] = snapshot.editedMessages.enumerated().map { index, entry in
            return EditArchiveEntry(index: index, entry: entry)
        }
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            emptyStateItem: snapshot.editedMessages.isEmpty ? ItemListTextEmptyStateItem(text: "No archived edits yet.") : nil,
            animateChanges: false
        )
        return (controllerState, (listState, EnhancedFeaturesArchiveArguments(removeEntry: { _ in })))
    }

    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    return controller
}
