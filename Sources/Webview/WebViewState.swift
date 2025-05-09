//
//  WebViewState.swift
//  Webview
//
//  Created by ByteDance on 4/18/25.
//

import Foundation
import WebKit

/// 表示网页加载的整体状态。
public enum WebLoadState: Equatable {
    case idle
    case loading
    case success
    case failure(Error)
}

extension WebLoadState {
    public static func == (lhs: WebLoadState, rhs: WebLoadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.loading, .loading),
             (.success, .success):
            return true
        case let (.failure(lError), .failure(rError)):
            return (lError as NSError).code == (rError as NSError).code &&
                   (lError as NSError).domain == (rError as NSError).domain
        default:
            return false
        }
    }
}


/// WebViewState - 一个管理网页视图状态的公共类。
@Observable
public class WebViewState : NSObject, WKNavigationDelegate {
    /// 指示网页视图是否可以后退。
    public var canGoBack: Bool = false
    /// 指示网页视图是否可以前进。
    public var canGoForward: Bool = false
    /// 指示网页视图是否正在加载内容。
    public var isLoading: Bool = false
    /// 网页加载的进度值。
    public var progress: Float = 0.0
    /// 当前网页的标题。
    public var title: String?
    /// 当前网页的地址。
    public var url: URL?
    /// 当前网页的加载状态。
    public var loadState: WebLoadState = .idle
    
    public nonisolated let webView: WKWebView
    
    public nonisolated let jsbridge : JSBridge
    
    public let plugin : PluginManager
    
    /// 初始化 WebViewState 实例，并设置键值观察。
    public override init() {
        self.webView = WKWebView()
        self.jsbridge = JSBridge(self.webView)
        self.plugin = PluginManager()
        super.init()
        jsbridge.state = self
        plugin.state = self
        webView.navigationDelegate = self
        webView.isInspectable = true
        setupKVO()
        plugin.addAppBaseJS()
    }
    
    /// 在实例销毁时移除所有的键值观察。
    deinit {
        teardownKVO()
    }
}

// MARK: - KVO
extension WebViewState {
    private func setupKVO() {
        webView.addObserver(self, forKeyPath: "canGoBack", options: .new, context: nil)
        webView.addObserver(self, forKeyPath: "canGoForward", options: .new, context: nil)
        webView.addObserver(self, forKeyPath: "loading", options: .new, context: nil)
        webView.addObserver(self, forKeyPath: "estimatedProgress", options: .new, context: nil)
        webView.addObserver(self, forKeyPath: "title", options: .new, context: nil)
        webView.addObserver(self, forKeyPath: "URL", options: .new, context: nil)
    }
    
    nonisolated private func teardownKVO() {
        webView.removeObserver(self, forKeyPath: "canGoBack")
        webView.removeObserver(self, forKeyPath: "canGoForward")
        webView.removeObserver(self, forKeyPath: "loading")
        webView.removeObserver(self, forKeyPath: "estimatedProgress")
        webView.removeObserver(self, forKeyPath: "title")
        webView.removeObserver(self, forKeyPath: "URL")
    }
}

// MARK: - Navigation
extension WebViewState {
    /// 加载指定的网页地址字符串。
    ///
    /// - Parameter urlString: 要加载的网址字符串，例如 "https://apple.com"。
    public func load(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        load(url: url)
    }
    
    /// 加载指定的网页地址。
    ///
    /// - Parameter url: 要加载的 URL 实例。
    public func load(url: URL) {
        let request = URLRequest(url: url)
        plugin.stateWillLoadUrl(url.absoluteString)
        webView.load(request)
    }
    
    /// 如果可以，则在网页历史中后退。
    public func goBack() {
        if webView.canGoBack {
            // 插件通知：后退
            plugin.webViewGoBack()
            webView.goBack()
        }
    }
    
    /// 如果可以，则在网页历史中前进。
    public func goForward() {
        if webView.canGoForward {
            // 插件通知：前进
            plugin.webViewGoForward()
            webView.goForward()
        }
    }
    
    /// 重新加载当前网页。
    public func reload() {
        webView.reload()
    }
}

// MARK: - Script
extension WebViewState {
    /// 在网页上下文中执行指定的 JavaScript 代码。
    ///
    /// - Parameters:
    ///   - script: 要执行的 JavaScript 代码。
    ///   - completion: 脚本评估完成时调用的闭包。
    public func evaluateJS(_ script: String, completion:((Any?, (any Error)?) -> Void)? = nil) {
        self.webView.evaluateJavaScript(script) { result, error in
            completion?(result, error)
        }
    }
    
    /// 添加用户脚本。
    ///
    /// - Parameter script: 要添加的用户脚本。
    public func addUserScript(_ script: WKUserScript) {
        webView.configuration.userContentController.addUserScript(script)
    }

    /// 添加用户脚本。
    ///
    /// - Parameters:
    ///   - source: 要添加的 JavaScript 源代码。
    ///   - injectionTime: 脚本注入时间。
    ///   - forMainFrameOnly: 是否仅针对主框架。
    public func addUserScript(_ script: String, injectionTime: WKUserScriptInjectionTime = .atDocumentStart, forMainFrameOnly: Bool = false) {
        let userScript = WKUserScript(source: script, injectionTime: injectionTime, forMainFrameOnly: forMainFrameOnly)
        addUserScript(userScript)
    }
    
}

// MARK: - WKNavigationDelegate
extension WebViewState {
    /// 处理 KVO 属性变更通知。
    public override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard let keyPath = keyPath else { return }

        Task { @MainActor in
            switch keyPath {
            case "canGoBack":
                self.canGoBack = webView.canGoBack
                print("KVO: canGoBack = \(self.canGoBack)")
            case "canGoForward":
                self.canGoForward = webView.canGoForward
                print("KVO: canGoForward = \(self.canGoForward)")
            case "loading":
                self.isLoading = webView.isLoading
                if self.isLoading {
                    self.loadState = .loading
                }
                print("KVO: isLoading = \(self.isLoading)")
            case "estimatedProgress":
                self.progress = Float(webView.estimatedProgress)
                print("KVO: progress = \(self.progress)")
            case "title":
                self.title = webView.title
                print("KVO: title = \(self.title ?? "nil")")
            case "URL":
                self.url = webView.url
                print("KVO: url = \(self.url?.absoluteString ?? "nil")")
            default:
                break
            }
        }
    }
    
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        plugin.webViewDidStartNavigation(url: webView.url)
    }
    
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.loadState = .success
        plugin.webViewDidFinishNavigation(url: webView.url)
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.loadState = .failure(error)
        plugin.webViewDidFailNavigation(url: webView.url, withError: error)
        print("Navigation error (provisional): \(error.localizedDescription)")
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.loadState = .failure(error)
        plugin.webViewDidFailNavigation(url: webView.url, withError: error)
        print("Navigation error: \(error.localizedDescription)")
    }
}
