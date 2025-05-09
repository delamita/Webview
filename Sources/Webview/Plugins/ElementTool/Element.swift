//
//  Element.swift
//  Webview
//
//  Created by ByteDance on 4/30/25.
//

import WebKit
import Foundation

// MARK: - ElementTemplatable

/// 抽象网页元素接口，用于统一访问 DOM 信息结构，
/// 可作为匹配模板使用，不包含具体页面状态或几何信息。
public protocol ElementTemplatable: Codable, Equatable, Hashable {
    /// HTML 标签名，例如 "DIV"
    var tag: String { get }

    /// 元素的 DOM id，可能为空
    var id: String? { get }

    /// class 属性，原始 className 字符串
    var className: String? { get }

    /// DOM 索引路径（可用于快速定位）
    var path: [Int]? { get }

    /// 从根节点到当前节点的完整结构链
    var chain: [Self]? { get }

    /// 附加属性字段（原始提取的属性）
    var attr: [String]? { get }
}


// MARK: - ElementTemplate

/// 元素结构模板，仅描述结构，不包含位置信息。
///
/// 可用于匹配页面中所有符合结构的 DOM 元素。
public struct ElementTemplate: ElementTemplatable {
    public let tag: String
    public let id: String?
    public let className: String?
    public let path: [Int]?
    public let chain: [ElementTemplate]?
    public let attr: [String]?
}


// MARK: - ElementRect

/// 表示一个元素在页面上的矩形框几何信息，单位为像素。
///
/// 所有值基于 `getBoundingClientRect()`，
/// 可用于高亮、定位、滚动或比对元素位置。
public struct ElementRect: Codable, Equatable, Hashable {
    public let top: Double
    public let left: Double
    public let width: Double
    public let height: Double
}

// MARK: - ElementModel

/// 具体网页元素协议，表示具有页面中实例信息的元素，
/// 比如文本、几何位置、完整 HTML 结构等。
public protocol ElementModel: ElementTemplatable {
    /// 元素的可见文本内容（用于展示、匹配）
    var innerText: String? { get }

    /// 元素在页面中的矩形区域信息
    var boundingRect: ElementRect? { get }

    /// 元素完整的 outerHTML 内容
    var outerHTML: String? { get }
}

// MARK: - Element

/// 表示网页中一个完整的 DOM 元素实例。
///
/// 包含 HTML 基础属性、页面几何信息、内容、路径等，
/// 可用于插件间传递、AI 目标识别、点击拾取等。
public struct Element: ElementModel {
    public let tag: String
    public let id: String?
    public let className: String?
    public let innerText: String?
    public let boundingRect: ElementRect?
    public let outerHTML: String?
    public let pickId: String?

    public var path: [Int]?
    public var chain: [Element]?
    public var attr: [String]?
}
