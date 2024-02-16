SHELL:=/usr/bin/env bash

#
# Directories
#

# ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
ROOT_DIR := .
DOTNET_DIR := modules/dotnet
RUST_DIR := modules/rust
ENVOY_DIR := proxies/envoy

DOTNET_IMAGE_NAME := envoy:dotnet
RUST_IMAGE_NAME := envoy:rust

ENVOY_NAME := envoy

##@ General

.PHONY: help
help:  # Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[0-9A-Za-z_-]+:.*?##/ { printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2 } /^\$$\([0-9A-Za-z_-]+\):.*?##/ { gsub("_","-", $$1); printf "  \033[36m%-25s\033[0m %s\n", tolower(substr($$1, 3, length($$1)-7)), $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: all
all: clean build  ## Execute all build tasks.

##@ Build

.PHONY: build-dotnet
build-dotnet: ## Build dotnet module and envoy proxy image.
	@echo "=> (module) Compiling .NET source..."
	@dotnet build ${ROOT_DIR}/${DOTNET_DIR}/dotnet.csproj
	@echo "=> (proxy) Building .NET image..."
	@docker build --build-arg MOD_PATH=${ROOT_DIR}/${DOTNET_DIR}/bin/Debug/net8.0/wasi-wasm/dotnet.wasm -t envoy:dotnet --file ${ROOT_DIR}/${ENVOY_DIR}/Dockerfile .

.PHONY: build-rust
build-rust: ## Build rust module and envoy proxy image.
	@echo "=> (module) Compiling Rust source..."
	@rustup target add wasm32-wasi
	@cargo build --manifest-path ${ROOT_DIR}/${RUST_DIR}/Cargo.toml --target wasm32-wasi
	@echo "=> (proxy) Building Rust image..."
	@docker build --build-arg MOD_PATH=${ROOT_DIR}/${RUST_DIR}/target/wasm32-wasi/debug/module.wasm -t envoy:rust --file ${ROOT_DIR}/${ENVOY_DIR}/Dockerfile .


.PHONY: build
build: build-dotnet build-rust ## Build all module and proxy artifacts.

##@ Clean

.PHONY: clean-dotnet
clean-dotnet: ## Clean dotnet module and proxy artifacts.
	@echo "=> (module) Cleaning .NET source..."
	@dotnet clean ${ROOT_DIR}/${DOTNET_DIR}/dotnet.csproj --verbosity minimal
	@echo "=> (proxy) Cleaning .NET image..."
	@docker images -q ${DOTNET_IMAGE_NAME} | xargs -r docker rmi

clean-rust: ## Clean rust module and proxy artifacts.
	@echo "=> (module) Cleaning Rust source..."
	@cargo clean --manifest-path ${ROOT_DIR}/${RUST_DIR}/Cargo.toml
	@echo "=> (proxy) Cleaning Rust image..."
	@docker images -q ${RUST_IMAGE_NAME} | xargs -r docker rmi

.PHONY: clean
clean: clean-dotnet clean-rust ## Clean all module and proxy artifacts.

##@ Container

.PHONY: docker-start-dotnet
docker-start-dotnet: ## Start proxy container.
	@echo "=> (dotnet) Starting Envoy Proxy..."
	@docker run -d --name ${ENVOY_NAME} -p 9901:9901 -p 10000:10000 ${DOTNET_IMAGE_NAME}

.PHONY: docker-start-rust
docker-start-rust: ## Start proxy container.
	@echo "=> (rust) Starting Envoy Proxy..."
	@docker run -d --name ${ENVOY_NAME} -p 9901:9901 -p 10000:10000 ${RUST_IMAGE_NAME}

.PHONY: docker-stop-dotnet
docker-stop-dotnet: ## Stop proxy container.
	@echo "=> Stopping Envoy Proxy..."
	@docker stop ${ENVOY_NAME} | xargs docker rm

.PHONY: docker-stop-rust
docker-stop-rust: ## Stop proxy container.
	@echo "=> Stopping Envoy Proxy..."
	@docker stop ${ENVOY_NAME} | xargs docker rm

.PHONY: docker-restart-dotnet
docker-restart-dotnet: stop start ## Restart proxy container.

.PHONY: docker-restart-rust
docker-restart-rust: stop start ## Restart proxy container.

##@ Runtime

.PHONY: wasmtime-dotnet
wasmtime-run-dotnet: ## Run dotnet module with wasmtime.
	@echo "=> Running .NET module with wasmtime..."
	@wasmtime run --dir=${ROOT_DIR}/${DOTNET_DIR}/bin/Debug/net8.0/wasi-wasm ${ROOT_DIR}/${DOTNET_DIR}/bin/Debug/net8.0/wasi-wasm/dotnet.wasm

.PHONY: wasmtime-rust
wasmtime-run-rust: ## Run rust module with wasmtime.
	@echo "=> Running Rust module with wasmtime..."
	@wasmtime run --dir=${ROOT_DIR}/${RUST_DIR}/target/wasm32-wasi/debug ${ROOT_DIR}/${RUST_DIR}/target/wasm32-wasi/debug/module.wasm

##@ Troubleshoot

.PHONY:
logs: ## Display proxy container logs.
	@echo "=> Showing Envoy Proxy logs..."
	@docker logs -f envoy
