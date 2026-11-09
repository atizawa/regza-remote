public import Foundation
package import RegzaDomain

/// ViewModel を外から読み、操作するための口 (Shopify の Reflex の Introspection Kit と同じ考え方)。
/// CLI や AI のエージェントが、画面を通さずに状態を JSON で読み、操作を名前と引数で送る。アプリ自身は使わない
@MainActor
public protocol Introspectable: AnyObject {
    /// 道 (`app/channels` など) の 1 つ分の名前
    var introspectionName: String { get }
    /// 状態。既定では `introspectionValue` を JSON にする
    var introspectionState: JSONValue { get }
    /// JSON にする値 (Elm 風の ViewModel なら state)
    var introspectionValue: Any { get }
    /// 受け付ける操作
    var introspectionActions: [ActionDescription] { get }
    /// 名前と引数で操作する
    func perform(_ action: String, _ arguments: [String: JSONValue]) throws
    /// いま開いている画面など、下にある ViewModel
    var introspectionChildren: [any Introspectable] { get }
    /// 通信などの途中か (CLI は終わるのを待ってから次の操作を送る)
    var isBusy: Bool { get }
    /// 道の名前を変えて見せているときの、元の ViewModel (ふつうは自分)
    var introspectionTarget: any Introspectable { get }
}

extension Introspectable {
    public var introspectionState: JSONValue { JSONValue(reflecting: introspectionValue) }
    public var introspectionChildren: [any Introspectable] { [] }
    public var isBusy: Bool { false }
    public var introspectionTarget: any Introspectable { self }
}

/// 名前と引数の操作を、画面の Action の型に置き換えられる ViewModel。置き換えは 1 か所 (action(_:_:)) に書き、
/// CLI (perform) と Android の振る舞いのテストの相手 (置き換えた Action を Android と同じ道で送る) の両方で使う
@MainActor
public protocol IntrospectableActions: Introspectable {
    associatedtype State
    associatedtype Action
    var state: State { get }
    /// 名前と引数の操作を Action にする (その状態ではできない操作なら投げる)
    func action(_ name: String, _ arguments: [String: JSONValue]) throws -> Action
    func send(_ action: Action)
    /// CLI と振る舞いのテストに見せる state の JSON。既定は state をそのまま JSON にする
    /// (大きいものは要約し、パスワードは伏せる。Android 側の相手も、受け取った state をこれで JSON にする)
    nonisolated static func introspectionJSON(of state: State) -> JSONValue
}

extension IntrospectableActions {
    public var introspectionValue: Any { Self.introspectionJSON(of: state) }

    nonisolated public static func introspectionJSON(of state: State) -> JSONValue {
        JSONValue(reflecting: state)
    }

    public func perform(_ action: String, _ arguments: [String: JSONValue]) throws {
        send(try self.action(action, arguments))
    }
}

/// 同じ種類の ViewModel がいくつも開いているとき (タブごとの戻る道など) に、道の名前を変えて見せる
@MainActor
final class IntrospectionAlias: Introspectable {
    let introspectionName: String
    let target: any Introspectable

    init(_ name: String, _ target: any Introspectable) {
        introspectionName = name
        self.target = target
    }

    var introspectionState: JSONValue { target.introspectionState }
    var introspectionValue: Any { target.introspectionValue }
    var introspectionActions: [ActionDescription] { target.introspectionActions }
    var introspectionChildren: [any Introspectable] { target.introspectionChildren }
    var isBusy: Bool { target.isBusy }
    var introspectionTarget: any Introspectable { target.introspectionTarget }
    func perform(_ action: String, _ arguments: [String: JSONValue]) throws { try target.perform(action, arguments) }
}

/// 操作の説明。引数は 名前 → 説明
public struct ActionDescription: Codable, Equatable, Sendable {
    public var name: String
    public var summary: String
    public var parameters: [String: String]

    public init(_ name: String, _ summary: String, parameters: [String: String] = [:]) {
        self.name = name
        self.summary = summary
        self.parameters = parameters
    }
}

public enum IntrospectionError: Error, Equatable, CustomStringConvertible {
    case unknownPath(String)
    case unknownAction(String)
    case missingArgument(String)
    case invalidArgument(String)
    /// その状態ではできない操作 (選ぶチャンネルが一覧にないなど)
    case unavailable(String)

    public var description: String {
        switch self {
        case .unknownPath(let path): "\(path) という ViewModel はありません"
        case .unknownAction(let name): "\(name) という操作はありません"
        case .missingArgument(let name): "引数 \(name) がありません"
        case .invalidArgument(let name): "引数 \(name) の値が正しくありません"
        case .unavailable(let reason): reason
        }
    }
}

/// ViewModel とその下の ViewModel の、状態と操作の一覧
public struct IntrospectionNode: Codable, Equatable, Sendable {
    public var name: String
    public var path: String
    public var isBusy: Bool
    public var state: JSONValue
    public var actions: [ActionDescription]
    public var children: [String]
}

/// 道で ViewModel を探し、読み、操作する
@MainActor
public struct Introspector {
    public let root: any Introspectable

    public init(root: any Introspectable) {
        self.root = root
    }

    /// `app/channels` のような道の ViewModel
    public func find(_ path: String) throws(IntrospectionError) -> any Introspectable {
        let names = path.split(separator: "/").map(String.init)
        guard names.first == root.introspectionName else { throw .unknownPath(path) }
        var current = root
        for name in names.dropFirst() {
            guard let child = current.introspectionChildren.first(where: { $0.introspectionName == name }) else {
                throw .unknownPath(path)
            }
            current = child
        }
        return current
    }

    public func node(_ path: String) throws(IntrospectionError) -> IntrospectionNode {
        let target = try find(path)
        let path = path.split(separator: "/").joined(separator: "/")
        return IntrospectionNode(
            name: target.introspectionName,
            path: path,
            isBusy: target.isBusy,
            state: target.introspectionState,
            actions: target.introspectionActions,
            children: target.introspectionChildren.map { "\(path)/\($0.introspectionName)" }
        )
    }

    /// すべての ViewModel の道
    public func paths() -> [String] {
        func walk(_ node: any Introspectable, _ prefix: String) -> [String] {
            let path = prefix.isEmpty ? node.introspectionName : "\(prefix)/\(node.introspectionName)"
            return [path] + node.introspectionChildren.flatMap { walk($0, path) }
        }
        return walk(root, "")
    }

    public func perform(_ path: String, _ action: String, _ arguments: [String: JSONValue] = [:]) throws {
        try find(path).perform(action, arguments)
    }

    /// どの ViewModel も通信などの途中でなくなるまで待つ。`timeout` 秒たったら false
    public func waitUntilIdle(timeout: TimeInterval = 15) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        // 操作を送った直後は、まだ通信が始まっていないことがあるので少し待つ
        try? await Task.sleep(for: .milliseconds(50))
        while Date() < deadline {
            if !anyBusy(root) { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return false
    }

    private func anyBusy(_ node: any Introspectable) -> Bool {
        node.isBusy || node.introspectionChildren.contains(where: anyBusy)
    }
}

extension [String: JSONValue] {
    /// 文字列の引数
    public func string(_ name: String) throws(IntrospectionError) -> String {
        guard let value = self[name] else { throw .missingArgument(name) }
        guard case .string(let text) = value else { throw .invalidArgument(name) }
        return text
    }

    /// 数の引数
    public func int(_ name: String) throws(IntrospectionError) -> Int {
        guard let value = self[name] else { throw .missingArgument(name) }
        switch value {
        case .number(let number) where number == number.rounded(): return Int(number)
        case .string(let text): if let number = Int(text) { return number }
        default: break
        }
        throw .invalidArgument(name)
    }

    /// 真偽の引数 (なければ false)
    public func bool(_ name: String) throws(IntrospectionError) -> Bool {
        switch self[name] {
        case nil: return false
        case .bool(let flag): return flag
        default: throw .invalidArgument(name)
        }
    }
}

/// JSON の値。状態を外に見せるときと、操作の引数に使う
public enum JSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else { self = .object(try container.decode([String: JSONValue].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    /// 構造体・enum・配列などを、プロパティの名前をキーにした JSON の値にする (Mirror で中を見る)。
    /// 日時は ISO 8601 の文字列、値のない enum は case の名前、値を持つ enum は `{"case名": 値}` にする
    public init(reflecting value: Any) {
        switch value {
        case let value as JSONValue: self = value
        case let value as String: self = .string(value)
        case let value as Bool: self = .bool(value)
        case let value as Int: self = .number(Double(value))
        case let value as Double: self = .number(value)
        case let value as Date: self = .string(value.formatted(.iso8601))
        case let value as URL: self = .string(value.absoluteString)
        case let value as any RawRepresentable<String>: self = .string(value.rawValue)
        default: self = Self.reflect(Mirror(reflecting: value), value)
        }
    }

    private static func reflect(_ mirror: Mirror, _ value: Any) -> JSONValue {
        switch mirror.displayStyle {
        case .optional:
            return mirror.children.first.map { JSONValue(reflecting: $0.value) } ?? .null
        case .collection, .set:
            return .array(mirror.children.map { JSONValue(reflecting: $0.value) })
        case .dictionary:
            var object: [String: JSONValue] = [:]
            for pair in mirror.children {
                let entry = Mirror(reflecting: pair.value).children.map(\.value)
                guard entry.count == 2 else { continue }
                let key = JSONValue(reflecting: entry[0])
                object[key.text ?? "\(entry[0])"] = JSONValue(reflecting: entry[1])
            }
            return .object(object)
        case .enum:
            guard let payload = mirror.children.first else { return .string("\(value)") }
            return .object([payload.label ?? "\(value)": JSONValue(reflecting: payload.value)])
        case .tuple:
            let children = Array(mirror.children)
            if children.allSatisfy({ $0.label?.hasPrefix(".") ?? true }) {
                return .array(children.map { JSONValue(reflecting: $0.value) })
            }
            return .object(Dictionary(children.enumerated().map { index, child in
                (child.label ?? String(index), JSONValue(reflecting: child.value))
            }, uniquingKeysWith: { first, _ in first }))
        case .struct, .class:
            var object: [String: JSONValue] = [:]
            for child in mirror.children {
                guard let label = child.label else { continue }
                // @Observable などが付けるもの (_ で始まる) は名前から _ を外す
                object[label.hasPrefix("_") ? String(label.dropFirst()) : label] = JSONValue(reflecting: child.value)
            }
            return .object(object)
        default:
            if let number = value as? any BinaryInteger { return .number(Double(number)) }
            if let number = value as? any BinaryFloatingPoint { return .number(Double(number)) }
            return .string("\(value)")
        }
    }

    var text: String? {
        switch self {
        case .string(let text): text
        case .number(let number): number == number.rounded() ? String(Int(number)) : String(number)
        case .bool(let flag): String(flag)
        default: nil
        }
    }

    /// 整えた JSON の文字列 (キーは並べ替える)
    public var json: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(self)).map { String(decoding: $0, as: UTF8.self) } ?? "null"
    }
}
