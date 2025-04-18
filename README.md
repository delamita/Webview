# Webview

`Webview` 是一个轻量级的 SwiftUI 封装组件，提供了完整功能的网页视图支持，基于 `WKWebView` 和 Swift 5.9 的 `Observation` 构建，适用于 iOS/macOS 应用中集成网页展示与交互功能。

## 特性

- ✅ SwiftUI 原生支持
- ✅ 使用 `@Observable` 追踪状态，无需 Combine
- ✅ 加载进度、标题、URL 实时同步
- ✅ 支持加载失败、空页面等状态展示
- ✅ 支持前进/后退/刷新/执行 JavaScript
- ✅ 可自定义错误页、加载提示、重试逻辑

## 安装方式

通过 Swift Package Manager：

```
https://github.com/delamita/Webview
```

## 使用方式

```swift
import Webview

@State private var state = WebViewState()

var body: some View {
    WebView(state: state)
        .onLoadStateChange { state in
            print("当前状态：\(state)")
        }
}
```

或使用简化方式加载网址：

```swift
WebView {
    let state = WebViewState()
    state.load("https://apple.com")
    return state
}
```

## 状态监听

Webview 会提供统一状态：

```swift
enum WebLoadState {
    case idle
    case loading
    case success
    case failure(Error)
}
```

你可以根据状态自定义 UI：

```swift
switch state.loadState {
case .loading: ProgressView()
case .failure(let error): Text("加载失败：\(error.localizedDescription)")
case .idle: Text("暂无内容")
case .success: EmptyView()
}
```

## API 简介

- `state.load(_ urlString: String)`
- `state.goBack()` / `state.goForward()` / `state.reload()`
- `state.evaluateJS(_:completion:)`

## 兼容平台

- iOS 15+
- macOS 13+
- watchOS 8+
- tvOS 15+
</file>

---

欢迎贡献或反馈问题。
