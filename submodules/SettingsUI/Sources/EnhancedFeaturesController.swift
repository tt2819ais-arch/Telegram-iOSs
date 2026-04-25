import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext

private final class EnhancedFeaturesControllerArguments {
    let updateSetting: (EnhancedFeatureToggle, Bool) -> Void
    let openArchive: () -> Void
    let openEditHistory: () -> Void
    let clearArchive: () -> Void

    init(
        updateSetting: @escaping (EnhancedFeatureToggle, Bool) -> Void,
        openArchive: @escaping () -> Void,
        openEditHistory: @escaping () -> Void,
        clearArchive: @escaping () -> Void
    ) {
        self.updateSetting = updateSetting
        self.openArchive = openArchive
        self.openEditHistory = openEditHistory
        self.clearArchive = clearArchive
    }
}

public enum EnhancedFeatureToggle {
    case saveDeletedMessages
    case saveEditedMessages
    case antiRecall
    case stealthRead
    case ghostMode
    case autoSaveViewOnceMedia
    case trackContactNameAndAvatarHistory
}

private enum EnhancedFeaturesSection: Int32 {
    case privacy
    case archive
    case advanced
    case actions
}

private enum EnhancedFeaturesEntry: ItemListNodeEntry {
    case privacyHeader
    case toggleSaveDeleted(Bool)
    case toggleSaveEdited(Bool)
    case toggleAntiRecall(Bool)
    case privacyFooter

    case archiveHeader
    case openDeletedArchive(Int)
    case openEditHistory(Int)
    case archiveFooter

    case advancedHeader
    case toggleStealthRead(Bool)
    case toggleGhostMode(Bool)
    case toggleAutoSaveViewOnce(Bool)
    case toggleTrackHistory(Bool)
    case advancedFooter

    case actionsHeader
    case clearArchive
    case actionsFooter

    var section: ItemListSectionId {
        switch self {
        case .privacyHeader, .toggleSaveDeleted, .toggleSaveEdited, .toggleAntiRecall, .privacyFooter:
            return EnhancedFeaturesSection.privacy.rawValue
        case .archiveHeader, .openDeletedArchive, .openEditHistory, .archiveFooter:
            return EnhancedFeaturesSection.archive.rawValue
        case .advancedHeader, .toggleStealthRead, .toggleGhostMode, .toggleAutoSaveViewOnce, .toggleTrackHistory, .advancedFooter:
            return EnhancedFeaturesSection.advanced.rawValue
        case .actionsHeader, .clearArchive, .actionsFooter:
            return EnhancedFeaturesSection.actions.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .privacyHeader: return 0
        case .toggleSaveDeleted: return 1
        case .toggleSaveEdited: return 2
        case .toggleAntiRecall: return 3
        case .privacyFooter: return 4

        case .archiveHeader: return 10
        case .openDeletedArchive: return 11
        case .openEditHistory: return 12
        case .archiveFooter: return 13

        case .advancedHeader: return 20
        case .toggleStealthRead: return 21
        case .toggleGhostMode: return 22
        case .toggleAutoSaveViewOnce: return 23
        case .toggleTrackHistory: return 24
        case .advancedFooter: return 25

        case .actionsHeader: return 30
        case .clearArchive: return 31
        case .actionsFooter: return 32
        }
    }

    static func <(lhs: EnhancedFeaturesEntry, rhs: EnhancedFeaturesEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! EnhancedFeaturesControllerArguments
        switch self {
        case .privacyHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "Privacy & message archive", sectionId: self.section)
        case let .toggleSaveDeleted(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Save deleted messages", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateSetting(.saveDeletedMessages, value)
            })
        case let .toggleSaveEdited(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Save edit history", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateSetting(.saveEditedMessages, value)
            })
        case let .toggleAntiRecall(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Anti-recall (show deleted messages)", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateSetting(.antiRecall, value)
            })
        case .privacyFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Stores deleted and edited messages locally on this device. Anti-recall keeps deleted messages visible in the chat using the local archive."), sectionId: self.section)

        case .archiveHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "Local archive", sectionId: self.section)
        case let .openDeletedArchive(count):
            return ItemListDisclosureItem(presentationData: presentationData, title: "Deleted messages", label: "\(count)", sectionId: self.section, style: .blocks, action: {
                arguments.openArchive()
            })
        case let .openEditHistory(count):
            return ItemListDisclosureItem(presentationData: presentationData, title: "Edit history", label: "\(count)", sectionId: self.section, style: .blocks, action: {
                arguments.openEditHistory()
            })
        case .archiveFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Up to 5000 entries are kept per category."), sectionId: self.section)

        case .advancedHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "Advanced privacy", sectionId: self.section)
        case let .toggleStealthRead(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Stealth read (don't send read receipts)", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateSetting(.stealthRead, value)
            })
        case let .toggleGhostMode(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Ghost mode (hide online + typing)", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateSetting(.ghostMode, value)
            })
        case let .toggleAutoSaveViewOnce(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Auto-save view-once media", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateSetting(.autoSaveViewOnceMedia, value)
            })
        case let .toggleTrackHistory(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Track contact name & avatar history", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateSetting(.trackContactNameAndAvatarHistory, value)
            })
        case .advancedFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Stealth read & Ghost mode reduce signals sent to other users about your activity. Some advanced features below are scaffolded and not yet wired into the app — they will be enabled in follow-up updates."), sectionId: self.section)

        case .actionsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "Actions", sectionId: self.section)
        case .clearArchive:
            return ItemListActionItem(presentationData: presentationData, title: "Clear local archive", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.clearArchive()
            })
        case .actionsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Permanently removes all locally archived deleted and edited messages."), sectionId: self.section)
        }
    }
}

private func enhancedFeaturesControllerEntries(settings: EnhancedFeaturesSettings, deletedCount: Int, editedCount: Int) -> [EnhancedFeaturesEntry] {
    var entries: [EnhancedFeaturesEntry] = []
    entries.append(.privacyHeader)
    entries.append(.toggleSaveDeleted(settings.saveDeletedMessages))
    entries.append(.toggleSaveEdited(settings.saveEditedMessages))
    entries.append(.toggleAntiRecall(settings.antiRecall))
    entries.append(.privacyFooter)

    entries.append(.archiveHeader)
    entries.append(.openDeletedArchive(deletedCount))
    entries.append(.openEditHistory(editedCount))
    entries.append(.archiveFooter)

    entries.append(.advancedHeader)
    entries.append(.toggleStealthRead(settings.stealthRead))
    entries.append(.toggleGhostMode(settings.ghostMode))
    entries.append(.toggleAutoSaveViewOnce(settings.autoSaveViewOnceMedia))
    entries.append(.toggleTrackHistory(settings.trackContactNameAndAvatarHistory))
    entries.append(.advancedFooter)

    entries.append(.actionsHeader)
    entries.append(.clearArchive)
    entries.append(.actionsFooter)
    return entries
}

public func enhancedFeaturesController(context: AccountContext) -> ViewController {
    let archive = EnhancedFeaturesArchive.shared(basePath: context.account.postbox.mediaBox.basePath)

    let settingsSignal: Signal<EnhancedFeaturesSettings, NoError> = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.enhancedFeaturesSettings])
    |> map { sharedData -> EnhancedFeaturesSettings in
        return sharedData.entries[ApplicationSpecificSharedDataKeys.enhancedFeaturesSettings]?.get(EnhancedFeaturesSettings.self) ?? EnhancedFeaturesSettings.default
    }

    let settingsPromise = Promise<EnhancedFeaturesSettings>()
    settingsPromise.set(settingsSignal)

    let flagsSyncDisposable = (settingsSignal
    |> deliverOnMainQueue).startStrict(next: { settings in
        archive.updateFlags(EnhancedFeaturesRuntimeFlags(
            saveDeletedMessages: settings.saveDeletedMessages,
            saveEditedMessages: settings.saveEditedMessages
        ))
    })

    let snapshotPromise = Promise<EnhancedFeaturesArchiveSnapshot>()
    snapshotPromise.set(archive.snapshot())

    var pushControllerImpl: ((ViewController) -> Void)?

    let arguments = EnhancedFeaturesControllerArguments(
        updateSetting: { toggle, value in
            let _ = updateEnhancedFeaturesSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
                var settings = settings
                switch toggle {
                case .saveDeletedMessages:
                    settings.saveDeletedMessages = value
                case .saveEditedMessages:
                    settings.saveEditedMessages = value
                case .antiRecall:
                    settings.antiRecall = value
                case .stealthRead:
                    settings.stealthRead = value
                case .ghostMode:
                    settings.ghostMode = value
                case .autoSaveViewOnceMedia:
                    settings.autoSaveViewOnceMedia = value
                case .trackContactNameAndAvatarHistory:
                    settings.trackContactNameAndAvatarHistory = value
                }
                return settings
            }).startStandalone()
        },
        openArchive: {
            pushControllerImpl?(deletedMessagesArchiveController(context: context))
        },
        openEditHistory: {
            pushControllerImpl?(editedMessagesHistoryController(context: context))
        },
        clearArchive: {
            archive.clearAll()
            snapshotPromise.set(archive.snapshot())
        }
    )

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        settingsPromise.get(),
        snapshotPromise.get()
    )
    |> map { presentationData, settings, snapshot -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Enhanced Features"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: enhancedFeaturesControllerEntries(settings: settings, deletedCount: snapshot.deletedMessages.count, editedCount: snapshot.editedMessages.count),
            style: .blocks,
            animateChanges: true
        )
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    controller.didDisappear = { _ in
        flagsSyncDisposable.dispose()
    }

    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }

    return controller
}
