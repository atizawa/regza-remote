import RegzaCore

// Android アプリに見せる API。swift-java がここの public な型と関数から Java のクラスを作る
// (Java のパッケージは com.example.regzaremote.core)。
// async の関数は Java の Future、throws の関数は Java の例外になる

// MARK: - probe: テレビが応答するか、status.htm まで届くかを確かめる

public struct RegzaAndroidProbeResult {
    /// /public/feature に応答した
    public var found: Bool
    public var supportsPIN: Bool
    /// status.htm の結果。"ok"・"unauthorized" (認証を求められた)・エラーの説明
    public var status: String
}

/// user と password が空なら、認証を求められるところまでを確かめる
public func regzaProbe(host: String, user: String, password: String) async -> RegzaAndroidProbeResult {
    let device = await RegzaDiscovery.probe(host: host)
    let status: String
    do {
        _ = try await RegzaClient(connection: RegzaConnection(host: host, user: user, password: password)).status()
        status = "ok"
    } catch RegzaError.unauthorized {
        status = "unauthorized"
    } catch {
        status = (error as? RegzaError)?.errorDescription ?? String(describing: error)
    }
    return RegzaAndroidProbeResult(found: device != nil, supportsPIN: device?.supportsPIN ?? false, status: status)
}
