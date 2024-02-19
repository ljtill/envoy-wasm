use log::info;
use proxy_wasm::traits::*;
use proxy_wasm::types::*;

// Define the main entry point for the WebAssembly module
proxy_wasm::main! {{
    // Set the log level to trace
    proxy_wasm::set_log_level(LogLevel::Trace);
    // Set the root context to HttpHeadersRoot
    proxy_wasm::set_root_context(|_| -> Box<dyn RootContext> { Box::new(HttpHeadersRoot) });
}}

// Define the root context struct
struct HttpHeadersRoot;

impl Context for HttpHeadersRoot {}

impl RootContext for HttpHeadersRoot {
    // Specify the context type as HttpContext
    fn get_type(&self) -> Option<ContextType> {
        Some(ContextType::HttpContext)
    }

    // Create a new HTTP context for each request
    fn create_http_context(&self, context_id: u32) -> Option<Box<dyn HttpContext>> {
        Some(Box::new(HttpHeaders { context_id }))
    }
}

// Define the HTTP context struct
struct HttpHeaders {
    context_id: u32,
}

impl Context for HttpHeaders {}

impl HttpContext for HttpHeaders {
    // Handle the request headers
    fn on_http_request_headers(&mut self, _: usize, _: bool) -> Action {
        // Log the request headers
        for (name, value) in &self.get_http_request_headers() {
            info!("#{} -> {}: {}", self.context_id, name, value);
        }

        // Check if the request path is "/wasm"
        match self.get_http_request_header(":path") {
            Some(path) if path == "/wasm" => {
                // Send a response with status code 200, headers, and body
                self.send_http_response(
                    200,
                    vec![("powered-by", "proxy-wasm")],
                    Some(b"Hello, World!\n"),
                );
                Action::Pause
            }
            _ => Action::Continue,
        }
    }

    // Handle the response headers
    fn on_http_response_headers(&mut self, _: usize, _: bool) -> Action {
        // Log the response headers
        for (name, value) in &self.get_http_response_headers() {
            info!("#{} <- {}: {}", self.context_id, name, value);
        }
        Action::Continue
    }

    // Handle the log event
    fn on_log(&mut self) {
        info!("#{} completed.", self.context_id);
    }
}
