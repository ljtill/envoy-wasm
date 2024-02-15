#!/usr/bin/env bash

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

echo "Script execution completed successfully."
