import AppKit
import WebKit

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate {

    private var window: NSWindow!
    private var webView: WKWebView!
    private var overlay: NSView!
    private var spinner: NSProgressIndicator!
    private var statusLabel: NSTextField!
    private var retryButton: NSButton!
    private var launchAtLoginItem: NSMenuItem!

    private let server = ServerController()
    private var loadedOnce = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        buildWindow()

        server.onStateChange = { [weak self] state in
            DispatchQueue.main.async { self?.apply(state) }
        }
        server.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        server.shutdown()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Window

    private func buildWindow() {
        let contentRect = NSRect(x: 0, y: 0, width: 1240, height: 800)
        window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DeepSeek Harness"
        window.minSize = NSSize(width: 960, height: 640)
        window.center()
        window.setFrameAutosaveName("DeepSeekHarnessWindow")
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false

        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: contentRect, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.allowsMagnification = true
        window.contentView = webView

        buildOverlay()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildOverlay() {
        overlay = NSView(frame: webView.bounds)
        overlay.autoresizingMask = [.width, .height]
        overlay.wantsLayer = true
        overlay.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .large
        spinner.isDisplayedWhenStopped = false
        spinner.startAnimation(nil)

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.alignment = .center
        statusLabel.font = .systemFont(ofSize: 13)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.maximumNumberOfLines = 0
        statusLabel.preferredMaxLayoutWidth = 520

        retryButton = NSButton(title: "重试", target: self, action: #selector(retryTapped))
        retryButton.bezelStyle = .rounded
        retryButton.isHidden = true

        let stack = NSStackView(views: [spinner, statusLabel, retryButton])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: overlay.centerYAnchor)
        ])

        webView.addSubview(overlay)
    }

    // MARK: - State handling

    private func apply(_ state: ServerState) {
        switch state {
        case .checking:
            showOverlay("正在检查 DeepSeek Harness 服务…")
        case .starting:
            showOverlay("正在启动 dsh 服务…")
        case .ready(let url):
            hideOverlay()
            if !loadedOnce || webView.url == nil || webView.url != url {
                webView.load(URLRequest(url: url))
                loadedOnce = true
            }
        case .failed(let message):
            showOverlay(message, retry: true)
        case .stopped:
            showOverlay("dsh 服务已停止。", retry: true)
        }
    }

    private func showOverlay(_ message: String, retry: Bool = false) {
        statusLabel.stringValue = message
        retryButton.isHidden = !retry
        if retry {
            spinner.stopAnimation(nil)
        } else {
            spinner.startAnimation(nil)
        }
        overlay.isHidden = false
    }

    private func hideOverlay() {
        overlay.isHidden = true
        spinner.stopAnimation(nil)
    }

    // MARK: - WebView delegate

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if overlay.isHidden {
            showOverlay("页面加载失败：\(error.localizedDescription)", retry: true)
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showOverlay("无法连接服务：\(error.localizedDescription)", retry: true)
    }

    // MARK: - Actions

    @objc private func retryTapped() {
        server.start()
    }

    @objc private func reloadPage() {
        webView.reload()
    }

    @objc private func openInBrowser() {
        NSWorkspace.shared.open(server.serverURL)
    }

    @objc private func copyURL() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(server.serverURL.absoluteString, forType: .string)
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "DeepSeek Harness 桌面版"
        alert.informativeText = "DeepSeek Harness (dsh) 的原生 macOS 客户端，内嵌 Web UI。\n版本 1.0.0"
        alert.runModal()
    }

    @objc private func toggleLaunchAtLogin() {
        let plistPath = NSHomeDirectory() + "/Library/LaunchAgents/com.zhouchao.dsh-desktop.plist"
        if FileManager.default.fileExists(atPath: plistPath) {
            try? FileManager.default.removeItem(atPath: plistPath)
            launchAtLoginItem.state = .off
        } else {
            let plist: [String: Any] = [
                "Label": "com.zhouchao.dsh-desktop",
                "ProgramArguments": ["/usr/bin/open", "-a", "DeepSeek Harness"],
                "RunAtLoad": true
            ]
            (plist as NSDictionary).write(toFile: plistPath, atomically: true)
            launchAtLoginItem.state = .on
        }
    }

    // MARK: - Menu

    private func buildMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu(title: "DeepSeek Harness")
        appMenu.addItem(withTitle: "关于 DeepSeek Harness", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(.separator())
        launchAtLoginItem = NSMenuItem(title: "登录时自动启动", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.state = FileManager.default.fileExists(
            atPath: NSHomeDirectory() + "/Library/LaunchAgents/com.zhouchao.dsh-desktop.plist"
        ) ? .on : .off
        appMenu.addItem(launchAtLoginItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏 DeepSeek Harness", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 DeepSeek Harness", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let viewItem = NSMenuItem()
        mainMenu.addItem(viewItem)
        let viewMenu = NSMenu(title: "视图")
        viewMenu.addItem(withTitle: "重新加载", action: #selector(reloadPage), keyEquivalent: "r")
        viewMenu.addItem(withTitle: "在浏览器中打开", action: #selector(openInBrowser), keyEquivalent: "o")
        viewMenu.addItem(withTitle: "复制地址", action: #selector(copyURL), keyEquivalent: "c")
        viewItem.submenu = viewMenu

        let windowItem = NSMenuItem()
        mainMenu.addItem(windowItem)
        let windowMenu = NSMenu(title: "窗口")
        windowMenu.addItem(withTitle: "最小化", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "关闭", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }
}
