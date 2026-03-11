/**
 * Pattern: Index-Based Lookup
 * Category: Performance & Optimization
 * Difficulty: Intermediate
 * Description: Pre-index reference data into a keyed object for O(1)
 * lookups instead of O(n) filter scans. Dramatically improves performance
 * when joining large datasets.
 *
 * Input (application/json):
 * {
 *   "transactions": [
 *     {
 *       "id": "T1",
 *       "accountId": "A1",
 *       "amount": 500
 *     },
 *     {
 *       "id": "T2",
 *       "accountId": "A2",
 *       "amount": 1200
 *     },
 *     {
 *       "id": "T3",
 *       "accountId": "A1",
 *       "amount": 300
 *     },
 *     {
 *       "id": "T4",
 *       "accountId": "A3",
 *       "amount": 750
 *     }
 *   ],
 *   "accounts": [
 *     {
 *       "id": "A1",
 *       "name": "Checking",
 *       "owner": "Alice"
 *     },
 *     {
 *       "id": "A2",
 *       "name": "Savings",
 *       "owner": "Bob"
 *     },
 *     {
 *       "id": "A3",
 *       "name": "Business",
 *       "owner": "Carol"
 *     }
 *   ]
 * }
 *
 * Output (application/json):
 * [
 * { "id": "TXN-001", "amount": 500, "accountName": "Checking", "owner": "Alice" },
 * { "id": "TXN-002", "amount": 1200, "accountName": "Savings", "owner": "Bob" },
 * { "id": "TXN-003", "amount": 300, "accountName": "Checking", "owner": "Alice" },
 * { "id": "TXN-004", "amount": 800, "accountName": "Business", "owner": "Carol" }
 * ]
 */
%dw 2.0
output application/json
var accountIndex = payload.accounts indexBy $.id
---
payload.transactions map (txn) -> do {
    var account = accountIndex[txn.accountId]
    ---
    ({ id: txn.id, amount: txn.amount, accountName: account.name default "Unknown", owner: account.owner default "Unknown" })
}
