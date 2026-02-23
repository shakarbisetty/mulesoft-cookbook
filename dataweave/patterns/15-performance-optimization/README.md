# 15 — Performance & Optimization

Patterns for handling large payloads efficiently — lazy evaluation, streaming, index-based lookups, delta processing, and parallel-safe chunking.

| Pattern | File | Difficulty | Description |
|---------|------|-----------|-------------|
| Lazy Evaluation | [lazy-evaluation.dwl](lazy-evaluation.dwl) | Advanced | Deferred execution for large payloads |
| Streaming with Reduce | [streaming-reduce.dwl](streaming-reduce.dwl) | Advanced | Process large files without loading into memory |
| Index-Based Lookup | [index-based-lookup.dwl](index-based-lookup.dwl) | Intermediate | Pre-index arrays for O(1) lookups vs O(n) filter |
| Selective Transform | [selective-transform.dwl](selective-transform.dwl) | Intermediate | Transform only changed fields (delta processing) |
| Parallel-Safe Chunking | [parallel-safe-chunking.dwl](parallel-safe-chunking.dwl) | Advanced | Split payload for parallel batch processing |

---

[Back to all patterns](../../README.md)
