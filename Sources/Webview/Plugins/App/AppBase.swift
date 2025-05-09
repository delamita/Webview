//
//  AppBase.swift
//  Webview
//
//  Created by ByteDance on 5/8/25.
//

import Foundation
import WebKit

@Observable
public class AppBase: WebViewState.Plugin {
    public static let identifier: String = "app.base"
    
    public unowned let state: WebViewState
    public required init(_ state: WebViewState) {
        self.state = state
    }
    
    public func webViewDidFinishNavigation(url: URL?) {
        evaluateNativeLog()
    }
    
    
    @MainActor
    private func evaluateNativeLog() {
        let js = """
        window.app = window.app || {};
        window.app.base = window.app.base || {};
        """
        state.evaluateJS(js)
    }
    
}
