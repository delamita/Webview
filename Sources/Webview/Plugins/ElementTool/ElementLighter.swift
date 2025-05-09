//
//  ElementHeighter.swift
//  Webview
//
//  Created by ByteDance on 4/29/25.
//

import Foundation

public class ElementLighterPlugin : WebViewState.Plugin {
    public static let identifier: String = "element.lighter"
    
    public unowned let state: WebViewState
    
    public required init(_ state: WebViewState) {
        self.state = state
    }
    
    public func pluginDidSetup() {
        injectHighlighterJS()
    }
    
    @MainActor
    private func injectHighlighterJS() {
        let js = """
        window.highlightSimilarElementsByTemplate = function(element) {
            if (!element || !Array.isArray(element.chain)) {
                window.nativelog('[Highlighter] Invalid element or missing chain');
                return;
            }

            // Inject style directly here
            if (!document.getElementById('__cedar_highlight_style')) {
                const style = document.createElement('style');
                style.id = '__cedar_highlight_style';
                document.head.appendChild(style);
                const css = ".cedar-element-highlight {\
                    position: absolute !important;\
                    background-color: rgba(255, 192, 203, 0.3) !important;\
                    pointer-events: none !important;\
                    z-index: 2147483647 !important;\
                }";
                style.appendChild(document.createTextNode(css));
            }

            function matchNode(el, node) {
                if (node.tag && el.tagName.toLowerCase() !== node.tag.toLowerCase()) return false;
                if (node.id && el.id !== node.id) return false;
                if (node.className && el.className !== node.className) return false;
                if (node.textContains && !el.innerText?.includes(node.textContains)) return false;
                return true;
            }

            function walkChain(root, chain, depth = 0) {
                if (depth >= chain.length) return [root];
                const node = chain[depth];
                const candidates = Array.from(root.querySelectorAll(node.tag || '*')).filter(el => matchNode(el, node));
                return candidates.flatMap(el => walkChain(el, chain, depth + 1));
            }

            // Clear previous highlights
            document.querySelectorAll('.cedar-element-highlight').forEach(el => {
                el.remove();
            });

            const matches = walkChain(document, element.chain);
            matches.forEach(el => {
                const rect = el.getBoundingClientRect();
                const overlay = document.createElement('div');
                overlay.className = 'cedar-element-highlight';
                overlay.style.top = rect.top + window.scrollY + 'px';
                overlay.style.left = rect.left + window.scrollX + 'px';
                overlay.style.width = rect.width + 'px';
                overlay.style.height = rect.height + 'px';
                document.body.appendChild(overlay);
            });

            window.nativelog('[Highlighter] Matched ' + matches.length + ' elements');
        };
        """
        state.addUserScript(js)
    }
    
    @MainActor
    public func highlightSimilarElements(basedOn element: Element) {
        guard let json = try? JSONEncoder().encode(element),
              let jsonStr = String(data: json, encoding: .utf8)
        else {
            log("[ElementLighter] Encoding element to JSON failed")
            return
        }

        let call = "window.highlightSimilarElementsByTemplate(\(jsonStr))"
        state.evaluateJS(call)
    }
    
}
