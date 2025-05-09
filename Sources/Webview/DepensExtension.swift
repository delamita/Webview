//
//  WebViewState+Log.swift
//  Webview
//
//  Created by ByteDance on 4/30/25.
//

import Foundation
import Cedar
import Canopy


let webViewLogger = Cedar.Module(name: "Webview")

extension Cedar {
    
    public static var webview: Cedar.Module {
        get {
            webViewLogger
        }
    }
    
}

func log(level: Cedar.Level = .debug, _ items: Any...) {
    Cedar.webview.log(level: level, items)
}
