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

    private let dshPath = "/Users/zhouchao/.npm-global/bin/dsh"
    private let logPath = "/Users/zhouchao/.dsh/dsh-desktop.log"
    private var spawnedProcess: Process?
    private var pollGeneration = 0

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

        guard FileManager.default.isExecutableFile(atPath: dshPath) else {
            set(.failed("找不到 dsh 命令：\(dshPath)\n请先执行 npm i -g @deepseek-ai/dsh"))
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: dshPath)
        proc.arguments = ["web", "--port", "3080"]

        var env = ProcessInfo.processInfo.environment
        env["HOME"] = NSHomeDirectory()
        env["DSH_HOME"] = NSHomeDirectory() + "/.dsh"
        env["PATH"] = "/Users/zhouchao/.npm-global/bin:/usr/local/bin:/usr/bin:/bin"
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
