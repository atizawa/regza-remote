package com.example.regzaremote

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.example.regzaremote.appservices.network.OkHttpTransport
import com.example.regzaremote.core.RegzaAndroidAppFactory
import java.io.IOException
import java.net.InetAddress
import java.security.KeyFactory
import java.security.KeyStore
import java.security.cert.CertificateFactory
import java.security.spec.PKCS8EncodedKeySpec
import java.util.Base64
import java.util.concurrent.atomic.AtomicReference
import javax.net.ssl.KeyManagerFactory
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLServerSocket
import javax.net.ssl.SSLSocket
import javax.net.ssl.TrustManagerFactory
import javax.net.ssl.X509TrustManager
import kotlin.concurrent.thread
import kotlinx.coroutines.future.await
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import okhttp3.OkHttpClient
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** 実際の Swift → JNI → OkHttp → Android TLS を、端末内の TLS サーバーと接続して確認する。 */
@RunWith(AndroidJUnit4::class)
class TLSTransportTest {
    @Test
    fun trustedCertificateCompletesHandshakeAndExchangesHttp() = runBlocking {
        val result = exchange(host = "localhost", trustsTestCertificate = true)
        assertEquals("200\ntls-ok", result.response)
        assertEquals("GET /tls HTTP/1.1", result.request)
    }

    @Test
    fun systemTrustStoreRejectsSelfSignedCertificate() = runBlocking {
        val result = exchange(host = "localhost", trustsTestCertificate = false)
        assertTrue(result.response, result.response.startsWith("error:") && result.response.contains("証明書を確かめられませんでした"))
        assertNull(result.request)
    }

    @Test
    fun trustedCertificateWithWrongHostIsRejected() = runBlocking {
        // 同じ証明書を信頼しても、DNS:localhost は IP:127.0.0.1 の証明書として使えない。
        val result = exchange(host = "127.0.0.1", trustsTestCertificate = true)
        assertTrue(result.response, result.response.startsWith("error:") && result.response.contains("証明書を確かめられませんでした"))
        assertNull(result.request)
    }

    @Test
    fun televisionSelfSignedCertificateIsAccepted() = runBlocking {
        val result = exchange(host = "127.0.0.1", trustsTestCertificate = false, port = 4430)
        assertEquals("200\ntls-ok", result.response)
    }

    @Test
    fun televisionCertificateExceptionDoesNotFollowRedirects() = runBlocking {
        val result = exchange(host = "127.0.0.1", trustsTestCertificate = false, port = 4430, redirects = true)
        assertEquals("302\n", result.response)
    }

    private suspend fun exchange(host: String, trustsTestCertificate: Boolean, port: Int = 0, redirects: Boolean = false): Exchange {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val assets = instrumentation.context.assets
        val certificateBytes = assets.open("tls/server-cert.pem").use { it.readBytes() }
        val certificate = CertificateFactory.getInstance("X.509").generateCertificate(certificateBytes.inputStream())
        val keyText = assets.open("tls/server-key.pem").bufferedReader().use { it.readText() }
        val keyBytes = Base64.getMimeDecoder().decode(
            keyText.replace("-----BEGIN PRIVATE KEY-----", "").replace("-----END PRIVATE KEY-----", ""),
        )
        val key = KeyFactory.getInstance("RSA").generatePrivate(PKCS8EncodedKeySpec(keyBytes))
        val password = "test-only".toCharArray()
        val keyStore = KeyStore.getInstance(KeyStore.getDefaultType()).apply {
            load(null, null)
            setKeyEntry("localhost", key, password, arrayOf(certificate))
        }
        val keyManagers = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm()).apply {
            init(keyStore, password)
        }
        val context = SSLContext.getInstance("TLS").apply { init(keyManagers.keyManagers, null, null) }
        val client = if (trustsTestCertificate) {
            val trustStore = KeyStore.getInstance(KeyStore.getDefaultType()).apply {
                load(null, null)
                setCertificateEntry("test-server", certificate)
            }
            val trustManager = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm()).apply {
                init(trustStore)
            }.trustManagers.single() as X509TrustManager
            val clientContext = SSLContext.getInstance("TLS").apply { init(null, arrayOf(trustManager), null) }
            OkHttpClient.Builder().sslSocketFactory(clientContext.socketFactory, trustManager).build()
        } else {
            OkHttpClient()
        }
        (context.serverSocketFactory.createServerSocket(port, 1, InetAddress.getByName("127.0.0.1")) as SSLServerSocket).use { server ->
            server.soTimeout = TIMEOUT.toInt()
            val request = AtomicReference<String?>()
            val failure = AtomicReference<Throwable?>()
            val responder = thread(name = "runtime-tls", isDaemon = true) {
                try {
                    (server.accept() as SSLSocket).use { socket ->
                        socket.soTimeout = TIMEOUT.toInt()
                        socket.startHandshake()
                        val input = socket.inputStream.bufferedReader()
                        request.set(input.readLine())
                        while (input.readLine()?.isNotEmpty() == true) {
                            // 空行までリクエストヘッダーを読む。
                        }
                        socket.outputStream.apply {
                            val reply = if (redirects) {
                                "HTTP/1.1 302 Found\r\nLocation: https://127.0.0.1:1/escape\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                            } else {
                                "HTTP/1.1 200 OK\r\nContent-Length: 6\r\nConnection: close\r\n\r\ntls-ok"
                            }
                            write(reply.toByteArray())
                            flush()
                        }
                    }
                } catch (error: Throwable) {
                    failure.set(error)
                }
            }
            val response = try {
                withTimeout(TIMEOUT) {
                    val address = "https://$host:${server.localPort}/tls"
                    RegzaAndroidAppFactory.`init`(OkHttpTransport(client)).networkProbe(address, 5.0).await()
                }
            } finally {
                server.close()
                responder.join(TIMEOUT)
            }
            assertFalse("TLS サーバーが終了しませんでした", responder.isAlive)
            if (!response.startsWith("error:")) {
                assertNull(failure.get())
            } else {
                // 証明書拒否時の TLS alert・切断による I/O エラーのみ許容する。
                assertTrue("TLS サーバーの予期しない失敗: ${failure.get()}", failure.get() is IOException)
            }
            return Exchange(response, request.get())
        }
    }

    private data class Exchange(val response: String, val request: String?)

    private companion object {
        const val TIMEOUT = 10_000L
    }
}
