package com.example.regzaremote

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.example.regzaremote.appservices.network.OkHttpTransport
import com.example.regzaremote.core.RegzaAndroidAppFactory
import com.example.regzaremote.core.RegzaAndroidHTTPClient
import com.example.regzaremote.core.RegzaAndroidHTTPCompletion
import com.example.regzaremote.core.RegzaAndroidHTTPRequest
import java.io.ByteArrayOutputStream
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import java.util.zip.GZIPOutputStream
import kotlinx.coroutines.future.await
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import mockwebserver3.MockResponse
import mockwebserver3.MockWebServer
import okio.Buffer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** 共通コアから JNI を通して、OkHttp の実際の送受信・圧縮・取消を確認する。 */
@RunWith(AndroidJUnit4::class)
class OkHttpTransportTest {
    @Test
    fun readsChunkedResponseAndPreservesEncodedQuery() = runBlocking {
        MockWebServer().use { server ->
            server.enqueue(MockResponse.Builder().chunkedBody("日本語の番組表", 3).build())
            server.start()
            val factory = RegzaAndroidAppFactory.`init`(OkHttpTransport())
            val result = withTimeout(TIMEOUT) { factory.networkProbe(server.url("/guide?q=a%20b&x=%26").toString(), 3.0).await() }
            assertEquals("200\n日本語の番組表", result)
            assertEquals("/guide?q=a%20b&x=%26", server.takeRequest(3, TimeUnit.SECONDS)?.target)
        }
    }

    @Test
    fun transparentlyDecompressesGzip() = runBlocking {
        val compressed = ByteArrayOutputStream().also { output ->
            GZIPOutputStream(output).use { it.write("圧縮された番組表".toByteArray()) }
        }.toByteArray()
        MockWebServer().use { server ->
            server.enqueue(MockResponse.Builder().body(Buffer().write(compressed)).addHeader("Content-Encoding", "gzip").build())
            server.start()
            val factory = RegzaAndroidAppFactory.`init`(OkHttpTransport())
            val result = withTimeout(TIMEOUT) { factory.networkProbe(server.url("/gzip").toString(), 3.0).await() }
            assertEquals("200\n圧縮された番組表", result)
            assertEquals("gzip", server.takeRequest(3, TimeUnit.SECONDS)?.headers?.get("Accept-Encoding"))
        }
    }

    @Test
    fun followsOrdinaryHttpRedirect() = runBlocking {
        MockWebServer().use { server ->
            server.enqueue(MockResponse.Builder().code(302).addHeader("Location", "/destination").build())
            server.enqueue(MockResponse.Builder().body("redirected").build())
            server.start()
            val factory = RegzaAndroidAppFactory.`init`(OkHttpTransport())
            val result = withTimeout(TIMEOUT) { factory.networkProbe(server.url("/origin").toString(), 3.0).await() }
            assertEquals("200\nredirected", result)
            assertEquals("/origin", server.takeRequest(3, TimeUnit.SECONDS)?.target)
            assertEquals("/destination", server.takeRequest(3, TimeUnit.SECONDS)?.target)
        }
    }

    @Test
    fun readTimeoutIsReturnedAsNetworkFailure() = runBlocking {
        MockWebServer().use { server ->
            server.enqueue(MockResponse.Builder().body("delayed").bodyDelay(1, TimeUnit.SECONDS).build())
            server.start()
            val factory = RegzaAndroidAppFactory.`init`(OkHttpTransport())
            val result = withTimeout(TIMEOUT) { factory.networkProbe(server.url("/slow").toString(), 0.1).await() }
            assertTrue(result, result.startsWith("error:") && result.contains("timeout", ignoreCase = true))
        }
    }

    @Test
    fun cancellingCallCompletesSwiftWait() = runBlocking {
        MockWebServer().use { server ->
            server.enqueue(MockResponse.Builder().body("delayed").bodyDelay(5, TimeUnit.SECONDS).build())
            server.start()
            val client = RecordingClient()
            val factory = RegzaAndroidAppFactory.`init`(client)
            val response = factory.networkProbe(server.url("/cancel").toString(), 30.0)
            assertNotNull(server.takeRequest(3, TimeUnit.SECONDS))
            client.cancel(requireNotNull(client.requestID.get()))
            val result = withTimeout(2_000) { response.await() }
            assertTrue(result, result.startsWith("error:") && result.contains("取り消しました"))
        }
    }

    private class RecordingClient : RegzaAndroidHTTPClient {
        val requestID = AtomicReference<String?>()
        private val transport = OkHttpTransport()

        override fun start(request: RegzaAndroidHTTPRequest, completion: RegzaAndroidHTTPCompletion) {
            requestID.set(request.id)
            transport.start(request, completion)
        }

        override fun cancel(id: String) = transport.cancel(id)
    }

    private companion object {
        const val TIMEOUT = 10_000L
    }
}
