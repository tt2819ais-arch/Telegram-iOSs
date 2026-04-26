import Foundation
import NexusCore

/// Gate that determines whether a given user has access to the hidden
/// Nexus admin panel.
///
/// Two independent checks are required:
///   1. The current Telegram user id must match `ownerUserId`.
///   2. The unlock code must have been entered (long-press on the
///      "About Nexus" screen reveals an input field).
///
/// Both checks live in this module so Stage 1 already ships the access
/// gate; only the UI hooks are added in Stage 5.
public final class NexusAdminAccess {
    /// Telegram user id that owns the Nexus build. Nil until the runtime
    /// is configured.
    public private(set) var ownerUserId: Int64?

    /// Hash of the unlock code. SHA256 of the raw code, hex-encoded.
    /// `nil` means no unlock code has been set, in which case the admin
    /// panel is unreachable regardless of `ownerUserId`.
    public private(set) var unlockCodeHash: String?

    public private(set) var isUnlocked: Bool = false

    public init(ownerUserId: Int64? = nil, unlockCodeHash: String? = nil) {
        self.ownerUserId = ownerUserId
        self.unlockCodeHash = unlockCodeHash
    }

    public func configure(ownerUserId: Int64, unlockCodeHash: String) {
        self.ownerUserId = ownerUserId
        self.unlockCodeHash = unlockCodeHash
    }

    /// Attempt to unlock the panel. Returns `true` when the code matches
    /// `unlockCodeHash` and the active user matches `ownerUserId`.
    public func attemptUnlock(currentUserId: Int64, code: String) -> Bool {
        guard NexusRuntime.shared.flags.adminPanelEnabled else {
            return false
        }
        guard let owner = self.ownerUserId, owner == currentUserId else {
            return false
        }
        guard let expectedHash = self.unlockCodeHash else {
            return false
        }
        let suppliedHash = NexusAdminAccess.sha256Hex(of: code)
        guard suppliedHash == expectedHash else {
            return false
        }
        self.isUnlocked = true
        return true
    }

    public func lock() {
        self.isUnlocked = false
    }

    /// SHA-256 hash of `value` returned as a lowercase hex string.
    /// Implemented manually so the module has no CryptoKit dependency
    /// and remains importable from extensions targeting older OS versions.
    static func sha256Hex(of value: String) -> String {
        let bytes = Array(value.utf8)
        let hash = NexusAdminAccess.sha256(message: bytes)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private static let initialHashValues: [UInt32] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    ]

    private static let roundConstants: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    ]

    private static func sha256(message: [UInt8]) -> [UInt8] {
        var padded = message
        let length = UInt64(message.count) * 8
        padded.append(0x80)
        while padded.count % 64 != 56 {
            padded.append(0x00)
        }
        for shift in stride(from: 56, through: 0, by: -8) {
            padded.append(UInt8((length >> shift) & 0xff))
        }

        var hashValues = NexusAdminAccess.initialHashValues
        for chunkStart in stride(from: 0, to: padded.count, by: 64) {
            var w = [UInt32](repeating: 0, count: 64)
            for i in 0..<16 {
                let base = chunkStart + i * 4
                w[i] = (UInt32(padded[base]) << 24)
                    | (UInt32(padded[base + 1]) << 16)
                    | (UInt32(padded[base + 2]) << 8)
                    | UInt32(padded[base + 3])
            }
            for i in 16..<64 {
                let s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
                let s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
                w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
            }

            var a = hashValues[0]
            var b = hashValues[1]
            var c = hashValues[2]
            var d = hashValues[3]
            var e = hashValues[4]
            var f = hashValues[5]
            var g = hashValues[6]
            var h = hashValues[7]

            for i in 0..<64 {
                let s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
                let ch = (e & f) ^ (~e & g)
                let temp1 = h &+ s1 &+ ch &+ NexusAdminAccess.roundConstants[i] &+ w[i]
                let s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
                let mj = (a & b) ^ (a & c) ^ (b & c)
                let temp2 = s0 &+ mj
                h = g
                g = f
                f = e
                e = d &+ temp1
                d = c
                c = b
                b = a
                a = temp1 &+ temp2
            }

            hashValues[0] = hashValues[0] &+ a
            hashValues[1] = hashValues[1] &+ b
            hashValues[2] = hashValues[2] &+ c
            hashValues[3] = hashValues[3] &+ d
            hashValues[4] = hashValues[4] &+ e
            hashValues[5] = hashValues[5] &+ f
            hashValues[6] = hashValues[6] &+ g
            hashValues[7] = hashValues[7] &+ h
        }

        var result: [UInt8] = []
        result.reserveCapacity(32)
        for value in hashValues {
            result.append(UInt8((value >> 24) & 0xff))
            result.append(UInt8((value >> 16) & 0xff))
            result.append(UInt8((value >> 8) & 0xff))
            result.append(UInt8(value & 0xff))
        }
        return result
    }
}

private func rotr(_ value: UInt32, _ count: UInt32) -> UInt32 {
    return (value >> count) | (value << (32 - count))
}
