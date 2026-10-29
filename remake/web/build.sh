#!/bin/sh
# Build the browser version into web/dist. Serve that directory over HTTP, e.g.
#   python3 -m http.server -d web/dist 8080
# Needs the wasm32-unknown-unknown target and a wasm-bindgen CLI of the same version as the
# wasm-bindgen crate in Cargo.lock (override the binary with WASM_BINDGEN=/path/to/it).
set -e
cd "$(dirname "$0")/.."
WBG=${WASM_BINDGEN:-wasm-bindgen}
want=$(grep -A1 '^name = "wasm-bindgen"$' Cargo.lock | sed -n 's/^version = "\(.*\)"$/\1/p')
have=$("$WBG" --version | cut -d' ' -f2)
if [ "$want" != "$have" ]; then
    echo "wasm-bindgen CLI is $have but Cargo.lock has $want:"
    echo "  cargo install wasm-bindgen-cli --version $want"
    exit 1
fi
cargo build --profile web --target wasm32-unknown-unknown
rm -rf web/dist
mkdir -p web/dist
"$WBG" --target web --no-typescript --out-dir web/dist target/wasm32-unknown-unknown/web/cyclone.wasm
cp web/index.html web/dist/
ls -l web/dist
