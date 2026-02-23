/**
 * Pattern: Distinct By (Remove Duplicates)
 * Category: Array Manipulation
 * Difficulty: Intermediate
 *
 * Description: Remove duplicate elements from an array based on a specific
 * field or criteria. Use when ingesting data from multiple sources that may
 * contain overlapping records, or when deduplicating API responses.
 *
 * Input (application/json):
 * [
 *   {"customerId": "C-100", "name": "Alice Chen", "email": "alice@example.com", "source": "Salesforce"},
 *   {"customerId": "C-101", "name": "Bob Martinez", "email": "bob@example.com", "source": "Salesforce"},
 *   {"customerId": "C-100", "name": "Alice Chen", "email": "alice.chen@example.com", "source": "SAP"},
 *   {"customerId": "C-102", "name": "Carol Nguyen", "email": "carol@example.com", "source": "Salesforce"},
 *   {"customerId": "C-101", "name": "Robert Martinez", "email": "bob@example.com", "source": "HubSpot"}
 * ]
 *
 * Output (application/json):
 * [
 *   {"customerId": "C-100", "name": "Alice Chen", "email": "alice@example.com", "source": "Salesforce"},
 *   {"customerId": "C-101", "name": "Bob Martinez", "email": "bob@example.com", "source": "Salesforce"},
 *   {"customerId": "C-102", "name": "Carol Nguyen", "email": "carol@example.com", "source": "Salesforce"}
 * ]
 */
%dw 2.0
output application/json
---
payload distinctBy (customer) -> customer.customerId

// Alternative 1 — shorthand:
// payload distinctBy $.customerId

// Alternative 2 — distinct by multiple fields (composite key):
// payload distinctBy (customer) -> customer.customerId ++ customer.source

// Alternative 3 — distinct on primitive arrays:
// [1, 2, 3, 2, 1, 4] distinctBy $
// Output: [1, 2, 3, 4]
