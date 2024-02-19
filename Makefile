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

#
# Aliases
#

bdn: build-dotnet
brs: build-rust
bdk: build-docker
tdn: test-dotnet
trs: test-rust
vdn: validate-dotnet
vrs: validate-rust
cdn: clean-dotnet
crs: clean-rust
cdk: clean-docker
sdn: start-dotnet
srs: start-rust
pdn: stop-dotnet
prs: stop-rust
ldk: list-docker
idn: inspect-dotnet
irs: inspect-rust
hdn: shell-dotnet
hrs: shell-rust
ldn: logs-dotnet
lrs: logs-rust
rdn: run-dotnet
rrs: run-rust

##@ General

.PHONY: help
help:  # Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[0-9A-Za-z_-]+:.*?##/ { printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2 } /^\$$\([0-9A-Za-z_-]+\):.*?##/ { gsub("_","-", $$1); printf "  \033[36m%-25s\033[0m %s\n", tolower(substr($$1, 3, length($$1)-7)), $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: all
all: clean build  ## Execute all build tasks

##@ Build

.PHONY: build
build: build-dotnet build-rust build ## Build all artifacts

.PHONY: build-dotnet
build-dotnet: ## Build dotnet module
	@echo "=> (module) Compiling .NET source..."
	@dotnet build ${DOTNET_PROJECT_FILE}

.PHONY: build-rust
build-rust: ## Build rust module
	@echo "=> (module) Compiling Rust source..."
	@rustup target add wasm32-wasi
	@cargo build --manifest-path ${RUST_DIR}/Cargo.toml --target wasm32-wasi

.PHONY:
build-docker: ## Build docker envoy images
	@echo "=> (proxy) Building .NET image..."
	@docker build --build-arg MOD_PATH=${DOTNET_DIR}/bin/Debug/net8.0/wasi-wasm/dotnet.wasm -t envoy:dotnet --file ${ENVOY_DIR}/Dockerfile .
	@echo "=> (proxy) Building Rust image..."
	@docker build --build-arg MOD_PATH=${RUST_DIR}/target/wasm32-wasi/debug/module.wasm -t envoy:rust --file ${ENVOY_DIR}/Dockerfile .

##@ Test

.PHONY: test
test: test-dotnet test-rust ## Test all modules

.PHONY: test-dotnet
test-dotnet: ## Test dotnet module
	@echo "=> (module) Testing .NET source..."
	@dotnet test ${DOTNET_PROJECT_FILE} --verbosity minimal

.PHONY: test-rust
test-rust: ## Test rust module
	@echo "=> (module) Testing Rust source..."
	@cargo test --manifest-path ${RUST_DIR}/Cargo.toml

##@ Validate

.PHONY: validate
validate: validate-dotnet validate-rust ## Validate all modules

.PHONY: validate-dotnet
validate-dotnet: ## Validate dotnet module
	@echo "=> (module) Validating .NET module..."
	@wasm-tools validate ${DOTNET_DIR}/bin/Debug/net8.0/wasi-wasm/dotnet.wasm

.PHONY: validate-rust
validate-rust: ## Validate rust module
	@echo "=> (module) Validating Rust module..."
	@wasm-tools validate ${RUST_DIR}/target/wasm32-wasi/debug/module.wasm

##@ Clean

.PHONY: clean
clean: clean-dotnet clean-rust clean ## Clean all artifacts

.PHONY: clean-dotnet
clean-dotnet: ## Clean dotnet module & proxy artifacts
	@echo "=> (module) Cleaning .NET source..."
	@dotnet clean ${DOTNET_PROJECT_FILE} --verbosity minimal

.PHONY: clean-rust
clean-rust: ## Clean rust module & proxy artifacts
	@echo "=> (module) Cleaning Rust source..."
	@cargo clean --manifest-path ${RUST_DIR}/Cargo.toml

.PHONY: clean-docker
clean-docker:
	@echo "=> (proxy) Cleaning .NET image..."
	@docker images -q ${DOTNET_IMAGE_NAME} | xargs -r docker rmi
	@echo "=> (proxy) Cleaning Rust image..."
	@docker images -q ${RUST_IMAGE_NAME} | xargs -r docker rmi

##@ Operate

.PHONY: start
start: start-dotnet start-rust ## Start all envoy containers

.PHONY: start-dotnet
start-dotnet: ## Start envoy container
	@echo "=> (dotnet) Starting envoy..."
	@docker run -d --name ${ENVOY_NAME}-dotnet -p 9901:9905 -p 10000:10005 ${DOTNET_IMAGE_NAME}

.PHONY: start-rust
start-rust: ## Start envoy container
	@echo "=> (rust) Starting envoy..."
	@docker run -d --name ${ENVOY_NAME}-rust -p 9901:9906 -p 10000:10006 ${RUST_IMAGE_NAME}

.PHONY: stop
stop: stop-dotnet stop-rust ## Stop all envoy containers

.PHONY: stop-dotnet
stop-dotnet: ## Stop envoy container
	@echo "=> Stopping envoy..."
	@docker stop ${ENVOY_NAME}-dotnet | xargs docker rm

.PHONY: stop-rust
stop-rust: ## Stop envoy container
	@echo "=> Stopping envoy..."
	@docker stop ${ENVOY_NAME}-rust | xargs docker rm

##@ Management

.PHONY: list
list: ## List all running containers
	@echo "=> Listing running containers..."
	@docker container list --all

.PHONY: inspect-rust
inspect-rust: ## Inspect rust image
	@echo "=> Inspecting Rust container..."
	@docker inspect ${ENVOY_NAME}-rust

.PHONY: inspect-dotnet
inspect-dotnet: ## Inspect dotnet image
	@echo "=> Inspecting .NET container..."
	@docker inspect ${ENVOY_NAME}-dotnet

.PHONY: shell-rust
shell-rust: ## Launch shell in envoy (rust) container
	@echo "=> Opening shell in Rust container..."
	@docker exec -it ${ENVOY_NAME}-rust /bin/sh

.PHONY: shell-dotnet
shell-dotnet: ## Launch shell in envoy (dotnet) container
	@echo "=> Opening shell in .NET container..."
	@docker exec -it ${ENVOY_NAME}-dotnet /bin/sh

##@ Logs

.PHONY: logs-dotnet
logs-dotnet: ## Display envoy container logs
	@echo "=> Showing envoy logs..."
	@docker logs -f ${ENVOY_NAME}-dotnet

.PHONY: logs-rust
logs-rust: ## Display envoy container logs
	@echo "=> Showing envoy logs..."
	@docker logs -f ${ENVOY_NAME}-rust

##@ Runtime

.PHONY: run-dotnet
run-dotnet: ## Run dotnet module
	@echo "=> Running .NET module with wasmtime..."
	@wasmtime run ${DOTNET_DIR}/bin/Debug/net8.0/wasi-wasm/dotnet.wasm

.PHONY: run-rust
run-rust: ## Run rust module
	@echo "=> Running Rust module with wasmtime..."
	@wasmtime run ${RUST_DIR}/target/wasm32-wasi/debug/module.wasm
