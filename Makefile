build-module-rust:
	@echo "=> (module) Compiling Rust source..."
	@rustup target add wasm32-wasi
	@cargo build --manifest-path ./modules/rust/Cargo.toml --target wasm32-wasi

build-module-dotnet:
	@echo "=> (module) Compiling .NET source..."
	@dotnet build ./modules/dotnet/dotnet.csproj

build-proxy-rust:
	@echo "=> (proxy) Building Envoy image..."
	@docker build --build-arg MOD_PATH=./modules/rust/target/wasm32-wasi/debug/module.wasm -t envoy --file ./proxies/envoy/Dockerfile .

build-proxy-dotnet:
	@echo "=> (proxy) Building Envoy image..."
	@docker build --build-arg MOD_PATH=./modules/dotnet/bin/Debug/net8.0/wasi-wasm/dotnet.wasm -t envoy --file ./proxies/envoy/Dockerfile .

start-proxy:
	@echo "=> Starting Envoy Proxy..."
	@docker run -d --name envoy -p 9901:9901 -p 10000:10000 envoy:latest

stop-proxy:
	@echo "=> Stopping Envoy Proxy..."
	@docker stop envoy | xargs docker rm

logs:
	@echo "=> Showing Envoy Proxy logs..."
	@docker logs -f envoy
