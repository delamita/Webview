//
//  NativeLog.swift
//  Webview
//
//  Created by ByteDance on 4/30/25.
//

import Foundation
import WebKit
import Cedar
import AnyCodable

@Observable
public class NativeLogPlugin: WebViewState.Plugin {
    public static let identifier: String = "app.nativeLog"
    
    public unowned let state: WebViewState
    public required init(_ state: WebViewState) {
        self.state = state
    }
    
    public func pluginDidSetup() {
        evaluateNativeLog()
        state.jsbridge.addJSHandler(name: "app.base.log") { [weak self] msg in
            guard let self else { return }
            self.handleMsg(msg)
        }
    }
    
    
    @MainActor
    private func evaluateNativeLog() {
        let js = """
        window.nativelog = function(msg) {
            console.log('[NativeLogPlugin] Received log:', msg);
            if (window.webkit?.messageHandlers?.['app.base.log']) {
                window.webkit.messageHandlers['app.base.log'].postMessage(msg);
            } else {
                console.log('⚠️ [NativeLogPlugin] JSBridge not found for app.base.log');
            }
        };
        """
        state.addUserScript(js)
    }
    
    @MainActor
    private func handleMsg(_ msg: WKScriptMessage) {
        guard let log = msg.body as? String else {
            return
        }
        Cedar.webview.log(log)
    }
    
}
