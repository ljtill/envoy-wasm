FROM envoyproxy/envoy:dev

COPY ./src/proxy/envoy.yaml /etc/envoy/envoy.yaml

# COPY ./src/config/wasm_service.wasm /etc/envoy/wasm_service.wasm

RUN chmod go+r /etc/envoy/envoy.yaml
