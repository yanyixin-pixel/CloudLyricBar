import CloudLyricBarCore

let permissionCoordinatorTests: [TestCase] = [
    TestCase(
        name: "PermissionCoordinatorTests.testDoesNotRequestPermissionBeforeFeatureNeedsIt",
        run: PermissionCoordinatorTests.testDoesNotRequestPermissionBeforeFeatureNeedsIt
    ),
    TestCase(
        name: "PermissionCoordinatorTests.testRequestsAccessibilityOnlyWhenAsked",
        run: PermissionCoordinatorTests.testRequestsAccessibilityOnlyWhenAsked
    ),
    TestCase(
        name: "PermissionCoordinatorTests.testCurrentAccessibilityStateReturnsTrusted",
        run: PermissionCoordinatorTests.testCurrentAccessibilityStateReturnsTrusted
    )
]

enum PermissionCoordinatorTests {
    static func testDoesNotRequestPermissionBeforeFeatureNeedsIt() async throws {
        let probe = RecordingAccessibilityPermissionProbe(isTrusted: false)
        let coordinator = PermissionCoordinator(accessibilityProbe: probe)

        let state = await coordinator.currentAccessibilityState()

        try expectEqual(state, .notTrusted)
        try await expectEqual(probe.requestCount(), 0)
    }

    static func testRequestsAccessibilityOnlyWhenAsked() async throws {
        let probe = RecordingAccessibilityPermissionProbe(isTrusted: false)
        let coordinator = PermissionCoordinator(accessibilityProbe: probe)

        await coordinator.requestAccessibility()

        try await expectEqual(probe.requestCount(), 1)
    }

    static func testCurrentAccessibilityStateReturnsTrusted() async throws {
        let probe = RecordingAccessibilityPermissionProbe(isTrusted: true)
        let coordinator = PermissionCoordinator(accessibilityProbe: probe)

        let state = await coordinator.currentAccessibilityState()

        try expectEqual(state, .trusted)
        try await expectEqual(probe.requestCount(), 0)
    }
}

private actor RecordingAccessibilityPermissionProbe: AccessibilityPermissionProbing {
    private let trusted: Bool
    private var requests = 0

    init(isTrusted: Bool) {
        trusted = isTrusted
    }

    func isTrusted() async -> Bool {
        trusted
    }

    func requestTrustPrompt() async {
        requests += 1
    }

    func requestCount() -> Int {
        requests
    }
}
