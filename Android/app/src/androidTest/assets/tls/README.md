端末内の TLS サーバー専用の自己署名証明書と秘密鍵。実環境の資格情報ではない。
このディレクトリは androidTest のみに梱包され、アプリの APK には含まれない。

server-cert.pem は DNS:localhost のみを SAN に持つ。
同じ証明書を信頼しても IP:127.0.0.1 による接続は拒否されることを確認する。
有効期間は 1999-12-31 UTC から 2199-11-12 UTC とし、実行日の影響を避ける。

再作成は JDK の keytool と OpenSSL を使う。一時ディレクトリで実行し、
できた 2 つの PEM をこのディレクトリへコピーする。

```sh
keytool -genkeypair -alias localhost -keyalg RSA -keysize 2048 -sigalg SHA256withRSA \
  -dname 'CN=localhost,OU=Android TLS tests,O=RegzaRemote' -ext SAN=dns:localhost \
  -startdate '2000/01/01 00:00:00' -validity 73000 \
  -storetype PKCS12 -keystore server.p12 -storepass regza-test-only -keypass regza-test-only
keytool -exportcert -rfc -alias localhost -keystore server.p12 \
  -storepass regza-test-only -file server-cert.pem
openssl pkcs12 -in server.p12 -passin pass:regza-test-only -nocerts -noenc -out key.pem
openssl pkcs8 -topk8 -nocrypt -in key.pem -out server-key.pem
```
