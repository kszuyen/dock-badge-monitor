import ApplicationServices
import Foundation

@MainActor
public protocol AccessibilityPermissionChecking {
    func isTrusted(prompt: Bool) -> Bool
}

@MainActor
public struct SystemAccessibilityPermissionChecker: AccessibilityPermissionChecking {
    public init() {}

    public func isTrusted(prompt: Bool) -> Bool {
        let options = [
            "AXTrustedCheckOptionPrompt": prompt
        ] as CFDictionary

        return AXIsProcessTrustedWithOptions(options)
    }
}
