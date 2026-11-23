import SourceGuards
import Testing

/// 作ったソースを読む
private func source(_ text: String) -> SourceFile {
    SourceFile(path: "Probe.swift", text: text)
}

/// 見つけたところを、決まりに合わないところとして知らせる
private func record(_ findings: [Finding], _ message: String) {
    for finding in findings { Issue.record("\(finding) \(message)") }
}

/// 共有の Swift は今の時刻を Date() で直接読まない (偽物のサーバーと、時計そのものを除く)
@Suite struct ClockUsageTests {
    @Test func sharedSwiftReadsTimeOnlyFromAppClock() throws {
        let files = try Repository.files(under: "Packages/RegzaCore/Sources") {
            !$0.hasPrefix("RegzaFakeServers/") && $0 != "RegzaDomain/Data/AppClock.swift"
        }
        #expect(files.count > 50)
        record(files.flatMap(Guards.clockReads), "が今の時刻を直接読んでいます。時計 (AppClock) から読んでください")
    }

    @Test func findsClockReads() {
        let file = source(
            """
            let a = Date()
            let b = Date.now
            let c = Date.init()
            let d = Date(timeIntervalSince1970: 0)
            // Date() はコメントの中
            let e = "Date()"
            let f = clock.now
            let g = Foundation.Date()
            let h: Date = .now
            var i: Date? = .init()
            let j: ContinuousClock.Instant = .now
            var k: Date { .now }
            func l(at time: Date = .now) {}
            let m = Date(timeIntervalSinceNow: 60)
            let n = deadline.timeIntervalSinceNow
            let o = Date(timeIntervalSince1970: 0).addingTimeInterval(1)
            let q: String = formatter.string(from: .now)
            let r = ContinuousClock.now
            let s = Date.timeIntervalSinceReferenceDate
            let t = CFAbsoluteTimeGetCurrent()
            """)
        // 型を省いた .now は、どの時計か分からないので、型を書いた先が Date 以外でも拾う
        #expect(Guards.clockReads(in: file).map(\.line) == [1, 2, 3, 8, 9, 10, 11, 12, 13, 14, 15, 17, 19, 20])
    }
}

/// 画面に出すエラーの文言は ErrorMessage だけが作る。`localizedDescription` を読んでよいのは ErrorMessage だけ
/// (OS のエラーは、通信が種類 (ConnectionFailure) に分けて RegzaError にし、OS の文言は使わない)
@Suite struct ErrorMessageUsageTests {
    @Test func onlyErrorMessageReadsLocalizedDescription() throws {
        let shared = try Repository.files(under: "Packages/RegzaCore/Sources") {
            !$0.hasPrefix("RegzaFakeServers/") && $0 != "Presentation/PresentationCore/Errors/ErrorMessage.swift"
        }
        let bridge = try Repository.files(under: "Android/RegzaAndroidBridge/Sources")
        let iOS = try Repository.files(under: "iOS/RegzaKit/Sources")
        #expect(!shared.isEmpty && !bridge.isEmpty && !iOS.isEmpty)
        record((shared + bridge + iOS).flatMap(Guards.localizedDescriptionReads), "がエラーの文言を直接読んでいます。ErrorMessage.text で文言にしてください")
    }

    @Test func findsLocalizedDescription() {
        let file = source(
            """
            let a = error.localizedDescription
            /* error.localizedDescription */
            let b = "error.localizedDescription"
            let c = (error as NSError)
                .localizedDescription
            let d = errors.map(\\.localizedDescription)
            """)
        #expect(Guards.localizedDescriptionReads(in: file).map(\.line) == [1, 4, 6])
    }
}

/// ViewModel が UseCase をどう持つかの決まり (docs/architecture.md の表)
@Suite struct ViewModelDependencyTests {
    /// UseCase を package で持ってよい型 (画面の移り変わりを持つアプリ全体の ViewModel)
    static let appWide: Set<String> = ["AppViewModel"]

    static func presentation() throws -> [SourceFile] {
        let files = try Repository.files(under: "Packages/RegzaCore/Sources/Presentation")
        #expect(files.count > 20)
        return files
    }

    @Test func screenViewModelsKeepUseCasesPrivate() throws {
        let findings = try Self.presentation().flatMap { Guards.nonPrivateUseCases(in: $0, exempt: Self.appWide) }
        record(findings, "が UseCase を private 以外で持っています。private で持ってください")
    }

    @Test func viewModelsDoNotUseOtherViewModelsUseCases() throws {
        record(try Self.presentation().flatMap(Guards.borrowedUseCases), "がほかの ViewModel の UseCase を使っています。使う UseCase は自分で受け取ってください")
    }

    @Test func findsHowUseCasesAreHeld() {
        let file = source(
            """
            final class Screen {
                package let a: (any GuideUseCaseProtocol)?
                @ObservationIgnored var b: [any GuideUseCaseProtocol]
                private let c: any GuideUseCaseProtocol
                package let h = GuideUseCase(repository: repository)
                fileprivate var i: any GuideUseCaseProtocol = make("private ")
                private(set) var j: any GuideUseCaseProtocol
                var d: Int { guideUseCase.value }
                func run() {
                    _ = other.guideUseCase
                    _ = self.guideUseCase; _ = Factory.makeGuideUseCase(); _ = make.guideUseCase()
                    _ = all.map { $0.guideUseCase }
                    _ = model?.guideUseCase
                }
                final class Inner { var m: any GuideUseCaseProtocol }
            }
            final class AppViewModel {
                package let e: any GuideUseCaseProtocol
            }
            extension AppViewModel {
            #if DEBUG
                package var g: any GuideUseCaseProtocol { guideUseCase }
            #endif
            }
            extension AppViewModel.Route {
                package var l: any GuideUseCaseProtocol
            }
            extension Screen {
            #if DEBUG
                package var n: any GuideUseCaseProtocol { guideUseCase }
            #endif
            }
            protocol Other {
                var k: any GuideUseCaseProtocol { get }
            }
            #if DEBUG
            extension Screen {
                package var o: any GuideUseCaseProtocol { guideUseCase }
            }
            #endif
            """)
        #expect(Guards.nonPrivateUseCases(in: file, exempt: Self.appWide).map(\.line) == [2, 3, 5, 6, 7, 15, 26, 30, 38])
        #expect(Guards.borrowedUseCases(in: file).map(\.line) == [10, 12, 13])
    }
}

/// 約束事 (CLI と振る舞いのテストの操作) に漏れがないこと。
/// 画面の Action (Presentation/<モジュール>/<画面>/Action/) のどの case も、操作の表 (introspectionTable) で作られていること
/// (アプリの画面から送れる操作は、どれも約束事からも送れる)
@Suite struct ContractCoverageTests {
    @Test func everyActionCaseCanBeSentFromTheContract() throws {
        let files = try Repository.files(under: "Packages/RegzaCore/Sources/Presentation")
        let types = Guards.actionTypes(in: files)
        let tables = Guards.tables(in: files)
        #expect(types.count > 10, "Action の型が見つかりません")
        for type in types {
            #expect(!type.cases.isEmpty, "\(type.name) に case が見つかりません")
            guard let names = tables[type.name] else {
                Issue.record("\(type.path) の \(type.name) を作る操作の表 (introspectionTable) が見つかりません")
                continue
            }
            let missing = type.cases.filter { !names.contains($0) }
            #expect(missing.isEmpty, "\(type.name) の \(missing.joined(separator: "・")) を約束事から送れません。操作の表に足してください")
        }
    }

    /// 1 つの表の中で、操作の名前が重ならない (重なると、後ろの操作を送れない)
    @Test func actionNamesAreUniqueInEachTable() throws {
        let files = try Repository.files(under: "Packages/RegzaCore/Sources/Presentation")
        record(files.flatMap(Guards.duplicateActionNames), "の操作の名前が、同じ表の中のほかの操作と重なっています")
    }

    @Test func readsActionTypesAndTables() {
        let action = SourceFile(
            path: "Feature/Screen/Action/ScreenAction.swift",
            text: """
                /// 画面からの操作
                public enum ScreenAction: Sendable {
                    case load
                    case select(String), close
                }
                """)
        let viewModel = SourceFile(
            path: "Feature/Screen/ScreenViewModel.swift",
            text: """
                public final class ScreenViewModel {
                    public typealias Action = ScreenAction
                }
                extension ScreenViewModel: IntrospectableActions {
                    public var introspectionTable: [IntrospectionAction<Action>] {
                        [
                            IntrospectionAction("load", "読む", .load),
                            IntrospectionAction("select", "選ぶ", .string("id", "id")) { id in
                                guard ids.contains(where: { $0 == id }) else { throw IntrospectionError.invalidArgument("id") }
                                return .select(.close(id))
                            },
                            IntrospectionAction("again", "名前を付けた処理で作る", .string("id", "id"), make: { .select($0) }),
                            IntrospectionAction("load", "名前が重なる", .load),
                            IntrospectionAction("pick", "条件で選ぶ", .bool("on", "x")) { $0 ? .open : .shut },
                            IntrospectionAction("pickIf", "if の式で選ぶ", .bool("on", "x")) { on in if on { .first } else { .second(1) } },
                        ]
                    }
                }
                """)
        #expect(
            Guards.actionTypes(in: [action, viewModel]) == [
                .init(name: "ScreenAction", cases: ["load", "select", "close"], path: action.path)
            ])
        let names = Guards.tables(in: [action, viewModel])["ScreenAction"] ?? []
        // 作る case だけを数える (引数の作り方や、case の中の値の名前は数えない)
        #expect(names == ["load", "select", "select", "load", "open", "shut", "first", "second"])
        #expect(Guards.duplicateActionNames(in: viewModel).map(\.line) == [13])
    }

    /// 1 つの操作の中で、引数の名前が重ならない。表の中で名前を付けた引数も、付けた名前から探す
    @Test func findsDuplicateParameterNames() throws {
        let file = source(
            """
            final class Screen {
                public typealias Action = ScreenAction
                struct Inner { typealias Action = OtherAction }
            }
            extension Screen: IntrospectableActions {
                public var introspectionTable: [IntrospectionAction<Action>] {
                    let id = ActionParameter<String>.string("id", "id")
                    return [
                        IntrospectionAction("a", "重ならない", id, .int("count", "数")) { .a($0, $1) },
                        IntrospectionAction("b", "重なる", id, ActionParameter<String>.string("id", "別").optional) { .b($0, $1) },
                        IntrospectionAction("c", "重なる", .bool("on", "x"), .bool("on", "y"), make: { .c($0, $1) }),
                    ]
                }
            }
            """)
        #expect(Guards.duplicateParameterNames(in: file).map(\.line) == [10, 11])
        // 表の型は、一番外の型の typealias Action で決める (入れ子の型のものは使わない)
        #expect(Guards.tables(in: [file]).keys.sorted() == ["ScreenAction"])
    }

    /// 1 つの操作の中で、引数の名前が重ならない (重なると、一覧に引数が 1 つしか出ず、同じ値を 2 通りに読む)
    @Test func parameterNamesAreUniqueInEachAction() throws {
        let files = try Repository.files(under: "Packages/RegzaCore/Sources/Presentation")
        record(files.flatMap(Guards.duplicateParameterNames), "の引数の名前が重なっています")
    }
}
