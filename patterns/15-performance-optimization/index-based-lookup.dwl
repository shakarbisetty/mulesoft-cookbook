/**
 * Pattern: Index-Based Lookup
 * Category: Performance & Optimization
 * Difficulty: Intermediate
 *
 * Description: Pre-index reference data into a keyed object for O(1)
 * lookups instead of O(n) filter scans. Dramatically improves performance
 * when joining large datasets.
 *
 * Input (application/json):
 * {
 *   "transactions": [
 *     { "id": "TXN-001", "accountId": "ACC-100", "amount": 500 },
 *     { "id": "TXN-002", "accountId": "ACC-200", "amount": 1200 },
 *     { "id": "TXN-003", "accountId": "ACC-100", "amount": 300 },
 *     { "id": "TXN-004", "accountId": "ACC-300", "amount": 800 }
 *   ],
 *   "accounts": [
 *     { "id": "ACC-100", "name": "Checking", "owner": "Alice" },
 *     { "id": "ACC-200", "name": "Savings", "owner": "Bob" },
 *     { "id": "ACC-300", "name": "Business", "owner": "Carol" }
 *   ]
 * }
 *
 * Output (application/json):
 * [
 *   { "id": "TXN-001", "amount": 500, "accountName": "Checking", "owner": "Alice" },
 *   { "id": "TXN-002", "amount": 1200, "accountName": "Savings", "owner": "Bob" },
 *   { "id": "TXN-003", "amount": 300, "accountName": "Checking", "owner": "Alice" },
 *   { "id": "TXN-004", "amount": 800, "accountName": "Business", "owner": "Carol" }
 * ]
 */
%dw 2.0
output application/json

// FAST: Pre-index accounts by ID — O(n) once, then O(1) per lookup
// This turns an array into a keyed object: { "ACC-100": {...}, "ACC-200": {...} }
var accountIndex = payload.accounts indexBy $.id

---
payload.transactions map (txn) -> do {
    // O(1) lookup — direct key access
    var account = accountIndex[txn.accountId]
    ---
    {
        id: txn.id,
        amount: txn.amount,
        accountName: account.name default "Unknown",
        owner: account.owner default "Unknown"
    }
}

// COMPARISON — SLOW approach (DO NOT use for large datasets):
//
// payload.transactions map (txn) -> do {
//     // O(n) lookup — scans entire accounts array for EVERY transaction
//     var account = (payload.accounts filter $.id == txn.accountId)[0]
//     ---
//     { id: txn.id, accountName: account.name }
// }
//
// Performance difference:
// 1,000 transactions × 1,000 accounts:
//   filter approach: ~1,000,000 comparisons (O(n×m))
//   index approach:  ~2,000 operations (O(n+m))
