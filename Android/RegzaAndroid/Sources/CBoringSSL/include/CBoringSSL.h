// Swift SDK for Android に入っている BoringSSL (libssl.a・libcrypto.a) のうち、HTTPS の接続に使う関数の宣言。
// SDK には BoringSSL のヘッダーが入っていないので、使うものだけを BoringSSL の ssl.h と同じ形で書く。
// Swift SDK の版を上げたら、BoringSSL の C の API が変わっていないかを確かめる
#ifndef CBORINGSSL_H
#define CBORINGSSL_H

#include <stdint.h>

typedef struct ssl_st SSL;
typedef struct ssl_ctx_st SSL_CTX;
typedef struct ssl_method_st SSL_METHOD;
typedef struct X509_VERIFY_PARAM_st X509_VERIFY_PARAM;

#define SSL_VERIFY_NONE 0x00
#define SSL_VERIFY_PEER 0x01
#define X509_V_OK 0
#define SSL_ERROR_NONE 0
#define SSL_ERROR_SSL 1
#define SSL_ERROR_WANT_READ 2
#define SSL_ERROR_WANT_WRITE 3
#define SSL_ERROR_SYSCALL 5
#define SSL_ERROR_ZERO_RETURN 6
#define TLS1_2_VERSION 0x0303

const SSL_METHOD *TLS_client_method(void);
SSL_CTX *SSL_CTX_new(const SSL_METHOD *method);
void SSL_CTX_free(SSL_CTX *ctx);
void SSL_CTX_set_verify(SSL_CTX *ctx, int mode, void *callback);
int SSL_CTX_set_min_proto_version(SSL_CTX *ctx, uint16_t version);
int SSL_CTX_load_verify_locations(SSL_CTX *ctx, const char *ca_file, const char *ca_dir);

SSL *SSL_new(SSL_CTX *ctx);
void SSL_free(SSL *ssl);
int SSL_set_fd(SSL *ssl, int fd);
int SSL_set_tlsext_host_name(SSL *ssl, const char *name);
int SSL_set1_host(SSL *ssl, const char *hostname);
X509_VERIFY_PARAM *SSL_get0_param(SSL *ssl);
int X509_VERIFY_PARAM_set1_ip_asc(X509_VERIFY_PARAM *param, const char *ipasc);
long SSL_get_verify_result(const SSL *ssl);
int SSL_connect(SSL *ssl);
int SSL_read(SSL *ssl, void *buf, int num);
int SSL_write(SSL *ssl, const void *buf, int num);
int SSL_get_error(const SSL *ssl, int ret_code);
int SSL_shutdown(SSL *ssl);

#endif
