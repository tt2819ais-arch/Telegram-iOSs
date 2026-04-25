import Foundation
import SwiftSignalKit
import TelegramCore
import Postbox

public struct EnhancedFeaturesSettings: Equatable, Codable {
    public var saveDeletedMessages: Bool
    public var saveEditedMessages: Bool
    public var antiRecall: Bool
    public var stealthRead: Bool
    public var ghostMode: Bool
    public var autoSaveViewOnceMedia: Bool
    public var trackContactNameAndAvatarHistory: Bool

    public static var `default`: EnhancedFeaturesSettings {
        return EnhancedFeaturesSettings(
            saveDeletedMessages: true,
            saveEditedMessages: true,
            antiRecall: true,
            stealthRead: false,
            ghostMode: false,
            autoSaveViewOnceMedia: false,
            trackContactNameAndAvatarHistory: false
        )
    }

    public init(
        saveDeletedMessages: Bool,
        saveEditedMessages: Bool,
        antiRecall: Bool,
        stealthRead: Bool,
        ghostMode: Bool,
        autoSaveViewOnceMedia: Bool,
        trackContactNameAndAvatarHistory: Bool
    ) {
        self.saveDeletedMessages = saveDeletedMessages
        self.saveEditedMessages = saveEditedMessages
        self.antiRecall = antiRecall
        self.stealthRead = stealthRead
        self.ghostMode = ghostMode
        self.autoSaveViewOnceMedia = autoSaveViewOnceMedia
        self.trackContactNameAndAvatarHistory = trackContactNameAndAvatarHistory
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.saveDeletedMessages = (try container.decodeIfPresent(Int32.self, forKey: "saveDeletedMessages") ?? 1) != 0
        self.saveEditedMessages = (try container.decodeIfPresent(Int32.self, forKey: "saveEditedMessages") ?? 1) != 0
        self.antiRecall = (try container.decodeIfPresent(Int32.self, forKey: "antiRecall") ?? 1) != 0
        self.stealthRead = (try container.decodeIfPresent(Int32.self, forKey: "stealthRead") ?? 0) != 0
        self.ghostMode = (try container.decodeIfPresent(Int32.self, forKey: "ghostMode") ?? 0) != 0
        self.autoSaveViewOnceMedia = (try container.decodeIfPresent(Int32.self, forKey: "autoSaveViewOnceMedia") ?? 0) != 0
        self.trackContactNameAndAvatarHistory = (try container.decodeIfPresent(Int32.self, forKey: "trackContactNameAndAvatarHistory") ?? 0) != 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode((self.saveDeletedMessages ? 1 : 0) as Int32, forKey: "saveDeletedMessages")
        try container.encode((self.saveEditedMessages ? 1 : 0) as Int32, forKey: "saveEditedMessages")
        try container.encode((self.antiRecall ? 1 : 0) as Int32, forKey: "antiRecall")
        try container.encode((self.stealthRead ? 1 : 0) as Int32, forKey: "stealthRead")
        try container.encode((self.ghostMode ? 1 : 0) as Int32, forKey: "ghostMode")
        try container.encode((self.autoSaveViewOnceMedia ? 1 : 0) as Int32, forKey: "autoSaveViewOnceMedia")
        try container.encode((self.trackContactNameAndAvatarHistory ? 1 : 0) as Int32, forKey: "trackContactNameAndAvatarHistory")
    }
}

public func updateEnhancedFeaturesSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (EnhancedFeaturesSettings) -> EnhancedFeaturesSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.enhancedFeaturesSettings, { entry in
            let currentSettings: EnhancedFeaturesSettings
            if let entry = entry?.get(EnhancedFeaturesSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = .default
            }
            return SharedPreferencesEntry(f(currentSettings))
        })
    }
}
