/**
 * Pattern: Pagination Response
 * Category: API Response Patterns
 * Difficulty: Intermediate
 *
 * Description: Build a paginated API response with metadata and
 * navigation links. Standard pattern for any list-returning API endpoint.
 *
 * Input (application/json):
 * Assumes: payload = array of records from DB/API
 *          vars.page = current page (from query param)
 *          vars.pageSize = page size (from query param)
 *          vars.totalCount = total record count
 *          vars.basePath = "/api/v1/orders"
 *
 * Output (application/json):
 * {
 *   "data": [...],
 *   "meta": {
 *     "page": 2,
 *     "pageSize": 10,
 *     "totalRecords": 47,
 *     "totalPages": 5,
 *     "hasNext": true,
 *     "hasPrevious": true
 *   },
 *   "links": {
 *     "self": "/api/v1/orders?page=2&size=10",
 *     "first": "/api/v1/orders?page=1&size=10",
 *     "last": "/api/v1/orders?page=5&size=10",
 *     "next": "/api/v1/orders?page=3&size=10",
 *     "previous": "/api/v1/orders?page=1&size=10"
 *   }
 * }
 */
%dw 2.0
output application/json

var page = (attributes.queryParams.page default "1") as Number
var pageSize = (attributes.queryParams.size default "10") as Number
var totalRecords = vars.totalCount as Number
var totalPages = ceil(totalRecords / pageSize)
var basePath = vars.basePath default "/api/v1/resources"

fun buildLink(p: Number): String =
    "$(basePath)?page=$(p)&size=$(pageSize)"
---
{
    data: payload,
    meta: {
        page: page,
        pageSize: pageSize,
        totalRecords: totalRecords,
        totalPages: totalPages,
        hasNext: page < totalPages,
        hasPrevious: page > 1
    },
    links: {
        self: buildLink(page),
        first: buildLink(1),
        last: buildLink(totalPages),
        (next: buildLink(page + 1)) if page < totalPages,
        (previous: buildLink(page - 1)) if page > 1
    }
}
