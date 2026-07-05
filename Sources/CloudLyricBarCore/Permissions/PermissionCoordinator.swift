public enum AccessibilityPermissionState: Equatable, Sendable {
    case trusted
    case notTrusted
}

public protocol AccessibilityPermissionProbing: Sendable {
    func isTrusted() async -> Bool
    func requestTrustPrompt() async
}

public actor PermissionCoordinator {
    private let accessibilityProbe: any AccessibilityPermissionProbing

    public init(accessibilityProbe: any AccessibilityPermissionProbing) {
        self.accessibilityProbe = accessibilityProbe
    }

    public func currentAccessibilityState() async -> AccessibilityPermissionState {
        await accessibilityProbe.isTrusted() ? .trusted : .notTrusted
    }

    public func requestAccessibility() async {
        await accessibilityProbe.requestTrustPrompt()
    }
}
