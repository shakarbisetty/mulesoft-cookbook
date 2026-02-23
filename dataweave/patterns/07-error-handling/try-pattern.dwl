/**
 * Pattern: Try Pattern
 * Category: Error Handling
 * Difficulty: Intermediate
 *
 * Description: Use the try function to attempt an operation that might fail
 * and handle the error gracefully. Returns an object with `success` (boolean)
 * and either `result` or `error`. Essential for resilient transformations
 * where some records may have bad data but you don't want the entire
 * transformation to fail.
 *
 * Input (application/json):
 * {
 *   "records": [
 *     {"id": "R001", "amount": "1299.99", "date": "2026-02-15"},
 *     {"id": "R002", "amount": "not_a_number", "date": "2026-02-16"},
 *     {"id": "R003", "amount": "450.00", "date": "invalid-date"},
 *     {"id": "R004", "amount": "89.95", "date": "2026-02-18"}
 *   ]
 * }
 *
 * Output (application/json):
 * {
 *   "successful": [
 *     {"id": "R001", "amount": 1299.99, "date": "2026-02-15", "status": "valid"},
 *     {"id": "R004", "amount": 89.95, "date": "2026-02-18", "status": "valid"}
 *   ],
 *   "failed": [
 *     {"id": "R002", "error": "Cannot coerce String (not_a_number) to Number", "field": "amount"},
 *     {"id": "R003", "error": "Cannot coerce String (invalid-date) to Date", "field": "date"}
 *   ],
 *   "summary": {
 *     "total": 4,
 *     "valid": 2,
 *     "invalid": 2
 *   }
 * }
 */
%dw 2.0
output application/json

var processed = payload.records map (record) -> do {
    var amountResult = try(() -> record.amount as Number)
    var dateResult = try(() -> record.date as Date {format: "yyyy-MM-dd"})
    ---
    if (amountResult.success and dateResult.success)
        {success: true, data: {id: record.id, amount: amountResult.result, date: dateResult.result as String, status: "valid"}}
    else if (!amountResult.success)
        {success: false, data: {id: record.id, error: amountResult.error.message default "Amount parse error", field: "amount"}}
    else
        {success: false, data: {id: record.id, error: dateResult.error.message default "Date parse error", field: "date"}}
}
---
{
    successful: (processed filter $.success) map $.data,
    failed: (processed filter !$.success) map $.data,
    summary: {
        total: sizeOf(processed),
        valid: sizeOf(processed filter $.success),
        invalid: sizeOf(processed filter !$.success)
    }
}

// Alternative 1 — simple try with default fallback:
// try(() -> payload.value as Number) orElse 0

// Alternative 2 — try with error logging:
// var result = try(() -> payload.date as Date)
// ---
// if (result.success) result.result
// else do {
//     var _ = log("Date parse failed", result.error)
//     ---
//     now()
// }

// Alternative 3 — try on the entire transformation:
// try(() -> complexTransformation(payload)) orElse {error: "Transform failed"}
