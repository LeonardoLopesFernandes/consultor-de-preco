# Release — Consultor de Preço (Flutter, arm64-v8a, split-per-abi)

Este app é o port fiel do `Scanner` nativo (Kotlin) para Flutter. O release é
gerado via GitHub Actions e instala **por cima** do anterior (mesmo
`applicationId` = `io.amer.scanner` e mesma upload key fixa em Encrypted Secrets).

## 1. Gerar a upload key (uma vez)

```bash
keytool -genkeypair -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload -storepass SUA_SENHA -keypass SUA_SENHA \
  -dname "CN=ConsultorDePreco, OU=App, O=App, L=Cidade, ST=Estado, C=BR"
```

## 2. Criar os 4 secrets no repo (criptografados com libsodium crypto_box_seal)

NÃO use base64 puro — use o `scripts/set_secrets.js` (libsodium-wrappers):

```bash
cd scripts
npm i libsodium-wrappers
export OWNER=seu-usuario REPO=consultor-de-preco GITHUB_TOKEN=ghp_xxx
export KEY_ALIAS=upload KEY_STORE_PASSWORD=SUA_SENHA KEY_PASSWORD=SUA_SENHA
# coloque upload-keystore.jks ao lado do script
node set_secrets.js
```

Secrets criados:
- `KEYSTORE_BASE64` = `base64 -w0 upload-keystore.jks`
- `KEY_ALIAS` = `upload`
- `KEY_STORE_PASSWORD` = `SUA_SENHA`
- `KEY_PASSWORD` = `SUA_SENHA`

## 3. build.yml (já presente em .github/workflows/build.yml)

Faz decode do `KEYSTORE_BASE64`, gera `android/key.properties` e roda:

```bash
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

O artefato é `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, anexado
ao GitHub Release.

## 4. Sobre o build.gradle.kts (assinatura)

O projeto usa **Kotlin DSL** (`android/app/build.gradle.kts`) — Flutter 3.29+
suporta `.kts` oficialmente, e o CI roda stable (3.29+), então o build não
quebra. O ponto crítico que você reportou — `java.util.Properties` não resolve
no Kotlin DSL — é contornado exatamente com `val rootProj = rootProject` e
`readLines()`, em `android/app/build.gradle.kts`:

```kotlin
val rootProj = rootProject
val keystoreProperties = mutableMapOf<String, String>()
val keystorePropertiesFile = rootProj.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.readLines().forEach { line ->
        val trimmed = line.trim()
        if (trimmed.isNotEmpty() && !trimmed.startsWith("#") && trimmed.contains("=")) {
            val parts = trimmed.split("=", limit = 2)
            keystoreProperties[parts[0].trim()] = parts[1].trim()
        }
    }
}
```

## 5. Tag e push

```bash
git init 2>/dev/null || true
git add -A
git commit -m "Consultor de Preço - Flutter port (arm64 split-per-abi)"
git tag v1.0.0
git remote add origin git@github.com:seu-usuario/consultor-de-preco.git
git push -u origin main
git push origin v1.0.0   # dispara o CI -> cria o Release com o APK arm64
```

Das próximas tags em diante, o CI atualiza o app por cima (mesma upload key).
