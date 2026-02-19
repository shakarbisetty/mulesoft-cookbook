/**
 * Pattern: HATEOAS Links
 * Category: API Response Patterns
 * Difficulty: Intermediate
 *
 * Description: Generate hypermedia links for REST resources following
 * HATEOAS (Hypermedia As The Engine Of Application State) principles.
 * Allows API clients to discover available actions dynamically.
 *
 * Input (application/json):
 * {
 *   "id": "ORD-12345",
 *   "customerId": "CUST-001",
 *   "status": "PENDING",
 *   "total": 299.99,
 *   "items": [
 *     { "productId": "PROD-A", "quantity": 2, "price": 99.99 },
 *     { "productId": "PROD-B", "quantity": 1, "price": 100.01 }
 *   ]
 * }
 *
 * Output (application/json):
 * {
 *   "id": "ORD-12345",
 *   "customerId": "CUST-001",
 *   "status": "PENDING",
 *   "total": 299.99,
 *   "items": [...],
 *   "_links": {
 *     "self":     { "href": "/api/v1/orders/ORD-12345", "method": "GET" },
 *     "update":   { "href": "/api/v1/orders/ORD-12345", "method": "PUT" },
 *     "cancel":   { "href": "/api/v1/orders/ORD-12345/cancel", "method": "POST" },
 *     "customer": { "href": "/api/v1/customers/CUST-001", "method": "GET" },
 *     "items":    { "href": "/api/v1/orders/ORD-12345/items", "method": "GET" },
 *     "invoice":  { "href": "/api/v1/orders/ORD-12345/invoice", "method": "GET" }
 *   }
 * }
 */
%dw 2.0
output application/json

var baseUrl = "/api/v1"
var orderId = payload.id

fun link(href: String, method: String): Object =
    { href: href, method: method }

// Determine available actions based on order status
var statusActions = payload.status match {
    case "PENDING" -> {
        update: link("$(baseUrl)/orders/$(orderId)", "PUT"),
        cancel: link("$(baseUrl)/orders/$(orderId)/cancel", "POST"),
        confirm: link("$(baseUrl)/orders/$(orderId)/confirm", "POST")
    }
    case "CONFIRMED" -> {
        cancel: link("$(baseUrl)/orders/$(orderId)/cancel", "POST"),
        ship: link("$(baseUrl)/orders/$(orderId)/ship", "POST"),
        invoice: link("$(baseUrl)/orders/$(orderId)/invoice", "GET")
    }
    case "SHIPPED" -> {
        track: link("$(baseUrl)/orders/$(orderId)/tracking", "GET"),
        invoice: link("$(baseUrl)/orders/$(orderId)/invoice", "GET")
    }
    case "DELIVERED" -> {
        "return": link("$(baseUrl)/orders/$(orderId)/return", "POST"),
        invoice: link("$(baseUrl)/orders/$(orderId)/invoice", "GET")
    }
    else -> {}
}
---
payload ++ {
    _links: {
        self: link("$(baseUrl)/orders/$(orderId)", "GET"),
        customer: link("$(baseUrl)/customers/$(payload.customerId)", "GET"),
        items: link("$(baseUrl)/orders/$(orderId)/items", "GET")
    } ++ statusActions
}
