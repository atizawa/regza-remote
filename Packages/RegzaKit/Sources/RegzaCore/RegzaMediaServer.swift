import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(FoundationXML)
import FoundationXML
#endif

/// 録画番組 (DLNA サーバーの `object.item.videoItem`)。
public struct RegzaRecording: Hashable, Sendable, Identifiable {
    public var id: String
    public var title: String
    /// 放送の開始時刻
    public var date: Date?
    public var channelName: String
    public var genre: String
    public var description: String
    /// 秒
    public var duration: Int
    /// まだ一度も再生していないか
    public var isUnwatched: Bool
}

/// フォルダ (DLNA サーバーの `object.container`)。
public struct RegzaRecordingFolder: Hashable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var childCount: Int?

    public init(id: String, title: String, childCount: Int? = nil) {
        self.id = id
        self.title = title
        self.childCount = childCount
    }
}

/// フォルダの中身の 1 ページ分
public struct RegzaRecordingPage: Sendable {
    public var folders: [RegzaRecordingFolder]
    public var recordings: [RegzaRecording]
    /// フォルダの中身の総数
    public var total: Int
}

/// テレビの DLNA サーバー (レグザリンク・シェア) から録画番組の一覧を読む。
///
/// レグザAppsコネクトの v2 API には録画済み番組の一覧がないため、こちらを使う。認証は不要。
/// 映像は DTCP-IP で保護されているので、アプリでは再生できない。
public final class RegzaMediaServer: Sendable {
    /// REGZA の DLNA サーバーのポート
    static let port = 20003
    static let controlPath = "/MediaServer/ContentDirectory/Control"
    public static let rootID = "0"

    public let host: String
    private let session: URLSession

    public init(host: String, timeout: TimeInterval = 10) {
        self.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        session = URLSession(configuration: configuration)
    }

    deinit {
        session.finishTasksAndInvalidate()
    }

    /// フォルダの中身を `start` 番目から最大 `count` 件取得する
    public func browse(_ folderID: String, start: Int = 0, count: Int = 50) async throws -> RegzaRecordingPage {
        guard !host.isEmpty else { throw RegzaError.notConfigured }
        guard let url = URL(string: "http://\(host):\(Self.port)\(Self.controlPath)") else { throw RegzaError.invalidHost }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(#"text/xml; charset="utf-8""#, forHTTPHeaderField: "Content-Type")
        request.setValue(#""urn:schemas-upnp-org:service:ContentDirectory:1#Browse""#, forHTTPHeaderField: "SOAPACTION")
        request.httpBody = Data(Self.browseBody(folderID, start: start, count: count).utf8)

        let (data, response): (Data, HTTPURLResponse) = try await withCheckedThrowingContinuation { continuation in
            session.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: RegzaError.network(error.localizedDescription))
                } else if let response = response as? HTTPURLResponse {
                    continuation.resume(returning: (data ?? Data(), response))
                } else {
                    continuation.resume(throwing: RegzaError.network("不正なレスポンスです"))
                }
            }.resume()
        }
        switch response.statusCode {
        case 200..<300: break
        case 404: throw RegzaError.unsupported
        default: throw RegzaError.httpStatus(response.statusCode)
        }
        guard let page = Self.parseBrowseResponse(data) else { throw RegzaError.unsupported }
        return page
    }

    static func browseBody(_ objectID: String, start: Int, count: Int) -> String {
        """
        <?xml version="1.0"?>\
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">\
        <s:Body><u:Browse xmlns:u="urn:schemas-upnp-org:service:ContentDirectory:1">\
        <ObjectID>\(escape(objectID))</ObjectID><BrowseFlag>BrowseDirectChildren</BrowseFlag><Filter>*</Filter>\
        <StartingIndex>\(start)</StartingIndex><RequestedCount>\(count)</RequestedCount><SortCriteria></SortCriteria>\
        </u:Browse></s:Body></s:Envelope>
        """
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// SOAP の応答から `Result` (エスケープされた DIDL-Lite) と `TotalMatches` を取り出して読む
    static func parseBrowseResponse(_ data: Data) -> RegzaRecordingPage? {
        let envelope = ElementTextCollector(names: ["Result", "TotalMatches"])
        let parser = XMLParser(data: data)
        parser.delegate = envelope
        guard parser.parse(), let result = envelope.texts["Result"] else { return nil }

        let didl = DIDLParser()
        let didlParser = XMLParser(data: Data(result.utf8))
        didlParser.shouldProcessNamespaces = true
        didlParser.delegate = didl
        guard didlParser.parse() else { return nil }
        let returned = didl.folders.count + didl.recordings.count
        return RegzaRecordingPage(
            folders: didl.folders,
            recordings: didl.recordings,
            total: envelope.texts["TotalMatches"].flatMap { Int($0) } ?? returned
        )
    }

    /// `1:09:03.000` → 4143 秒
    static func seconds(fromDuration text: String) -> Int {
        let parts = text.split(separator: ":").map { Double($0) ?? 0 }
        return Int(parts.reduce(0) { $0 * 60 + $1 })
    }

    /// `2026-01-02T21:00:00` (日本時間)
    static func date(from text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: text)
    }
}

/// 指定した名前の要素の文字列を集める
private final class ElementTextCollector: NSObject, XMLParserDelegate {
    let names: Set<String>
    private(set) var texts: [String: String] = [:]
    private var current: String?

    init(names: Set<String>) {
        self.names = names
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        let name = elementName.split(separator: ":").last.map(String.init) ?? elementName
        if names.contains(name) {
            current = name
            texts[name] = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if let current { texts[current, default: ""] += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        current = nil
    }
}

/// DIDL-Lite からフォルダと録画番組を読む
private final class DIDLParser: NSObject, XMLParserDelegate {
    private(set) var folders: [RegzaRecordingFolder] = []
    private(set) var recordings: [RegzaRecording] = []

    private var attributes: [String: String] = [:]
    private var fields: [String: String] = [:]
    private var durations: [String] = []
    private var text = ""
    private var isInObject = false

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        text = ""
        switch elementName {
        case "container", "item":
            isInObject = true
            self.attributes = attributes
            fields = [:]
            durations = []
        case "res":
            if let duration = attributes["duration"] { durations.append(duration) }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        defer { text = "" }
        guard isInObject else { return }
        switch elementName {
        case "container":
            isInObject = false
            guard let id = attributes["id"] else { return }
            folders.append(RegzaRecordingFolder(
                id: id, title: fields["title"] ?? "", childCount: attributes["childCount"].flatMap { Int($0) }
            ))
        case "item":
            isInObject = false
            guard let id = attributes["id"], fields["class"]?.hasPrefix("object.item.videoItem") ?? false else { return }
            recordings.append(RegzaRecording(
                id: id,
                title: RegzaNowPlaying.cleanTitle(fields["title"] ?? ""),
                date: fields["date"].flatMap(RegzaMediaServer.date(from:)),
                channelName: fields["channelName"] ?? "",
                genre: fields["genre"] ?? "",
                description: fields["longDescription"] ?? fields["description"] ?? "",
                duration: durations.first.map(RegzaMediaServer.seconds(fromDuration:)) ?? 0,
                isUnwatched: fields["playbackState"] == "0"
            ))
        case "res":
            break
        default:
            // 名前空間を除いた要素名で持つ (dc:title → title など)
            if fields[elementName] == nil { fields[elementName] = text.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
    }
}
