package com.example.regzaremote.appservices.network

import com.example.regzaremote.core.RegzaAndroidHTTPClient
import com.example.regzaremote.core.RegzaAndroidHTTPCompletion
import com.example.regzaremote.core.RegzaAndroidHTTPRequest
import java.io.IOException
import java.security.SecureRandom
import java.security.cert.X509Certificate
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLHandshakeException
import javax.net.ssl.SSLPeerUnverifiedException
import javax.net.ssl.X509TrustManager
import okhttp3.Call
import okhttp3.Callback
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response

/** HTTP・DNS・プロキシ・TLS・圧縮・接続管理は OkHttp と Android に任せる。 */
class OkHttpTransport(private val client: OkHttpClient = OkHttpClient()) : RegzaAndroidHTTPClient {
    private val calls = ConcurrentHashMap<String, Call>()
    private val televisionClient by lazy {
        // REGZA の自己署名 HTTPS に限る既存の例外。リダイレクト先に例外を持ち出さない。
        val trustManager = object : X509TrustManager {
            override fun checkClientTrusted(chain: Array<out X509Certificate>, authType: String) = Unit
            override fun checkServerTrusted(chain: Array<out X509Certificate>, authType: String) = Unit
            override fun getAcceptedIssuers(): Array<X509Certificate> = emptyArray()
        }
        val context = SSLContext.getInstance("TLS").apply {
            init(null, arrayOf(trustManager), SecureRandom())
        }
        client.newBuilder()
            .sslSocketFactory(context.socketFactory, trustManager)
            .hostnameVerifier { _, _ -> true }
            .followRedirects(false)
            .followSslRedirects(false)
            .build()
    }

    override fun start(request: RegzaAndroidHTTPRequest, completion: RegzaAndroidHTTPCompletion) {
        val id = request.id
        try {
            val builder = Request.Builder().url(request.address)
            val headers = request.headers
            require(headers.size % 2 == 0) { "不正なリクエストヘッダーです" }
            for (index in headers.indices step 2) builder.header(headers[index], headers[index + 1])
            val method = request.method
            val body = if (request.isHasBody || method in listOf("POST", "PUT", "PATCH")) request.body.toRequestBody() else null
            val outgoing = builder.method(method, body).build()
            val selected = if (request.isVerifiesCertificate) client else televisionClient
            val timeout = (request.timeout * 1_000).toLong().coerceAtLeast(1)
            val configured = selected.newBuilder()
                .connectTimeout(timeout, TimeUnit.MILLISECONDS)
                .readTimeout(timeout, TimeUnit.MILLISECONDS)
                .writeTimeout(timeout, TimeUnit.MILLISECONDS)
                .build()
            val call = configured.newCall(outgoing)
            calls[id] = call
            call.enqueue(object : Callback {
                override fun onFailure(call: Call, error: IOException) {
                    calls.remove(id)
                    completion.fail(if (call.isCanceled()) "通信を取り消しました" else message(error, outgoing.url.host))
                }

                override fun onResponse(call: Call, response: Response) {
                    try {
                        response.use {
                            val fields = it.headers.names().flatMap { name -> listOf(name, it.headers.values(name).joinToString(", ")) }
                            completion.succeed(it.code, fields.toTypedArray(), it.body.bytes())
                        }
                    } catch (error: Exception) {
                        completion.fail(if (call.isCanceled()) "通信を取り消しました" else message(error, outgoing.url.host))
                    } finally {
                        calls.remove(id)
                    }
                }
            })
        } catch (error: Exception) {
            calls.remove(id)?.cancel()
            completion.fail(error.localizedMessage ?: "通信に失敗しました")
        }
    }

    override fun cancel(id: String) {
        calls.remove(id)?.cancel()
    }

    private fun message(error: Exception, host: String): String = when (error) {
        is SSLPeerUnverifiedException, is SSLHandshakeException -> "$host の証明書を確かめられませんでした"
        else -> error.localizedMessage ?: "通信に失敗しました"
    }
}
