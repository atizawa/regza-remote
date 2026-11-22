import Foundation
import Testing

/// ViewModel が UseCase をどう持つかの決まり (docs/architecture.md の表) を、ソースを読んで見張る
@Suite struct ViewModelDependencyGuardTests {
    /// UseCase を package で持ってよい型
    static let appWide = "AppViewModel"

    /// UseCase を private 以外で持つ行。アプリ全体の ViewModel (と、その extension) の中は除く
    static func nonPrivateUseCases(in lines: [SourceLine]) -> [SourceLine] {
        // 字下げのない型の宣言。属性や修飾子が前に付いても拾う。extension は入れ子の型の名前 (A.B) まで取る
        let declaration = /^(?:[@\w]+(?:\([^)]*\))?\s+)*(class|struct|enum|actor|extension|protocol)\s+(\w+(?:\.\w+)*)/
        // 型の中の宣言 (字下げ 1 段) で、型に UseCase を含むもの (省略できる型や配列も) か、UseCase を作って入れるもの。
        // 前に付いた属性や修飾子を 1 つ目で取り出す
        let stored = /^    ((?:[@\w]+(?:\([^)]*\))?\s+)*)(?:let|var)\s+\w+\s*(?::[^={]*UseCase|=\s*\w*UseCase\b)/
        // いまいる一番外の宣言。見張らないもの (アプリ全体の ViewModel・protocol の要件) の中なら true
        var exempt = false
        var path = ""
        return lines.filter { line in
            if line.path != path { (exempt, path) = (false, line.path) }
            // 字下げのない行で、閉じ括弧と #if などの条件以外が来たら、そこで一番外の宣言が変わる
            if let first = line.code.first, !first.isWhitespace, first != "}", first != "#" {
                exempt = line.code.firstMatch(of: declaration).map { $0.1 == "protocol" || $0.2 == appWide } ?? false
            }
            guard !exempt, let match = line.code.firstMatch(of: stored) else { return false }
            // 修飾子に private (private(set) は読む側が private ではないので除く) がない
            return !match.1.split(whereSeparator: \.isWhitespace).contains("private")
        }
    }

    /// 自分 (self) 以外が持つ UseCase のプロパティを読む行。型の名前や関数の呼び出しは除く
    static func borrowedUseCases(in lines: [SourceLine]) -> [SourceLine] {
        let borrowed = /(?:\$\d+|\b([a-z]\w*))\??\.[a-z]\w*UseCase\b(?!\s*\()/
        return lines.filter { line in line.code.matches(of: borrowed).contains { $0.1 != "self" } }
    }

    static func presentation() throws -> [SourceLine] {
        let lines = try SourceLine.read(under: "Packages/RegzaCore/Sources/Presentation")
        #expect(!lines.isEmpty)
        return lines
    }

    @Test func screenViewModelsKeepUseCasesPrivate() throws {
        for line in Self.nonPrivateUseCases(in: try Self.presentation()) {
            Issue.record("\(line.location) が UseCase を private 以外で持っています。private で持ってください")
        }
    }

    @Test func viewModelsDoNotUseOtherViewModelsUseCases() throws {
        for line in Self.borrowedUseCases(in: try Self.presentation()) {
            Issue.record("\(line.location) がほかの ViewModel の UseCase を使っています。使う UseCase は自分で受け取ってください")
        }
    }

    /// 見張りが拾うもの・拾わないものを、作った行で確かめる
    @Test func guardsFindViolations() {
        let source = [
            "final class Screen {",
            "    package let a: (any GuideUseCaseProtocol)?",
            "    @ObservationIgnored var b: [any GuideUseCaseProtocol]",
            "    private let c: any GuideUseCaseProtocol",
            "    package let h = GuideUseCase(repository: repository)",
            "    fileprivate var i: any GuideUseCaseProtocol = make(\"private \")",
            "    private(set) var j: any GuideUseCaseProtocol",
            "    var d: Int { guideUseCase.value }",
            "        _ = other.guideUseCase",
            "        _ = self.guideUseCase; _ = Factory.makeGuideUseCase(); _ = make.guideUseCase()",
            "        _ = all.map { $0.guideUseCase }",
            "}",
            "final class AppViewModel {",
            "    package let e: any GuideUseCaseProtocol",
            "}",
            "extension AppViewModel {",
            "#if DEBUG",
            "    package var g: any GuideUseCaseProtocol { guideUseCase }",
            "#endif",
            "}",
            "extension AppViewModel.Route {",
            "    package var l: any GuideUseCaseProtocol",
            "}",
            "protocol Other {",
            "    var k: any GuideUseCaseProtocol { get }",
            "}",
        ]
        var context = SourceLine.Context.code
        let lines = source.enumerated().map { index, code in
            SourceLine(root: "Probe", path: "Probe.swift", number: index + 1, code: SourceLine.stripComments(code, context: &context))
        }
        #expect(Self.nonPrivateUseCases(in: lines).map(\.number) == [2, 3, 5, 6, 7, 22])
        #expect(Self.borrowedUseCases(in: lines).map(\.number) == [9, 11])
    }
}
