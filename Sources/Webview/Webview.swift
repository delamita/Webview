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
    
    var onScrollContinuous: ((CGPoint) -> Void)? = nil
    var onScrollEnd: ((_ from: CGPoint, _ to: CGPoint) -> Void)? = nil
    var onScrollGesture: ((_ from: CGPoint, _ to: CGPoint) -> Void)? = nil

    /// 使用已有的 WebViewState 初始化 WebView。
    public init(_ state: WebViewState) {
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
        state.webView.scrollView.delegate = context.coordinator
        return state.webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {
        // 不需要手动更新，由 WebViewState 控制 WebView 行为
    }
    
    /// 暴露底层 WKWebView 供外部访问。
    public var webView: WKWebView {
        state.webView
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(
            onScrollContinuous: onScrollContinuous,
            onScrollEnd: onScrollEnd,
            onScrollGesture: onScrollGesture
        )
    }

    public class Coordinator: NSObject, UIScrollViewDelegate {
        let onScrollContinuous: ((CGPoint) -> Void)?
        let onScrollEnd: ((_ from: CGPoint, _ to: CGPoint) -> Void)?
        let onScrollGesture: ((_ from: CGPoint, _ to: CGPoint) -> Void)?
        private var dragStartOffset: CGPoint = .zero
        private var hasCalledEnd = false

        init(
            onScrollContinuous: ((CGPoint) -> Void)?,
            onScrollEnd: ((_ from: CGPoint, _ to: CGPoint) -> Void)?,
            onScrollGesture: ((_ from: CGPoint, _ to: CGPoint) -> Void)?
        ) {
            self.onScrollContinuous = onScrollContinuous
            self.onScrollEnd = onScrollEnd
            self.onScrollGesture = onScrollGesture
        }

        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            onScrollContinuous?(scrollView.contentOffset)
            onScrollGesture?(dragStartOffset, scrollView.contentOffset)
        }

        public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            dragStartOffset = scrollView.contentOffset
            hasCalledEnd = false
        }

        public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                triggerScrollEnd(scrollView)
            }
        }

        public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            triggerScrollEnd(scrollView)
        }

        private func triggerScrollEnd(_ scrollView: UIScrollView) {
            guard !hasCalledEnd else { return }
            hasCalledEnd = true
            let endOffset = scrollView.contentOffset
            onScrollEnd?(dragStartOffset, endOffset)
        }
    }
    
    
    public func onScrollContinuous(_ action: @escaping (CGPoint) -> Void) -> WebView {
        var copy = self
        copy.onScrollContinuous = action
        return copy
    }

    public func onScrollEnd(_ action: @escaping (_ from: CGPoint, _ to: CGPoint) -> Void) -> WebView {
        var copy = self
        copy.onScrollEnd = action
        return copy
    }
    
    public func onScrollGesture(_ action: @escaping (_ from: CGPoint, _ to: CGPoint) -> Void) -> WebView {
        var copy = self
        copy.onScrollGesture = action
        return copy
    }
    
}
