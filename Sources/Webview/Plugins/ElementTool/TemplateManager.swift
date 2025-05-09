//
//  TemplateManager.swift
//  Webview
//
//  Created by ByteDance on 5/7/25.
//

import Foundation
import WebKit


public class TemplateManager : WebViewState.Plugin {
    
    public static var dependencies: [any WebViewState.Plugin.Type] {
        [ElementPickerPlugin.self, ElementLighterPlugin.self]
    }
    
    public static let identifier: String = "element.tmpManager"
    
    public unowned let state: WebViewState
    
    

    public required init(_ state: WebViewState) {
        self.state = state
    }
    
    public func pluginDidSetup() {
        state.jsbridge.addJSHandler(name: "plugin.element.template") { [weak self] msg in
            guard let self else { return }
            self.handleMsg(msg)
        }
        injectPickerJS()
    }
    
    @MainActor
    private func injectPickerJS() {
        let js = """
        window.createElementTemplateFromElement = function(el) {
            console.log("[ElementTemplate] did recieved");
            window.nativelog("[ElementTemplate] recieved el", el);
            if (!el) return null;

            const toNode = (node) => {
                return {
                    tag: node.tagName?.toLowerCase() || null,
                    requiredAttributes: (() => {
                        const map = {};
                        for (const attr of node.attributes) {
                          const name = attr.name;
                          if (
                            name.startsWith("data-") && name.match(/^data-v-[0-9a-f]+$/)
                          ) {
                            continue; // 🚫 跳过 Vue scoped 标记
                          }

                          if (
                            name.startsWith("data-") ||
                            name === "role" ||
                            name === "type" ||
                            name === "id" ||
                            name === "class" ||
                            name.startsWith("aria-") ||
                            name === "name"
                          ) {
                            map[name] = attr.value;
                          }
                        }
                        return Object.keys(map).length > 0 ? map : null;
                    })(),
                    textContains: (() => {
                        const text = node.innerText?.trim();
                        return text?.length > 0 ? text : null;
                    })()
                };
            };

            const chain = [];
            let current = el;
            while (current && current !== document.body && chain.length < 5) {
                chain.unshift(toNode(current));
                current = current.parentElement;
            }

            const template = {
                chain: chain,
                allowMultiple: true
            };

            window.nativelog("[ElementTemplate] Created:", template);

            if (window.webkit?.messageHandlers?.['plugin.element.template']) {
                window.webkit.messageHandlers['plugin.element.template'].postMessage(template);
            }
        };
        """
        state.addUserScript(js)
    }
    
    
    
    @MainActor
    private func handleMsg(_ msg: WKScriptMessage) {
        log("[ElementTmpManager] Received template:", msg.body)
    }
    
    
    
}
