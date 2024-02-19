FROM envoyproxy/envoy:dev

ARG MOD_PATH

COPY ./proxies/envoy/envoy.yaml /etc/envoy/envoy.yaml
COPY ${MOD_PATH} /etc/envoy/wasm_service.wasm

RUN chmod go+r /etc/envoy/envoy.yaml
