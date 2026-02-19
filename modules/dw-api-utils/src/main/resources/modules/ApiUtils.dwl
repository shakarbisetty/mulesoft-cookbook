%dw 2.0
import dw::Crypto

/**
 * ApiUtils — API response helper functions for DataWeave 2.x
 *
 * Build standardized API responses with pagination, error handling,
 * field filtering, sorting, and query string utilities.
 *
 * Usage:
 *   import modules::ApiUtils
 *   ApiUtils::paginate(payload, 1, 10)
 *   ApiUtils::buildErrorResponse(404, "Not Found", "Customer CUST-001 not found")
 */

/**
 * Build a paginated response with metadata.
 * Returns { data: Array, meta: { page, pageSize, totalRecords, totalPages, hasNext, hasPrevious } }
 */
fun paginate(arr: Array, page: Number, size: Number): Object = do {
    var safeSize = if (size > 0) size else 10
    var totalRecords = sizeOf(arr)
    var totalPages = ceil(totalRecords / safeSize)
    var startIdx = (page - 1) * safeSize
    var endIdx = min([startIdx + safeSize - 1, totalRecords - 1])
    ---
    {
        data: if (startIdx >= totalRecords) [] else arr[startIdx to endIdx],
        meta: {
            page: page,
            pageSize: size,
            totalRecords: totalRecords,
            totalPages: totalPages,
            hasNext: page < totalPages,
            hasPrevious: page > 1
        }
    }
}

/**
 * Build pagination navigation links.
 */
fun buildLinks(basePath: String, page: Number, totalPages: Number, pageSize: Number): Object =
    {
        self: "$(basePath)?page=$(page)&size=$(pageSize)",
        first: "$(basePath)?page=1&size=$(pageSize)",
        last: "$(basePath)?page=$(totalPages)&size=$(pageSize)",
        (next: "$(basePath)?page=$(page + 1)&size=$(pageSize)") if page < totalPages,
        (previous: "$(basePath)?page=$(page - 1)&size=$(pageSize)") if page > 1
    }

/**
 * Filter object to only include specified fields.
 * Supports dot notation for nested fields (e.g., "address.city").
 */
fun filterFields(obj: Object, fields: Array<String>): Object =
    if (isEmpty(fields)) obj
    else obj filterObject (value, key) ->
        fields some (f) -> f == (key as String) or f startsWith "$(key as String)."

/**
 * Sort an array of objects by a field name with direction.
 * order: "asc" or "desc"
 */
fun sortBy(arr: Array, field: String, order: String = "asc"): Array =
    if (lower(order) == "desc")
        (arr orderBy $[field])[-1 to 0]
    else
        arr orderBy $[field]

/**
 * Wrap data in a standard success response envelope.
 */
fun buildSuccessResponse(data: Any, meta: Object = {}): Object =
    {
        success: true,
        data: data,
        (meta: meta) if !isEmpty(meta)
    }

/**
 * Build an RFC 7807 Problem Details error response.
 */
fun buildErrorResponse(status: Number, title: String, detail: String): Object =
    {
        "type": "about:blank",
        title: title,
        status: status,
        detail: detail
    }

/**
 * Generate an ETag hash from a payload for cache validation.
 */
fun addETag(data: Any): String = do {
    var serialized = write(data, "application/json")
    var hash = Crypto::hashWith(serialized as Binary {encoding: "UTF-8"}, "MD5")
    ---
    "\"$(hash)\""
}

/**
 * Build a summary of bulk operation results.
 * Input: array of { id, status: "SUCCESS"|"FAILED", error? }
 */
fun buildBulkResult(results: Array<Object>): Object = do {
    var total = sizeOf(results)
    var successes = results filter $.status == "SUCCESS"
    var failures = results filter $.status == "FAILED"
    ---
    {
        summary: {
            total: total,
            successful: sizeOf(successes),
            failed: sizeOf(failures)
        },
        (errors: failures map { id: $.id, error: $.error }) if !isEmpty(failures)
    }
}

/**
 * Convert an object to a URL query string.
 * { name: "John", age: 30 } → "name=John&age=30"
 */
fun toQueryString(params: Object): String =
    params pluck (value, key) ->
        "$(key as String)=$(value as String)"
    joinBy "&"

/**
 * Parse a URL query string into an object.
 * "name=John&age=30" → { name: "John", age: "30" }
 */
fun fromQueryString(qs: String): Object =
    if (isEmpty(trim(qs))) {}
    else (qs splitBy "&") reduce (pair, acc = {}) -> do {
        var parts = pair splitBy "="
        ---
        if (isEmpty(parts[0])) acc
        else acc ++ { (parts[0]): parts[1] default "" }
    }
