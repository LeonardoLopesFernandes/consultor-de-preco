// set_secrets.js
// Cria os 4 GitHub Encrypted Secrets do app consultor-de-preco usando
// libsodium-wrappers (crypto_box_seal). NÃO use base64 puro — o GitHub exige
// o valor criptografado com a chave pública do repositório.
//
// Uso:
//   1) npm i libsodium-wrappers
//   2) Exporte GITHUB_TOKEN (com permissão repo + secrets), e defina:
//        OWNER, REPO, KEY_ALIAS, KEY_STORE_PASSWORD, KEY_PASSWORD
//   3) Coloque o upload-keystore.jks na mesma pasta deste script.
//   4) node set_secrets.js
//
// O script base64-do-jks vira o secret KEYSTORE_BASE64 automaticamente.

const fs = require('fs');
const sodium = require('libsodium-wrappers');
const https = require('https');

const OWNER = process.env.OWNER;
const REPO = process.env.REPO;
const TOKEN = process.env.GITHUB_TOKEN;

if (!OWNER || !REPO || !TOKEN) {
  console.error('Defina OWNER, REPO e GITHUB_TOKEN');
  process.exit(1);
}

function req(method, path, body) {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : null;
    const r = https.request(
      {
        hostname: 'api.github.com',
        path,
        method,
        headers: {
          Authorization: `Bearer ${TOKEN}`,
          'User-Agent': 'set-secrets',
          Accept: 'application/vnd.github+json',
          ...(data ? { 'Content-Type': 'application/json' } : {}),
        },
      },
      (res) => {
        let out = '';
        res.on('data', (c) => (out += c));
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            try {
              resolve(out ? JSON.parse(out) : {});
            } catch {
              resolve({});
            }
          } else {
            reject(new Error(`HTTP ${res.statusCode}: ${out}`));
          }
        });
      }
    );
    r.on('error', reject);
    if (data) r.write(data);
    r.end();
  });
}

function base64u(buf) {
  return Buffer.from(buf).toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

async function main() {
  await sodium.ready;

  const pub = await req(
    'GET',
    `/repos/${OWNER}/${REPO}/actions/secrets/public-key`
  );
  const publicKey = sodium.from_base64(pub.key, sodium.base64_variants.ORIGINAL);
  const keyId = pub.key_id;

  // Monta os 4 secrets
  const jksB64 = fs.readFileSync('upload-keystore.jks').toString('base64');
  const secrets = {
    KEYSTORE_BASE64: jksB64,
    KEY_ALIAS: process.env.KEY_ALIAS || 'upload',
    KEY_STORE_PASSWORD: process.env.KEY_STORE_PASSWORD,
    KEY_PASSWORD: process.env.KEY_PASSWORD,
  };

  for (const [name, value] of Object.entries(secrets)) {
    if (!value) {
      console.error(`Secret ${name} não definido`);
      process.exit(1);
    }
    const msg = sodium.from_string(String(value));
    const cipher = sodium.crypto_box_seal(msg, publicKey);
    await req('PUT', `/repos/${OWNER}/${REPO}/actions/secrets/${name}`, {
      encrypted_value: base64u(cipher),
      key_id: keyId,
    });
    console.log(`Secret ${name} criado ✔`);
  }
  console.log('Pronto. Agora crie a tag v1.0.0 e push.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
