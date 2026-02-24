## Custom Rust/WASM Policy
> Build a custom Flex Gateway policy in Rust, compiled to WebAssembly.

### When to Use
- Out-of-the-box policies do not meet your requirements
- High-performance custom logic at the gateway layer
- IP filtering, custom auth, or request transformation

### Configuration / Code

**Rust policy (src/lib.rs):**
```rust
use proxy_wasm::traits::*;
use proxy_wasm::types::*;

struct MyPolicy;

impl HttpContext for MyPolicy {
    fn on_http_request_headers(&mut self, _: usize, _: bool) -> Action {
        if let Some(key) = self.get_http_request_header("x-api-key") {
            if key == "valid-key-123" {
                return Action::Continue;
            }
        }
        self.send_http_response(401, vec![], Some(b"Unauthorized"));
        Action::Pause
    }
}

impl Context for MyPolicy {}
```

**Build and deploy:**
```bash
cargo build --target wasm32-wasi --release
cp target/wasm32-wasi/release/my_policy.wasm ./policy.wasm
```

**Policy binding YAML:**
```yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: Extension
metadata:
  name: my-custom-policy
spec:
  extends:
  - name: extension-definition
  - name: envoy-filter
    namespace: default
  source: /policies/policy.wasm
```

### How It Works
1. Write policy logic in Rust using the proxy-wasm SDK
2. Compile to WebAssembly targeting wasm32-wasi
3. Deploy the .wasm file alongside the Flex Gateway
4. Apply via PolicyBinding YAML referencing the extension

### Gotchas
- WASM policies run in a sandbox — no filesystem or network access from policy code
- Debug with `proxy_wasm::hostcalls::log` — stdout is not available
- WASM binary size affects gateway startup time — optimize with `wasm-opt`
- Policy errors crash the filter chain — test thoroughly before production

### Related
- [DataWeave Transform Policy](../dataweave-transform/) — simpler DW-based policies
- [Publish to Exchange](../publish-to-exchange/) — sharing custom policies
