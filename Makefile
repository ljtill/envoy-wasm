SHELL:=/usr/bin/env bash

#
# Directories
#

# ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
ROOT_DIR := .
DOTNET_DIR := ${ROOT_DIR}/modules/dotnet
RUST_DIR := ${ROOT_DIR}/modules/rust
ENVOY_DIR := ${ROOT_DIR}/proxies/envoy

#
# Tools
#

DOTNET_IMAGE_NAME := envoy:dotnet
DOTNET_PROJECT_FILE := ${DOTNET_DIR}/Envoy.csproj

RUST_IMAGE_NAME := envoy:rust
RUST_MANIFEST_FILE := ${RUST_DIR}/Cargo.toml

ENVOY_NAME := envoy

##@ General

.PHONY: help
help:  # Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[0-9A-Za-z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^\$$\([0-9A-Za-z_-]+\):.*?##/ { gsub("_","-", $$1); printf "  \033[36m%-20s\033[0m %s\n", tolower(substr($$1, 3, length($$1)-7)), $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: all
all: clean build  ## Execute all build tasks.

##@ Build

.PHONY: build
build: build-dotnet build-rust ## Build all module & proxy artifacts.

.PHONY: build-dotnet
build-dotnet: ## Build dotnet module & envoy proxy image.
	@echo "=> (module) Compiling .NET source..."
	@dotnet build ${DOTNET_PROJECT_FILE}
	@echo "=> (proxy) Building .NET image..."
	@docker build --build-arg MOD_PATH=${DOTNET_DIR}/bin/Debug/net8.0/wasi-wasm/dotnet.wasm -t envoy:dotnet --file ${ENVOY_DIR}/Dockerfile .

.PHONY: build-rust
build-rust: ## Build rust module & envoy proxy image.
	@echo "=> (module) Compiling Rust source..."
	@rustup target add wasm32-wasi
	@cargo build --manifest-path ${RUST_DIR}/Cargo.toml --target wasm32-wasi
	@echo "=> (proxy) Building Rust image..."
	@docker build --build-arg MOD_PATH=${RUST_DIR}/target/wasm32-wasi/debug/module.wasm -t envoy:rust --file ${ENVOY_DIR}/Dockerfile .

##@ Test

.PHONY: test
test: test-dotnet test-rust ## Test all modules.

.PHONY: test-dotnet
test-dotnet: ## Test dotnet module.
	@echo "=> (module) Testing .NET source..."
	@dotnet test ${DOTNET_PROJECT_FILE} --verbosity minimal

.PHONY: test-rust
test-rust: ## Test rust module.
	@echo "=> (module) Testing Rust source..."
	@cargo test --manifest-path ${RUST_DIR}/Cargo.toml

##@ Validate

.PHONY: validate
validate: validate-dotnet validate-rust ## Validate all modules.

.PHONY: validate-dotnet
validate-dotnet: ## Validate dotnet module.
	@echo "=> (module) Validating .NET module..."
	@wasm-tools validate ${DOTNET_DIR}/bin/Debug/net8.0/wasi-wasm/dotnet.wasm

.PHONY: validate-rust
validate-rust: ## Validate rust module.
	@echo "=> (module) Validating Rust module..."
	@wasm-tools validate ${RUST_DIR}/target/wasm32-wasi/debug/module.wasm

##@ Clean

.PHONY: clean
clean: clean-dotnet clean-rust ## Clean all module & proxy artifacts.

.PHONY: clean-dotnet
clean-dotnet: ## Clean dotnet module & proxy artifacts.
	@echo "=> (module) Cleaning .NET source..."
	@dotnet clean ${DOTNET_PROJECT_FILE} --verbosity minimal
	@echo "=> (proxy) Cleaning .NET image..."
	@docker images -q ${DOTNET_IMAGE_NAME} | xargs -r docker rmi

.PHONY: clean-rust
clean-rust: ## Clean rust module & proxy artifacts.
	@echo "=> (module) Cleaning Rust source..."
	@cargo clean --manifest-path ${RUST_DIR}/Cargo.toml
	@echo "=> (proxy) Cleaning Rust image..."
	@docker images -q ${RUST_IMAGE_NAME} | xargs -r docker rmi

##@ Deploy

.PHONY: docker-start
docker-start: docker-start-dotnet docker-start-rust ## Start all envoy proxy containers.

.PHONY: docker-start-dotnet
docker-start-dotnet: ## Start envoy proxy container.
	@echo "=> (dotnet) Starting Envoy Proxy..."
	@docker run -d --name ${ENVOY_NAME}-dotnet -p 9901:9905 -p 10000:10005 ${DOTNET_IMAGE_NAME}

.PHONY: docker-start-rust
docker-start-rust: ## Start envoy proxy container.
	@echo "=> (rust) Starting Envoy Proxy..."
	@docker run -d --name ${ENVOY_NAME}-rust -p 9901:9906 -p 10000:10006 ${RUST_IMAGE_NAME}

.PHONY: docker-stop
docker-stop: docker-stop-dotnet docker-stop-rust ## Stop all envoy proxy containers.

.PHONY: docker-stop-dotnet
docker-stop-dotnet: ## Stop envoy proxy container.
	@echo "=> Stopping Envoy Proxy..."
	@docker stop ${ENVOY_NAME}-dotnet | xargs docker rm

.PHONY: docker-stop-rust
docker-stop-rust: ## Stop envoy proxy container.
	@echo "=> Stopping Envoy Proxy..."
	@docker stop ${ENVOY_NAME}-rust | xargs docker rm

##@ Logs

.PHONY: docker-logs-dotnet
docker-logs-dotnet: ## Display envoy proxy container logs.
	@echo "=> Showing Envoy Proxy logs..."
	@docker logs -f ${ENVOY_NAME}-dotnet

.PHONY: docker-logs-rust
docker-logs-rust: ## Display envoy proxy container logs.
	@echo "=> Showing Envoy Proxy logs..."
	@docker logs -f ${ENVOY_NAME}-rust

##@ Runtime

.PHONY: wasmtime-run-dotnet
wasmtime-run-dotnet: ## Run dotnet module.
	@echo "=> Running .NET module with wasmtime..."
	@wasmtime run ${DOTNET_DIR}/bin/Debug/net8.0/wasi-wasm/dotnet.wasm

.PHONY: wasmtime-run-rust
wasmtime-run-rust: ## Run rust module.
	@echo "=> Running Rust module with wasmtime..."
	@wasmtime run ${RUST_DIR}/target/wasm32-wasi/debug/module.wasm
