import Foundation

enum ServerState {
    case checking
    case starting
    case ready(URL)
    case failed(String)
    case stopped
}

/// Ensures the dsh web server is reachable on port 3080, starting it when needed.
final class ServerController {

    var onStateChange: ((ServerState) -> Void)?

    let serverURL = URL(string: "http://127.0.0.1:3080")!

    private var logPath: String {
        NSHomeDirectory() + "/.dsh/dsh-desktop.log"
    }
    private var spawnedProcess: Process?
    private var pollGeneration = 0

    private struct LaunchCommand {
        let executable: URL
        let arguments: [String]
    }

    func start() {
        if spawnedProcess?.isRunning == true {
            set(.starting)
            pollUntilReachable(timeout: 35) { [weak self] ok in
                guard let self else { return }
                ok ? self.set(.ready(self.serverURL)) : self.set(.failed("dsh 服务启动超时。日志：\(self.logPath)"))
            }
        } else {
            set(.checking)
            pollUntilReachable(timeout: 8) { [weak self] ok in
                guard let self else { return }
                if ok {
                    self.set(.ready(self.serverURL))
                } else {
                    self.launchServer()
                }
            }
        }
    }

    func shutdown() {
        pollGeneration += 1
        if let proc = spawnedProcess, proc.isRunning {
            proc.terminate()
        }
        spawnedProcess = nil
    }

    // MARK: - Server launch

    private func launchServer() {
        set(.starting)

        guard let command = resolveLaunchCommand() else {
            set(.failed("未找到 dsh 命令。\n请先安装 Node.js 并执行：npm i -g @deepseek-ai/dsh"))
            return
        }

        let proc = Process()
        proc.executableURL = command.executable
        proc.arguments = command.arguments

        var env = ProcessInfo.processInfo.environment
        env["HOME"] = NSHomeDirectory()
        env["DSH_HOME"] = NSHomeDirectory() + "/.dsh"
        env["PATH"] = [
            NSHomeDirectory() + "/.npm-global/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin"
        ].joined(separator: ":")
        proc.environment = env

        let logDir = (logPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: logPath, contents: nil)
        if let handle = FileHandle(forWritingAtPath: logPath) {
            proc.standardOutput = handle
            proc.standardError = handle
        }

        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.spawnedProcess === proc else { return }
                self.spawnedProcess = nil
                // The port may have been taken over by another instance; re-check before failing.
                self.pollUntilReachable(timeout: 5) { ok in
                    ok ? self.set(.ready(self.serverURL)) : self.set(.stopped)
                }
            }
        }

        do {
            try proc.run()
            spawnedProcess = proc
            pollUntilReachable(timeout: 35) { [weak self] ok in
                guard let self else { return }
                ok ? self.set(.ready(self.serverURL)) : self.set(.failed("dsh 服务启动超时。日志：\(self.logPath)"))
            }
        } catch {
            set(.failed("启动 dsh 失败：\(error.localizedDescription)"))
        }
    }

    // MARK: - dsh discovery

    /// Locates a usable `dsh` command: on PATH, in common install locations,
    /// or via `npx` (which downloads @deepseek-ai/dsh on first run).
    private func resolveLaunchCommand() -> LaunchCommand? {
        if let dsh = executableInPATH("dsh") {
            return LaunchCommand(executable: dsh, arguments: ["web", "--port", "3080"])
        }

        let home = NSHomeDirectory()
        for path in [
            home + "/.npm-global/bin/dsh",
            "/usr/local/bin/dsh",
            "/opt/homebrew/bin/dsh",
            "/usr/bin/dsh"
        ] where FileManager.default.isExecutableFile(atPath: path) {
            return LaunchCommand(executable: URL(fileURLWithPath: path), arguments: ["web", "--port", "3080"])
        }

        if let npx = executableInPATH("npx") {
            return LaunchCommand(
                executable: npx,
                arguments: ["--yes", "@deepseek-ai/dsh", "web", "--port", "3080"]
            )
        }
        return nil
    }

    private func executableInPATH(_ name: String) -> URL? {
        var paths = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":").map(String.init)
        paths.insert(NSHomeDirectory() + "/.npm-global/bin", at: 0)
        paths.insert("/opt/homebrew/bin", at: 0)
        paths.insert("/usr/local/bin", at: 0)

        for dir in paths where !dir.isEmpty {
            let candidate = dir + "/" + name
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return URL(fileURLWithPath: candidate)
            }
        }
        return nil
    }

    // MARK: - Reachability polling

    private func pollUntilReachable(timeout: TimeInterval, completion: @escaping (Bool) -> Void) {
        pollGeneration += 1
        let generation = pollGeneration
        let deadline = Date().addingTimeInterval(timeout)

        func tick() {
            guard generation == pollGeneration else { return }
            isReachable { ok in
                DispatchQueue.main.async {
                    guard generation == self.pollGeneration else { return }
                    if ok {
                        completion(true)
                    } else if Date() >= deadline {
                        completion(false)
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { tick() }
                    }
                }
            }
        }
        tick()
    }

    private func isReachable(completion: @escaping (Bool) -> Void) {
        var request = URLRequest(url: serverURL)
        request.timeoutInterval = 1.5
        request.cachePolicy = .reloadIgnoringLocalCacheData
        URLSession.shared.dataTask(with: request) { _, response, _ in
            let ok: Bool
            if let http = response as? HTTPURLResponse {
                ok = (200..<500).contains(http.statusCode)
            } else {
                ok = false
            }
            completion(ok)
        }.resume()
    }

    private func set(_ state: ServerState) {
        onStateChange?(state)
    }
}
