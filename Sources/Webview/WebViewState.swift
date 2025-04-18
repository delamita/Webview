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

@MainActor
@Observable
/// 一个管理网页视图状态的公共类。
public class WebViewState: NSObject, WKNavigationDelegate {
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
    
    /// 初始化 WebViewState 实例，并设置键值观察。
    public override init() {
        self.webView = WKWebView()
        super.init()
        webView.navigationDelegate = self
        setupKVO()
    }
    
    /// 在实例销毁时移除所有的键值观察。
    deinit {
        teardownKVO()
    }
    
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
    
    /// 加载指定的网页地址字符串。
    ///
    /// - Parameter urlString: 要加载的网址字符串，例如 "https://apple.com"。
    public func load(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    /// 加载指定的网页地址。
    ///
    /// - Parameter url: 要加载的 URL 实例。
    public func load(url: URL) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    /// 如果可以，则在网页历史中后退。
    public func goBack() {
        if webView.canGoBack {
            webView.goBack()
        }
    }
    
    /// 如果可以，则在网页历史中前进。
    public func goForward() {
        if webView.canGoForward {
            webView.goForward()
        }
    }
    
    /// 重新加载当前网页。
    public func reload() {
        webView.reload()
    }
    
    /// 在网页上下文中执行指定的 JavaScript 代码。
    ///
    /// - Parameters:
    ///   - script: 要执行的 JavaScript 代码。
    ///   - completion: 脚本评估完成时调用的闭包。
    public func evaluateJS(_ script: String, completion: @Sendable @escaping (Any?, Error?) -> Void) {
        webView.evaluateJavaScript(script, completionHandler: completion)
    }
    
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
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.loadState = .success
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.loadState = .failure(error)
        print("Navigation error (provisional): \(error.localizedDescription)")
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.loadState = .failure(error)
        print("Navigation error: \(error.localizedDescription)")
    }
}
