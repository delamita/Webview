//
//  WebView.swift
//  Webview
//
//  Created by ByteDance on 4/18/25.
//

import SwiftUI
import WebKit

/// 一个兼容 SwiftUI 的 WebView，使用 WebViewState 驱动状态。
@available(iOS 13.0, *)
public struct WebView: UIViewRepresentable {
    public let state: WebViewState

    /// 使用已有的 WebViewState 初始化 WebView。
    public init(state: WebViewState) {
        self.state = state
    }

    /// 使用 URL 初始化 WebView，内部自动创建 WebViewState 并加载该地址。
    public init(url: URL) {
        let state = WebViewState()
        state.load(url: url)
        self.state = state
    }
    
    public init(_ urlString: String) {
        let state = WebViewState()
        state.load(urlString)
        self.state = state
    }
    
    public func makeUIView(context: Context) -> WKWebView {
        return state.webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {
        // 不需要手动更新，由 WebViewState 控制 WebView 行为
    }
    
    /// 暴露底层 WKWebView 供外部访问。
    public var webView: WKWebView {
        state.webView
    }
}
