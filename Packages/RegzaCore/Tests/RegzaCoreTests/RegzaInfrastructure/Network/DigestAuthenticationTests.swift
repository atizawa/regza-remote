import Foundation
import Testing

@testable import RegzaDomain
@testable import RegzaInfrastructure

@Suite struct DigestTests {
    // RFC 2617 3.5 の例
    let header = """
        Digest realm="testrealm@host.com", qop="auth,auth-int", \
        nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093", opaque="5ccc069c403ebaf9f0171e9517f40e41"
        """

    @Test func parsesChallenge() throws {
        let challenge = try #require(DigestChallenge(header: header))
        #expect(challenge.realm == "testrealm@host.com")
        #expect(challenge.nonce == "dcd98b7102dd2f0e8b11d0f600bfb0c093")
        #expect(challenge.qop == "auth")
        #expect(challenge.opaque == "5ccc069c403ebaf9f0171e9517f40e41")
    }

    @Test func rfcResponse() throws {
        let challenge = try #require(DigestChallenge(header: header))
        let authorization = challenge.authorization(
            method: "GET", uri: "/dir/index.html",
            user: "Mufasa", password: "Circle Of Life",
            nonceCount: 1, clientNonce: "0a4f113b"
        )
        #expect(authorization.contains("response=\"6629fae49393a05397450978507c4ef1\""))
        #expect(authorization.contains("nc=00000001"))
    }

    @Test func rejectsBasic() {
        #expect(DigestChallenge(header: "Basic realm=\"x\"") == nil)
    }
}
