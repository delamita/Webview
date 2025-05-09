//
//  ElementPicker.swift
//  Webview
//
//  Created by ByteDance on 4/29/25.
//

import Foundation
import WebKit
import AnyCodable
import Cedar
import Canopy

@Observable
public class ElementPickerPlugin: WebViewState.Plugin {
    public static let identifier: String = "element.picker"
    public unowned let state: WebViewState
    
    @MainActor
    public var pickedElement: Element? = nil

    public required init(_ state: WebViewState) {
        self.state = state
    }
    
    public func pluginDidSetup() {
        setupPickerJS()
        state.jsbridge.addJSHandler(name: "plugin.element.picker") { [weak self] msg in
            guard let self else { return }
            self.handleMsg(msg)
        }
    }
    
    public func webViewDidFinishNavigation(url: URL?) {
        enableElementPicker()
    }
    
    @MainActor
    private func handleMsg(_ msg: WKScriptMessage) {
        guard let element = msg.decode(as: Element.self) else { return }
        pickedElement = element
        state.plugin.plugin(ElementLighterPlugin.self)?.highlightSimilarElements(basedOn: element)
        
        
        
    }

    // 注入 JS 脚本
    @MainActor
    private func setupPickerJS() {
        let js = """
        window.enableElementPicker = function() {
            window.nativelog('[ElementPicker] Picker mode enabled');

            // 清除旧监听
            if (window._disableClickBehavior) {
                document.removeEventListener('click', window._disableClickBehavior, true);
            }
            if (window._elementPickerHandler) {
                document.removeEventListener('click', window._elementPickerHandler, true);
            }
            // 阻止默认点击行为
            const disableClickBehavior = (e) => {
                e.preventDefault();
                e.stopPropagation();
            };
            window._disableClickBehavior = disableClickBehavior;
            document.addEventListener('click', disableClickBehavior, true);

            // 生成路径的辅助函数
            const getPath = (el) => {
                const path = [];
                while (el && el !== document.body) {
                    let index = 0;
                    let sibling = el;
                    while (sibling = sibling.previousElementSibling) index++;
                    path.unshift(index);
                    el = el.parentElement;
                }
                return path;
            };

            // 元素选择回调
            const handler = function(e) {
                e.preventDefault();
                e.stopPropagation();

                const el = e.target;

                const buildElement = (el, includeOuterHTML = false) => {
                    return {
                        tag: el.tagName,
                        id: el.id || null,
                        className: el.className || null,
                        innerText: el.innerText?.trim() || null,
                        outerHTML: includeOuterHTML ? (el.outerHTML || null) : null
                    };
                };

                const buildChain = (el) => {
                    const chain = [];
                    let current = el;
                    while (current && current !== document.body) {
                        chain.unshift(buildElement(current, false));
                        current = current.parentElement;
                    }
                    return chain;
                };

                const info = buildElement(el, true);
                info.path = getPath(el);
                info.chain = buildChain(el);
                window.nativelog('[ElementPicker] Picked:', info);
        
                if (window.createElementTemplateFromElement) {
                    window.createElementTemplateFromElement(el);
                }
        
                if (window.webkit?.messageHandlers?.['plugin.element.picker']) {
                    window.webkit.messageHandlers['plugin.element.picker'].postMessage(info);
                } else {
                    window.nativelog('[ElementPicker] JSBridge handler not found!');
                }
            };
        

            window._elementPickerHandler = handler;
            document.addEventListener('click', handler, true);
        };
        """
        state.addUserScript(js)
    }
    
    @MainActor
    private func enableElementPicker() {
        state.evaluateJS("window.enableElementPicker()")
    }
}
