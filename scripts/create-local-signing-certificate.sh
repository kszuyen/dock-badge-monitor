#!/usr/bin/env bash
set -euo pipefail

IDENTITY="${BADGEBELL_LOCAL_CODESIGN_IDENTITY:-BadgeBell Local Code Signing}"
KEYCHAIN="${BADGEBELL_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"
P12_PASSPHRASE="${BADGEBELL_LOCAL_CODESIGN_P12_PASSPHRASE:-$(openssl rand -hex 24)}"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/badgebell-signing.XXXXXX")"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

if security find-identity -v -p codesigning | grep -Fq "\"$IDENTITY\""; then
  echo "Code signing identity already exists: $IDENTITY"
  exit 0
fi

if security find-certificate -c "$IDENTITY" "$KEYCHAIN" >/dev/null 2>&1; then
  security find-certificate -c "$IDENTITY" -p "$KEYCHAIN" > "$WORK_DIR/certificate.crt"
  security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$WORK_DIR/certificate.crt"

  if security find-identity -v -p codesigning "$KEYCHAIN" | grep -Fq "\"$IDENTITY\""; then
    echo "Trusted existing local code signing identity: $IDENTITY"
    exit 0
  fi
fi

cat > "$WORK_DIR/openssl.cnf" <<EOF
[ req ]
prompt = no
distinguished_name = subject
x509_extensions = extensions

[ subject ]
CN = $IDENTITY

[ extensions ]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = codeSigning
EOF

openssl req \
  -newkey rsa:2048 \
  -nodes \
  -keyout "$WORK_DIR/certificate.key" \
  -x509 \
  -days 3650 \
  -out "$WORK_DIR/certificate.crt" \
  -config "$WORK_DIR/openssl.cnf" \
  >/dev/null 2>&1

openssl pkcs12 \
  -legacy \
  -export \
  -out "$WORK_DIR/certificate.p12" \
  -inkey "$WORK_DIR/certificate.key" \
  -in "$WORK_DIR/certificate.crt" \
  -passout "pass:$P12_PASSPHRASE" \
  >/dev/null 2>&1

security import "$WORK_DIR/certificate.p12" \
  -k "$KEYCHAIN" \
  -P "$P12_PASSPHRASE" \
  -T /usr/bin/codesign \
  >/dev/null

security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$WORK_DIR/certificate.crt"

if ! security find-identity -v -p codesigning "$KEYCHAIN" | grep -Fq "\"$IDENTITY\""; then
  echo "Created certificate, but macOS did not list it as a valid code signing identity." >&2
  echo "Open Keychain Access and confirm the certificate is trusted for Code Signing." >&2
  exit 1
fi

echo "Created local code signing identity: $IDENTITY"
echo "If macOS asks whether codesign can access the key, choose Always Allow."
