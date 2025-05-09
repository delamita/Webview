//
//  WebViewState+Plugin.swift
//  Webview
//
//  Created by ByteDance on 4/21/25.
//

/// WebView 插件系统支持模块
/// - 定义插件协议 WebViewPlugin
/// - 插件注册与生命周期管理器 PluginManager
/// - 插件事件分发与通信机制

import Foundation
import WebKit

// MARK: - WebViewPlugin 协议
/// 插件协议，所有 WebView 插件必须实现此协议。
/// 插件应在初始化时注入 `WebViewState`，用于访问宿主上下文。
extension WebViewState {
    
    public protocol Plugin {
        /// 插件的唯一标识符
        static var identifier: String { get }

        /// 插件持有的 `WebViewState`，默认由框架在注册时注入。
        var state: WebViewState { get }
        
        /// 插件必须通过 state 初始化
        init(_ state: WebViewState)
        
        /// 插件依赖的其他插件类型，默认空
        static var dependencies: [Plugin.Type] { get }

        // MARK: - 生命周期方法
        
        /// 插件已完成初始化
        @MainActor
        func pluginDidSetup()
        
        /// 插件即将被销毁（WebViewState 销毁前）
        func pluginWillDestroy()
        
        /// 手动Url加载事件处理
        func stateWillLoadUrl(_ url: String)
        
        // MARK: - WebView 事件处理
        
        /// WebView 开始加载页面
        /// - Parameter url: 即将加载的页面地址
        @MainActor
        func webViewDidStartNavigation(url: URL?)
        
        /// WebView 加载完成
        /// - Parameter url: 已加载的页面地址
        @MainActor
        func webViewDidFinishNavigation(url: URL?)
        
        /// WebView 加载失败
        /// - Parameters:
        ///   - url: 加载失败的页面地址
        ///   - error: 发生的错误
        @MainActor
        func webViewDidFailNavigation(url: URL?, withError error: Error)
        
        // MARK: - 插件通信
        
        /// 用户点击了返回按钮（可用于记录行为）
        @MainActor
        func webViewGoBack()
        
        /// 用户点击了前进按钮
        @MainActor
        func webViewGoForward()

        /// 接收来自其他插件的消息，并可选回调处理结果。
        /// - Parameters:
        ///   - sender: 发送消息的插件对象
        ///   - message: 任意消息体
        ///   - respond: 回调闭包，可在处理完成后返回结果
        func receivePluginMessage(from sender: Plugin, message: Any, respond: ((Any?) -> Void)?)
    }
}


// MARK: - 协议默认实现扩展
extension WebViewState.Plugin {
    /// 插件依赖的其他插件类型，默认空
    public static var dependencies: [WebViewState.Plugin.Type] { [] }
    
    /// 插件已完成初始化
    @MainActor
    public func pluginDidSetup() {}
    
    /// 插件即将被销毁
    public func pluginWillDestroy() {}
    
    
    public func webviewDidSetup() {}
    
    /// 手动Url加载事件处理
    public func stateWillLoadUrl(_ url: String) {}
    
    /// WebView 开始加载页面
    public func webViewDidStartNavigation(url: URL?) {}
    
    /// WebView 加载完成
    public func webViewDidFinishNavigation(url: URL?) {}
    
    /// WebView 加载失败
    public func webViewDidFailNavigation(url: URL?, withError error: Error) {}
    
    /// 用户点击了后退按钮
    public func webViewGoBack() {}
    
    /// 用户点击了前进按钮
    public func webViewGoForward() {}
    
    /// 接收来自其他插件的消息
    /// - Parameters:
    ///   - sender: 发送插件对象
    ///   - message: 任意消息体
    ///   - respond: 可选回调
    public func receivePluginMessage(from sender: WebViewState.Plugin, message: Any, respond: ((Any?) -> Void)?) {
        respond?(nil)
    }
}


// MARK: - PluginManager 类
/// 插件管理器，负责注册插件、转发事件与插件间通信。
/// 每个 WebViewState 实例对应一个独立的 PluginManager。
extension WebViewState {
    
    public class PluginManager {
        
        @MainActor
        public weak var state: WebViewState? {
            didSet {
                reloadPlugins()
            }
        }
        
        private var plugins: [String: Plugin] = [:]
        
        deinit {
            pluginWillDestroy()
        }

        /// 根据类型查找插件实例
        public func plugin<T: Plugin>(_ pluginType: T.Type) -> T? {
            plugins.values.first { $0 is T } as? T
        }

        // MARK: - 插件注册与访问
        
        /// 注册插件类型，若 identifier 相同将覆盖旧插件
        /// - Parameter pluginType: 插件类型
        @MainActor
        @discardableResult
        public func register(_ pluginType: Plugin.Type) -> Self {
            guard let state = state else { return self }

            // 如果已经注册过，跳过
            if plugins[pluginType.identifier] != nil {
                return self
            }

            // 递归注册依赖
            for dependency in pluginType.dependencies {
                register(dependency)
            }

            // 注册当前插件
            let plugin = pluginType.init(state)
            plugins[pluginType.identifier] = plugin
            plugin.pluginDidSetup()
            return self
        }

        /// 注册插件实例
        /// - Parameter plugin: 插件实例
        @MainActor
        @discardableResult
        public func register(_ plugin: Plugin) -> Self {
            plugins[type(of: plugin).identifier] = plugin
            plugin.pluginDidSetup()
            return self
        }

        /// 获取所有已注册插件
        /// - Returns: 所有插件的数组
        public var allPlugins: [Plugin] {
            Array(plugins.values)
        }

        // MARK: - 插件事件分发
        
        /// 重新加载所有插件
        @MainActor
        @discardableResult
        public func reloadPlugins() -> Self {
            guard let state = state else { return  self }
            let types = plugins.values.map { type(of: $0) }
            pluginWillDestroy()
            plugins.removeAll()
            for type in types {
                let plugin = type.init(state)
                plugins[type.identifier] = plugin
                plugin.pluginDidSetup()
            }
            return self
        }
    }
}

// MARK: - PluginManager 事件转发
extension WebViewState.PluginManager {
    
    /// 通知所有插件：插件即将被销毁
    public func pluginWillDestroy() {
        plugins.values.forEach { $0.pluginWillDestroy() }
    }
    
    /// 通知所有插件：手动Url加载事件
    func stateWillLoadUrl(_ url: String) {
        plugins.values.forEach { $0.stateWillLoadUrl(url) }
    }

    /// 通知所有插件：WebView 开始加载页面
    /// - Parameter url: 即将加载的页面地址
    @MainActor
    public func webViewDidStartNavigation(url: URL?) {
        plugins.values.forEach { $0.webViewDidStartNavigation(url: url) }
    }

    /// 通知所有插件：WebView 加载完成
    /// - Parameter url: 已加载的页面地址
    @MainActor
    public func webViewDidFinishNavigation(url: URL?) {
        plugins.values.forEach { $0.webViewDidFinishNavigation(url: url) }
    }

    /// 通知所有插件：WebView 加载失败
    /// - Parameters:
    ///   - url: 加载失败的页面地址
    ///   - error: 发生的错误
    @MainActor
    public func webViewDidFailNavigation(url: URL?, withError error: Error) {
        plugins.values.forEach { $0.webViewDidFailNavigation(url: url, withError: error) }
    }

    /// 通知所有插件：用户点击了返回按钮
    @MainActor
    public func webViewGoBack() {
        plugins.values.forEach { $0.webViewGoBack() }
    }

    /// 通知所有插件：用户点击了前进按钮
    @MainActor
    public func webViewGoForward() {
        plugins.values.forEach { $0.webViewGoForward() }
    }

    /// 向指定插件发送消息。
    /// - Parameters:
    ///   - identifier: 接收插件标识符
    ///   - sender: 发送插件对象
    ///   - message: 任意消息体
    ///   - respond: 可选响应回调
    public func sendMessage(
        to identifier: String,
        from sender: WebViewState.Plugin,
        message: Any,
        respond: ((Any?) -> Void)? = nil
    ) {
        plugins[identifier]?.receivePluginMessage(from: sender, message: message, respond: respond)
    }
    
    /// 保证AppBase在其他JS前注册
    @MainActor
    func addAppBaseJS() {
        let js = """
        window.native = {};
        window.native.base = {};
        """
        state?.addUserScript(js)
    }
}




extension WebViewState.PluginManager {
    
    @MainActor
    public func registBasePlugins() {
        appBasePlugins.forEach { pluginType in
            register(pluginType)
        }
    }
    
    
    public var appBasePlugins: [WebViewState.Plugin.Type] {
        [
            AppBase.self,
            NativeLogPlugin.self,
            TemplateManager.self,
        ]
    }
    
}

