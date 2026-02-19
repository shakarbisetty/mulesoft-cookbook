/**
 * Pattern: Lazy Evaluation
 * Category: Performance & Optimization
 * Difficulty: Advanced
 *
 * Description: Use DataWeave's lazy evaluation and deferred output to
 * process large payloads without loading the entire dataset into memory.
 * Critical for transformations on payloads > 10 MB.
 *
 * Input (application/json):
 * [
 *   { "id": 1, "name": "Alice", "status": "active", "score": 85 },
 *   { "id": 2, "name": "Bob", "status": "inactive", "score": 42 },
 *   { "id": 3, "name": "Carol", "status": "active", "score": 91 },
 *   ... (thousands of records)
 * ]
 *
 * Output (application/json):
 * [
 *   { "id": 1, "name": "ALICE", "score": 85 },
 *   { "id": 3, "name": "CAROL", "score": 91 },
 *   ...
 * ]
 */
%dw 2.0

// deferred=true enables streaming output — records are written as they
// are produced, without buffering the entire result in memory
output application/json deferred=true
---
// This pipeline is evaluated lazily:
// 1. filter reads one record at a time
// 2. map transforms it immediately
// 3. output writes it to the stream
// The entire array is never fully in memory at once
payload
    filter $.status == "active"
    map (item) -> {
        id: item.id,
        name: upper(item.name),
        score: item.score
    }

// IMPORTANT: Operations that break streaming (require full dataset):
// - groupBy (needs all records to group)
// - orderBy (needs all records to sort)
// - sizeOf (needs to count all records)
// - distinctBy (needs to track all seen values)
//
// If you need these, consider:
// 1. Pre-sort in the database query
// 2. Use reduce with an accumulator
// 3. Process in chunks (see parallel-safe-chunking pattern)

// Alternative — streaming with write for piping to output:
// %dw 2.0
// output application/json deferred=true, indent=false
// ---
// payload map (item) -> { id: item.id, name: item.name }
