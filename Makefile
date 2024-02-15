.PHONY: all
all: clean build

##@ General

.PHONY: help
help: ## Display this help content.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Build

.PHONY: build
build: ## Build module and proxy artifacts.
	@echo "=> (module) Compiling .NET source..."
	@dotnet build ./modules/dotnet/dotnet.csproj

	@echo "=> (module) Compiling Rust source..."
	@rustup target add wasm32-wasi
	@cargo build --manifest-path ./modules/rust/Cargo.toml --target wasm32-wasi

	@echo "=> (proxy) Building .NET image..."
	@docker build --build-arg MOD_PATH=./modules/dotnet/bin/Debug/net8.0/wasi-wasm/dotnet.wasm -t envoy:dotnet --file ./proxies/envoy/Dockerfile .

	@echo "=> (proxy) Building Rust image..."
	@docker build --build-arg MOD_PATH=./modules/rust/target/wasm32-wasi/debug/module.wasm -t envoy:rust --file ./proxies/envoy/Dockerfile .

.PHONY: clean
clean: ## Clean module and proxy artifacts.
	@echo "=> (module) Cleaning .NET source..."
	@dotnet clean ./modules/dotnet/dotnet.csproj

	@echo "=> (module) Cleaning Rust source..."
	@cargo clean --manifest-path ./modules/rust/Cargo.toml

	@echo "=> (proxy) Cleaning .NET image..."
	@docker rmi envoy:dotnet

	@echo "=> (proxy) Cleaning Rust image..."
	@docker rmi envoy:rust

##@ Deployment

.PHONY: start-dotnet
start: ## Start proxy container.
	@echo "=> (dotnet) Starting Envoy Proxy..."
	@docker run -d --name envoy -p 9901:9901 -p 10000:10000 envoy:latest

.PHONY: start-rust
start: ## Start proxy container.
	@echo "=> (rust) Starting Envoy Proxy..."
	@docker run -d --name envoy -p 9901:9901 -p 10000:10000 envoy:latest



.PHONY: stop
stop: ## Stop proxy container.
	@echo "=> Stopping Envoy Proxy..."
	@docker stop envoy | xargs docker rm

.PHONY: restart
restart: stop start ## Restart proxy container.

##@ Troubleshoot

.PHONY:
logs: ## Display proxy container logs.
	@echo "=> Showing Envoy Proxy logs..."
	@docker logs -f envoy
