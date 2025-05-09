//
//  WebViewState+JS.swift
//  Webview
//
//  Created by ByteDance on 4/21/25.
//

import Foundation
import WebKit
@preconcurrency import AnyCodable

/// JavaScript 桥接及消息处理的扩展工具。
/// 通过 `actor BridgeCore` 提供线程安全的消息注册 / 移除能力，
/// 并对外暴露轻量级门面 `JSBridge`。
@MainActor
fileprivate class ScriptHandler: NSObject, WKScriptMessageHandler {
    /// WKScriptMessageHandler 的轻量封装，
    /// 将收到的消息转发给提供的闭包。
    private let handler: (WKScriptMessage) -> Void
    /// 使用给定闭包创建消息处理封装。
    ///
    /// - Parameter handler: 消息到达时调用的闭包。
    init(handler: @escaping (WKScriptMessage) -> Void) {
        self.handler = handler
    }
    /// 收到脚本消息后转发给回调。
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        handler(message)
    }
}

// MARK: - BridgeCore (actor, owns state)
/// 内部并发隔离的核心，持有可变状态 `jsHandlers`，
/// 并在主线程完成 WebKit 的注册与移除操作。
actor BridgeCore {
    /// JS 处理器字典，key 为消息名，value 为原生回调。
    private var jsHandlers: [String: [@MainActor (WKScriptMessage) -> Void]] = [:]
    private var scriptHandlerWrappers: [String: ScriptHandler] = [:]
    private unowned let webView: WKWebView

    init(webView: WKWebView) {
        self.webView = webView
    }

    /// 注册 JS 消息处理器。
    ///
    /// - Parameters:
    ///   - name: JS 消息名称。
    ///   - handler: 消息到达时执行的闭包。
    /// - Note: WebKit 的注册过程在主线程执行。
    func add(name: String, handler: @MainActor @escaping (WKScriptMessage) -> Void) async {
        // 1️⃣ 更新回调数组（actor 内线程安全）
        var list = jsHandlers[name] ?? []
        list.append(handler)
        jsHandlers[name] = list

        // 2️⃣ 首次注册时，主线程添加 ScriptHandler
        if scriptHandlerWrappers[name] != nil {
            return
        }
        let wrapper = await MainActor.run { [weak self] () -> ScriptHandler in
            guard let self = self else {
                // 返回一个空占位；在外层会因为 self 为 nil 而提前 return
                return ScriptHandler { _ in }
            }
            let w = ScriptHandler { [weak self] message in
                Task { [weak self] in
                    await self?.dispatch(name: name, message: message)
                }
            }
            self.webView.configuration.userContentController.add(w, name: name)
            return w
        }
        self.scriptHandlerWrappers[name] = wrapper
    }

    private func dispatch(name: String, message: WKScriptMessage) {
        guard let handlers = jsHandlers[name] else { return }
        for h in handlers {
            Task { @MainActor in
                h(message)
            }
        }
    }

    /// 移除所有已注册的 JS 处理器。
    func removeAll() async {
        let names = Array(jsHandlers.keys)
        await MainActor.run { [weak self] in
            guard let self = self else { return }
            for n in names {
                self.webView.configuration.userContentController
                    .removeScriptMessageHandler(forName: n)
            }
        }
        scriptHandlerWrappers.removeAll()
        jsHandlers.removeAll()
    }
}

// MARK: - JSBridge (public façade)
extension WebViewState {
    /// 对外公开的门面。所有实际操作委托给 `BridgeCore`，
    /// 调用方无需关注并发细节。
    public class JSBridge: @unchecked Sendable {
        /// JSBridge 透出的跨线程消息结构体
        public struct Message: @unchecked Sendable {
            public let name: String
            public let body: [String: AnyCodable]
        }

        unowned var state: WebViewState?
        private let core: BridgeCore

        init(_ webview: WKWebView) {
            self.core = BridgeCore(webView: webview)
        }
        
        /// 在任意线程可调用，注册 JS 消息处理器
        ///
        /// - 参数 name: JS 消息名称
        /// - 参数 handler: 收到消息时执行的闭包
        public func addJSHandler(
            name: String,
            handler: @MainActor @escaping (WKScriptMessage) -> Void
        ) {
            Task { [core] in
                await core.add(name: name, handler: handler)
            }
        }

        /// 移除所有 JS 处理器，可在任意线程调用。
        public func removeAllJSHandlers() {
            Task { [core] in
                await core.removeAll()
            }
        }
    }
}

extension WKScriptMessage {
    /// `WKScriptMessage.body` 的解码辅助方法。
    ///
    /// 尝试将消息体解码为 `Decodable` 类型，
    /// 支持 `Data` 或 JSON 兼容字典。
    public func decode<T: Decodable>(as type: T.Type) -> T? {
        if let data = body as? Data {
            return try? JSONDecoder().decode(T.self, from: data)
        } else if let jsonObject = body as? [String: Any],
                  let data = try? JSONSerialization.data(withJSONObject: jsonObject, options: []) {
            return try? JSONDecoder().decode(T.self, from: data)
        }
        
        return nil
    }
}
