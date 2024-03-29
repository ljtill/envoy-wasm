SHELL:=/usr/bin/env bash

#
# Directories
#

ROOT_DIR := .
DOTNET_ROOT_DIR := ${ROOT_DIR}/modules/dotnet
DOTNET_BUILD_DIR := ${DOTNET_ROOT_DIR}/bin/Debug/net9.0/wasi-wasm/AppBundle
RUST_ROOT_DIR := ${ROOT_DIR}/modules/rust
RUST_BUILD_DIR := ${ROOT_DIR}/target/wasm32-wasi/debug
ENVOY_ROOT_DIR := ${ROOT_DIR}/proxies/envoy

#
# Tools
#

DOTNET_IMAGE_NAME := envoy:dotnet
DOTNET_PROJECT_FILE := ${DOTNET_ROOT_DIR}/Envoy.csproj

RUST_IMAGE_NAME := envoy:rust
RUST_MANIFEST_FILE := ${RUST_ROOT_DIR}/Cargo.toml

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
lcn: list-containers
lim: list-images
idn: inspect-dotnet
irs: inspect-rust
hdn: shell-dotnet
hrs: shell-rust
ldn: logs-dotnet
lrs: logs-rust
rdn: run-dotnet
rrs: run-rust

#
# Targets
#

##@ General

.PHONY: help
help:  # Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[0-9A-Za-z_-]+:.*?##/ { printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2 } /^\$$\([0-9A-Za-z_-]+\):.*?##/ { gsub("_","-", $$1); printf "  \033[36m%-25s\033[0m %s\n", tolower(substr($$1, 3, length($$1)-7)), $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: all
all: clean build  ## Execute all build tasks

##@ Build

.PHONY: build-dotnet
build-dotnet: ## Build dotnet module
	@echo "=> (module) Compiling .NET source..."
	@dotnet build -c Debug ${DOTNET_PROJECT_FILE}
	@echo "=> (proxy) Building .NET image..."
	@docker build --build-arg MOD_PATH=${DOTNET_BUILD_DIR}/Envoy.wasm -t ${ENVOY_NAME}:dotnet --file ${ENVOY_ROOT_DIR}/Dockerfile .

.PHONY: build-rust
build-rust: ## Build rust module
	@echo "=> (module) Compiling Rust source..."
	@rustup target add wasm32-wasi
	@cargo build --manifest-path ${RUST_ROOT_DIR}/Cargo.toml --target wasm32-wasi --target-dir ${RUST_ROOT_DIR}/target
	@echo "=> (proxy) Building Rust image..."
	@docker build --build-arg MOD_PATH=${RUST_BUILD_DIR}/module.wasm -t ${ENVOY_NAME}:rust --file ${ENVOY_ROOT_DIR}/Dockerfile .

##@ Generate
# TODO: Implement wit-bindgen targets
# wit-bindgen c-sharp --runtime native-aot ./modules/dotnet/Envoy.wit --out-dir ./modules/dotnet/Generated/

##@ Test

.PHONY: test-dotnet
test-dotnet: ## Test dotnet module
	@echo "=> (module) Testing .NET source..."
	@dotnet test ${DOTNET_PROJECT_FILE} --verbosity minimal

.PHONY: test-rust
test-rust: ## Test rust module
	@echo "=> (module) Testing Rust source..."
	@cargo test --manifest-path ${RUST_DIR}/Cargo.toml

##@ Validate

.PHONY: validate-dotnet
validate-dotnet: ## Validate dotnet module
	@echo "=> (module) Validating .NET module..."
	@wasm-tools validate -vv ${DOTNET_BUILD_DIR}/Envoy.wasm

.PHONY: validate-rust
validate-rust: ## Validate rust module
	@echo "=> (module) Validating Rust module..."
	@wasm-tools validate -vv ${RUST_DIR}/target/wasm32-wasi/debug/module.wasm

##@ Clean

.PHONY: clean-dotnet
clean-dotnet: ## Clean dotnet artifacts
	@echo "=> (module) Cleaning .NET source..."
	@dotnet clean ${DOTNET_PROJECT_FILE} --verbosity minimal
	@echo "=> (module) Removing compiled module..."
	@rm -f ${DOTNET_ROOT_DIR}/Envoy.wasm
	@echo "=> (proxy) Cleaning .NET image..."
	@docker images -q ${DOTNET_IMAGE_NAME} | xargs -r docker rmi

.PHONY: clean-rust
clean-rust: ## Clean rust artifacts
	@echo "=> (module) Cleaning Rust source..."
	@cargo clean --manifest-path ${RUST_DIR}/Cargo.toml
	@echo "=> (proxy) Cleaning Rust image..."
	@docker images -q ${RUST_IMAGE_NAME} | xargs -r docker rmi

##@ Operate

.PHONY: start-dotnet
start-dotnet: ## Start dotnet container
	@echo "=> (dotnet) Starting envoy..."
	@docker run -d --name ${ENVOY_NAME}-dotnet -p 9905:9901 -p 10005:10000 ${DOTNET_IMAGE_NAME}

.PHONY: start-rust
start-rust: ## Start rust container
	@echo "=> (rust) Starting envoy..."
	@docker run -d --name ${ENVOY_NAME}-rust -p 9906:9901 -p 10006:10000 ${RUST_IMAGE_NAME}

.PHONY: stop-dotnet
stop-dotnet: ## Stop dotnet container
	@echo "=> Stopping envoy..."
	@docker stop ${ENVOY_NAME}-dotnet | xargs docker rm

.PHONY: stop-rust
stop-rust: ## Stop rust container
	@echo "=> Stopping envoy..."
	@docker stop ${ENVOY_NAME}-rust | xargs docker rm

##@ Manage

.PHONY: list-containers
list-containers: ## List all containers
	@echo "=> Listing running containers..."
	@docker container list --all

.PHONY: list-images
list-images: ## List all images
	@echo "=> Listing images..."
	@docker images --all

##@ Debug

.PHONY: inspect-dotnet
inspect-dotnet: ## Inspect dotnet image
	@echo "=> Inspecting .NET container..."
	@docker inspect ${ENVOY_NAME}-dotnet

.PHONY: inspect-rust
inspect-rust: ## Inspect rust image
	@echo "=> Inspecting Rust container..."
	@docker inspect ${ENVOY_NAME}-rust

.PHONY: shell-dotnet
shell-dotnet: ## Launch dotnet shell
	@echo "=> Opening shell in .NET container..."
	@docker exec -it ${ENVOY_NAME}-dotnet /bin/sh

.PHONY: shell-rust
shell-rust: ## Launch rust shell
	@echo "=> Opening shell in Rust container..."
	@docker exec -it ${ENVOY_NAME}-rust /bin/sh

##@ Logs

.PHONY: logs-dotnet
logs-dotnet: ## Display dotnet logs
	@echo "=> Showing envoy logs..."
	@docker logs -f ${ENVOY_NAME}-dotnet

.PHONY: logs-rust
logs-rust: ## Display envoy logs
	@echo "=> Showing envoy logs..."
	@docker logs -f ${ENVOY_NAME}-rust

##@ Runtime

.PHONY: run-dotnet
run-dotnet: ## Run dotnet module
	@echo "=> Running .NET module with wasmtime..."
	@wasmtime --dir . -- ${DOTNET_BUILD_DIR}/Envoy.wasm

.PHONY: run-rust
run-rust: ## Run rust module
	@echo "=> Running Rust module with wasmtime..."
	@wasmtime --dir . -- ${RUST_BUILD_DIR}/module.wasm
