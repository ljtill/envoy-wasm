#!/usr/bin/env bash

set -e

# Path to the dotnet executable
DOTNET=/usr/share/dotnet/dotnet

# Update dotnet workload
echo "Updating dotnet workload..."
if ! $DOTNET workload update; then
    echo "Failed to update dotnet workload. Exiting." >&2
    exit 1
fi

# Install wasi-experimental workload
echo "Installing wasi-experimental workload..."
if ! $DOTNET workload install wasi-experimental; then
    echo "Failed to install wasi-experimental workload. Exiting." >&2
    exit 1
fi

# Install wasi-sdk
echo "Installing wasi-sdk..."
WASI_SDK_URL="https://github.com/webassembly/wasi-sdk/releases/download/${WASI_VERSION}/${WASI_VERSION}.0-linux.tar.gz"
WASI_SDK_TMP="/tmp/${WASI_VERSION}.0-linux.tar.gz"
WASI_SDK_DIR="/usr/local/lib/${WASI_VERSION}.0"

curl -Lo "${WASI_SDK_TMP}" "${WASI_SDK_URL}"
tar -xzf "${WASI_SDK_TMP}" -C /tmp/
rm "${WASI_SDK_TMP}"
mv "/tmp/${WASI_VERSION}.0" "${WASI_SDK_DIR}"

echo "Script execution completed successfully."
