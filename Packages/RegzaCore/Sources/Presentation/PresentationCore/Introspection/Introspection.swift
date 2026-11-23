public import Foundation
import RegzaDomain

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

extension Introspectable {
    /// 通信などの途中でなくなるまで待つ。見回らず、isBusy が読む値が変わったときだけ確かめ直す
    public func waitUntilIdle() async {
        await waitUntil { !self.isBusy }
    }
}

/// 名前と引数の操作を、画面の Action の型に置き換えられる ViewModel。置き換えは操作の表 (introspectionTable) の 1 か所に書き、
/// CLI (perform) と Android の振る舞いのテストの相手 (置き換えた Action を Android と同じ道で送る) の両方で使う。
/// 操作の一覧 (introspectionActions) と置き換え (action(_:_:)) は、表から作る
@MainActor
public protocol IntrospectableActions: Introspectable {
    associatedtype State
    associatedtype Action
    var state: State { get }
    /// 受け付ける操作の表。操作ごとに、名前・説明・引数と、引数の値から Action を作る処理を 1 つにまとめる
    var introspectionTable: [IntrospectionAction<Action>] { get }
    /// 名前と引数の操作を Action にする (その状態ではできない操作なら投げる)。既定では表から引く
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

    public var introspectionActions: [ActionDescription] { introspectionTable.map(\.description) }

    public func action(_ name: String, _ arguments: [String: JSONValue]) throws -> Action {
        guard let entry = introspectionTable.first(where: { $0.description.name == name }) else {
            throw IntrospectionError.unknownAction(name)
        }
        return try entry.make(arguments)
    }
}

/// 受け付ける操作 1 つ。名前・説明・引数と、引数の値から Action を作る処理を 1 か所に書く
/// (一覧に見せる名前と引数が、受け付ける名前と読む引数から作られ、ずれようがないように)
@MainActor
public struct IntrospectionAction<Action> {
    /// 一覧に見せる説明 (引数の名前と説明は、引数から作る)
    public let description: ActionDescription
    let make: @MainActor ([String: JSONValue]) throws -> Action

    /// 引数を読み、その値で Action を作る操作 (その状態ではできない操作なら、make が投げる)
    public init<each Value>(
        _ name: String, _ summary: String, _ parameters: repeat ActionParameter<each Value>,
        make: @escaping @MainActor (repeat each Value) throws -> Action
    ) {
        var descriptions: [String: String] = [:]
        // 同じ名前の引数は書かない (ソースの見張り SourceGuards が確かめる)
        for parameter in repeat each parameters { descriptions[parameter.name] = parameter.summary }
        description = ActionDescription(name, summary, parameters: descriptions)
        self.make = { arguments in try make(repeat try (each parameters).read(in: arguments)) }
    }

    /// 引数のない、いつでも送れる操作
    public init(_ name: String, _ summary: String, _ action: Action) {
        description = ActionDescription(name, summary)
        make = { _ in action }
    }

    private init(description: ActionDescription, make: @escaping @MainActor ([String: JSONValue]) throws -> Action) {
        self.description = description
        self.make = make
    }

    /// 部品の操作を、親の操作にする (名前に接頭辞を付け、Action を親の Action の case に入れる)
    public func prefixed<Parent>(_ prefix: String, _ transform: @escaping (Action) -> Parent) -> IntrospectionAction<Parent> {
        let make = make
        return IntrospectionAction<Parent>(
            description: ActionDescription(prefix + description.name, description.summary, parameters: description.parameters),
            make: { transform(try make($0)) })
    }
}

/// 操作の引数 1 つ。名前・説明と、JSON の値の読み方を 1 か所に書く。
/// 読み方には宣言した名前の値だけを渡すので、一覧に見せる名前と読む名前はずれない
public struct ActionParameter<Value> {
    public let name: String
    public let summary: String
    /// 名前の値 (省かれたら nil) を読む
    let read: (JSONValue?) throws(IntrospectionError) -> Value

    /// - Parameter read: 名前の値 (省かれたら nil) を読む。読めなければ、その名前で invalidArgument や missingArgument を投げる
    public init(_ name: String, _ summary: String, read: @escaping (JSONValue?) throws(IntrospectionError) -> Value) {
        self.name = name
        self.summary = summary
        self.read = read
    }

    /// 引数の中から、宣言した名前の値を読む
    func read(in arguments: [String: JSONValue]) throws(IntrospectionError) -> Value {
        try read(arguments[name])
    }

    /// 省いてよい引数 (省くか null なら nil)
    public var optional: ActionParameter<Value?> {
        let read = read
        return ActionParameter<Value?>(name, summary) { value throws(IntrospectionError) in
            value == nil || value == .null ? nil : try read(value)
        }
    }
}

extension ActionParameter where Value == String {
    /// 文字列の引数
    public static func string(_ name: String, _ summary: String) -> Self {
        Self(name, summary) { value throws(IntrospectionError) in try value.string(name) }
    }
}

extension ActionParameter where Value == Int {
    /// 数の引数
    public static func int(_ name: String, _ summary: String) -> Self {
        Self(name, summary) { value throws(IntrospectionError) in try value.int(name) }
    }
}

extension ActionParameter where Value == Bool {
    /// 真偽の引数 (省くと false)
    public static func bool(_ name: String, _ summary: String) -> Self {
        Self(name, summary) { value throws(IntrospectionError) in try value.bool(name) }
    }
}

extension ActionParameter where Value == [JSONValue] {
    /// JSON の配列のままの引数 (省くと空。配列でなければ受け付けない。中の読み方は操作が決める)
    public static func array(_ name: String, _ summary: String) -> Self {
        Self(name, summary) { value throws(IntrospectionError) in
            guard let value else { return [] }
            guard case .array(let values) = value else { throw .invalidArgument(name) }
            return values
        }
    }
}

extension ActionParameter {
    /// 決まった値から選ぶ引数。説明は選べる値の一覧 (label で文字にしたもの)
    public static func choice(_ name: String, from values: [Value], label: @escaping (Value) -> String) -> Self {
        Self(name, values.map(label).joined(separator: " | ")) { value throws(IntrospectionError) in
            let text = try value.string(name)
            guard let value = values.first(where: { label($0) == text }) else { throw .invalidArgument(name) }
            return value
        }
    }
}

extension ActionParameter where Value: RawRepresentable, Value.RawValue == String {
    /// 決まった値から raw value で選ぶ引数
    public static func choice(_ name: String, from values: [Value]) -> Self {
        choice(name, from: values, label: \.rawValue)
    }
}

extension ActionParameter where Value: CaseIterable {
    /// どの case からも選べる引数
    public static func choice(_ name: String, label: @escaping (Value) -> String) -> Self {
        choice(name, from: Array(Value.allCases), label: label)
    }
}

extension ActionParameter where Value: CaseIterable & RawRepresentable, Value.RawValue == String {
    /// どの case からも raw value で選べる引数
    public static func choice(_ name: String) -> Self {
        choice(name, from: Array(Value.allCases))
    }
}

extension IntrospectableActions {
    /// 操作を送り、それで始まった処理 (テレビとのやり取りなど) が終わるまで待つ。
    /// 画面のない入口 (iOS の Siri やロック画面のボタン) が、終わってから結果 (state) を見るのに使う
    public func sendAndWait(_ action: Action) async {
        // 処理は送った時点で数え始める (Work.run) ので、送った直後から待ってよい
        send(action)
        await waitUntilIdle()
    }
}

/// 同じ種類の ViewModel がいくつも開いているとき (タブごとの戻る道など) に、道の名前を変えて見せる
@MainActor
package final class IntrospectionAlias: Introspectable {
    package let introspectionName: String
    let target: any Introspectable

    package init(_ name: String, _ target: any Introspectable) {
        introspectionName = name
        self.target = target
    }

    package var introspectionState: JSONValue { target.introspectionState }
    package var introspectionValue: Any { target.introspectionValue }
    package var introspectionActions: [ActionDescription] { target.introspectionActions }
    package var introspectionChildren: [any Introspectable] { target.introspectionChildren }
    package var isBusy: Bool { target.isBusy }
    package var introspectionTarget: any Introspectable { target.introspectionTarget }
    package func perform(_ action: String, _ arguments: [String: JSONValue]) throws { try target.perform(action, arguments) }
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
        // 操作を後回しで送る経路 (Android の振る舞いのテストの相手) では、送った直後はまだ処理が始まっていないことがあるので少し待つ
        try? await Task.sleep(for: .milliseconds(50))
        // 開いている ViewModel も変わるので、木全体を読む条件で待つ。見回らず、読んだ値が変わったときだけ確かめ直す
        let root = root
        let waiting = Task { await waitUntil { !Self.anyBusy(root) } }
        // 時間切れになったら待つのをやめる (waitUntil は取り消されると返る)
        let timer = Task {
            try? await Task.sleep(for: .seconds(timeout))
            waiting.cancel()
        }
        await waiting.value
        timer.cancel()
        return !Self.anyBusy(root)
    }

    private static func anyBusy(_ node: any Introspectable) -> Bool {
        node.isBusy || node.introspectionChildren.contains(where: anyBusy)
    }
}

extension [String: JSONValue] {
    /// 文字列の引数
    public func string(_ name: String) throws(IntrospectionError) -> String { try self[name].string(name) }

    /// 数の引数
    public func int(_ name: String) throws(IntrospectionError) -> Int { try self[name].int(name) }

    /// 真偽の引数 (なければ false)
    public func bool(_ name: String) throws(IntrospectionError) -> Bool { try self[name].bool(name) }
}

/// 引数 1 つの値 (省かれたら nil) の読み方。name は、読めなかったときに知らせる引数の名前
extension JSONValue? {
    func string(_ name: String) throws(IntrospectionError) -> String {
        guard let value = self else { throw .missingArgument(name) }
        guard case .string(let text) = value else { throw .invalidArgument(name) }
        return text
    }

    func int(_ name: String) throws(IntrospectionError) -> Int {
        guard let value = self else { throw .missingArgument(name) }
        switch value {
        case .number(let number) where number == number.rounded(): return Int(number)
        case .string(let text): if let number = Int(text) { return number }
        default: break
        }
        throw .invalidArgument(name)
    }

    func bool(_ name: String) throws(IntrospectionError) -> Bool {
        switch self {
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
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
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
            return .object(
                Dictionary(
                    children.enumerated().map { index, child in
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
