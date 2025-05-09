//
//  VideoDetectPlugin.swift
//  Webview
//
//  Created by ByteDance on 4/21/25.
//

import Foundation
import WebKit
import Cedar

// 视频信息模型，用于从 JS 解码消息体
public struct VideoInfo: Decodable {
    public let src: String
    public let type: String
    public let from: String?
    public let title: String?
    
    
    public init(src: String, type: String, from: String?, title: String?) {
        self.src = src
        self.type = type
        self.from = from
        self.title = title
    }
}

public class VideoDetectPlugin : WebViewState.Plugin {
    
    public static let identifier: String = "video.finder"
    public unowned let state: WebViewState
    
    public required init(_ state: WebViewState) {
        self.state = state
    }
    
    public func pluginDidSetup() {

    }
    
    public func webViewDidFinishNavigation(url: URL?) {
        // 注入 video 检测脚本   
    }
}

/// 通用视频嗅探插件：通过 hook video 和 XHR 检测 .mp4 / .m3u8 链接
public class UniversalVideoSnifferPlugin: WebViewState.Plugin {
    
    public static let identifier = "video.universal.sniffer"
    public unowned let state: WebViewState

    public required init(_ state: WebViewState) {
        self.state = state
    }
    public func webViewDidFinishNavigation(url: URL?) {
        let state = self.state
        Task { @MainActor in
            let js = """
            (function () {
                console.log("[Sniffer] Injecting video sniffing script");
                const seen = new Set();
            
                document.querySelectorAll('video').forEach(v => {
                    const src = v.currentSrc || v.src;
                    console.log("[Sniffer] Found existing video:", src);
                    report(src, 'video', 'querySelector');
                });

                function report(src, type, method) {
                    if (!src || seen.has(src)) return;
                    seen.add(src);
                    console.log("[Sniffer] Reporting:", { src, type, method });
                    window.webkit?.messageHandlers?.UniversalVideoFinder?.postMessage({
                        src: src,
                        type: type || '',
                        from: method || 'hook',
                        title: document.title || ''
                    });
                }

                console.log("[Sniffer] Hooking document.createElement");
                const realCreate = document.createElement;
                document.createElement = function(tag) {
                    const el = realCreate.call(this, tag);
                    if (tag === 'video') {
                        setTimeout(() => {
                            console.log("[Sniffer] Created video element:", el);
                            report(el.currentSrc || el.src, 'video', 'createElement');
                        }, 500);
                    }
                    return el;
                };

                console.log("[Sniffer] Hooking XMLHttpRequest.open");
                const open = XMLHttpRequest.prototype.open;
                XMLHttpRequest.prototype.open = function() {
                    this.addEventListener('load', function() {
                        if (this.responseURL.match(/\\.m3u8|\\.mp4/i)) {
                            console.log("[Sniffer] XHR loaded:", this.responseURL);
                            report(this.responseURL, 'xhr', 'xhr');
                        }
                    });
                    return open.apply(this, arguments);
                };

                console.log("[Sniffer] Hooking fetch");
                const originalFetch = window.fetch;
                window.fetch = function (...args) {
                    return originalFetch.apply(this, args).then(response => {
                        try {
                            const url = response?.url || '';
                            if (url.match(/\\.m3u8|\\.mp4/i)) {
                                console.log("[Sniffer] fetch() caught:", url);
                                report(url, 'fetch', 'fetch');
                            }
                        } catch (e) {
                            console.log("[Sniffer] fetch error:", e);
                        }
                        return response;
                    });
                };
                window.fetch.toString = function () {
                    return originalFetch.toString();
                };
            })();
            """
            
            state.jsbridge.addJSHandler(name: "UniversalVideoFinder") { message in
                Task { @MainActor in
                    do {
                        let raw = try JSONSerialization.data(withJSONObject: message.body, options: [])
                        let video = try JSONDecoder().decode(VideoInfo.self, from: raw)
                        Cedar.webview.log("🎯 通用嗅探捕获:", video)
                    } catch {
                        print("❌ 解码失败:", error)
                    }
                }
            }
            
            let userScript = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            state.webView.configuration.userContentController.addUserScript(userScript)
            
            
        }
    }
}
