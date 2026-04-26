import Foundation

/// Static branding values used across the Nexus modules.
///
/// Centralised here so that future renames or rebuilds only need to touch
/// a single file. The values intentionally do not pull from `Bundle.main`
/// because some Nexus features run in extension contexts where the main
/// bundle's display name is not available.
public enum NexusBranding {
    /// User-visible product name.
    public static let productName: String = "Nexus"

    /// One-line tagline used on the "About Nexus" screen.
    public static let tagline: String = "Unofficial client based on Telegram API"

    /// Disclaimer shown on the "About" screen and in onboarding.
    public static let disclaimer: String =
        "Nexus is an unofficial third-party client built on the open-source Telegram-iOS codebase. It is not affiliated with, endorsed by, or sponsored by Telegram Messenger Inc."

    /// URL of the Nexus source repository.
    public static let sourceRepositoryURL: String =
        "https://github.com/tt2819ais-arch/nexus-ios"
}
