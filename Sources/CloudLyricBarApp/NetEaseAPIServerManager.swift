import Foundation

final class NetEaseAPIServerManager: @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession
    private var process: Process?

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    deinit {
        process?.terminate()
    }

    func ensureRunning() async -> Bool {
        if await isReachable() {
            return true
        }

        guard process == nil, let command = startupCommand() else {
            return false
        }

        let process = Process()
        process.executableURL = command.executableURL
        process.arguments = command.arguments
        process.currentDirectoryURL = command.workingDirectoryURL
        process.environment = command.environment
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            self.process = process
        } catch {
            return false
        }

        return await waitUntilReachable()
    }

    private func isReachable() async -> Bool {
        let url = baseURL.appendingPathComponent("search")
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }
        components.queryItems = [
            URLQueryItem(name: "keywords", value: "test"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let requestURL = components.url else {
            return false
        }

        var request = URLRequest(url: requestURL)
        request.timeoutInterval = 1.5

        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    private func waitUntilReachable() async -> Bool {
        for _ in 0..<30 {
            if await isReachable() {
                return true
            }

            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        return false
    }

    private func startupCommand() -> StartupCommand? {
        if let bundledAPI = bundledAPIPath(), let node = bundledNode() ?? executable(named: "node") {
            return StartupCommand(
                executableURL: node,
                arguments: [bundledAPI.appendingPathComponent("app.js").path],
                workingDirectoryURL: bundledAPI,
                environment: environment(port: port)
            )
        }

        if let npx = executable(named: "npx") {
            return StartupCommand(
                executableURL: npx,
                arguments: ["--yes", "NeteaseCloudMusicApi@latest"],
                workingDirectoryURL: nil,
                environment: environment(port: port)
            )
        }

        return nil
    }

    private var port: String {
        String(baseURL.port ?? 3000)
    }

    private func bundledAPIPath() -> URL? {
        guard let url = Bundle.main.url(forResource: "NeteaseCloudMusicApi", withExtension: nil),
              FileManager.default.fileExists(atPath: url.appendingPathComponent("app.js").path)
        else {
            return nil
        }

        return url
    }

    private func bundledNode() -> URL? {
        guard let resourcesURL = Bundle.main.resourceURL else {
            return nil
        }

        let url = resourcesURL.appendingPathComponent("node/bin/node")
        return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
    }

    private func executable(named name: String) -> URL? {
        let paths = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)"
        ]

        return paths
            .map(URL.init(fileURLWithPath:))
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    private func environment(port: String) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["PORT"] = port
        environment["HOST"] = "127.0.0.1"
        return environment
    }
}

private struct StartupCommand {
    let executableURL: URL
    let arguments: [String]
    let workingDirectoryURL: URL?
    let environment: [String: String]
}
