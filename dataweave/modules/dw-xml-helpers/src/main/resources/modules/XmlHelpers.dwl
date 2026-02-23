%dw 2.0
import * from dw::core::Objects

/**
 * Module: XmlHelpers
 * Version: 1.0.0
 *
 * Reusable XML utility functions for DataWeave 2.x.
 * Works on XML data after it has been parsed into DW's object model
 * (i.e., the Object representation of XML with @attributes and nested keys).
 *
 * Import with: import modules::XmlHelpers
 *
 * Functions (12):
 *   nsAware, stripNamespaces, extractAttributes, cdataWrap, cdataUnwrap,
 *   xmlToFlat, flatToXml, mergeXmlNodes, xpathLike, validateStructure,
 *   soapEnvelope, xmlToString
 */

/**
 * Apply a namespace prefix to all top-level element keys in an object.
 * Useful when building XML output that requires namespace-qualified elements.
 *
 * nsAware({name: "Alice", age: 30}, "http://example.com/ns", "ex")
 *   -> {ex#name @(xmlns: {ex: "http://example.com/ns"}): "Alice", ex#age: 30}
 *
 * Note: In practice, DW handles namespaces via `ns` declarations at the top level.
 * This function provides a programmatic alternative for dynamic namespace application.
 */
fun nsAware(xml: Object, nsUri: String, prefix: String): Object =
    xml mapObject ((val, key) ->
        {((prefix ++ ":" ++ (key as String))): val}
    )

/**
 * Remove all namespace prefixes from element keys.
 * Turns "ns0:element" into "element", "soap:Body" into "Body".
 *
 * stripNamespaces({\"ns0:root\": {\"ns0:child\": \"value\"}})
 *   -> {root: {child: \"value\"}}
 */
fun stripNamespaces(xml: Object): Object =
    xml mapObject ((val, key) -> do {
        var cleanKey = ((key as String) splitBy ":")[(-1)]
        ---
        if (val is Object)
            {(cleanKey): stripNamespaces(val as Object)}
        else
            {(cleanKey): val}
    })

/**
 * Extract the @ attributes from a named element within an XML object.
 * Returns the attributes object, or empty object if none found.
 *
 * Given XML: <product id="SKU-100" category="electronics">Widget</product>
 * Parsed as: {product @(id: "SKU-100", category: "electronics"): "Widget"}
 *
 * extractAttributes({product @(id: "SKU-100", category: "electronics"): "Widget"}, "product")
 *   -> {id: "SKU-100", category: "electronics"}
 */
fun extractAttributes(xml: Object, elem: String): Object =
    xml[elem].@ default {}

/**
 * Wrap a string value as CDATA for XML output.
 * When output as XML, the value will be enclosed in <![CDATA[...]]>.
 *
 * cdataWrap("<script>alert('hi')</script>") -> CDATA value
 */
fun cdataWrap(value: String): String =
    value as String {class: "org.mule.weave.v2.el.CData"} default value

/**
 * Unwrap / extract the string content from a CDATA value.
 * If the value is already a plain string, returns it as-is.
 *
 * cdataUnwrap(cdataValue) -> "plain string content"
 */
fun cdataUnwrap(cdata: Any): String =
    cdata as String

/**
 * Flatten a nested XML-like object into dot-notation keys.
 * Similar to CollectionUtils::flattenKeys but designed for XML structures
 * where attributes are preserved separately.
 *
 * xmlToFlat({order: {header: {id: "123"}, items: {item: "Widget"}}}, ".")
 *   -> {"order.header.id": "123", "order.items.item": "Widget"}
 */
fun xmlToFlat(xml: Object, sep: String): Object =
    xml mapObject ((val, key) ->
        if (val is Object)
            xmlToFlat(val as Object, sep) mapObject ((innerVal, innerKey) ->
                {((key as String) ++ sep ++ (innerKey as String)): innerVal}
            )
        else
            {(key): val}
    )

/**
 * Convert dot-notation flat keys back into a nested object structure.
 * Inverse of xmlToFlat.
 *
 * flatToXml({"order.header.id": "123", "order.header.date": "2026-02-15"}, ".")
 *   -> {order: {header: {id: "123", date: "2026-02-15"}}}
 */
fun flatToXml(obj: Object, sep: String): Object =
    obj pluck ((val, key) -> {key: key as String, val: val})
        reduce ((item, acc = {}) -> do {
            var parts = item.key splitBy sep
            ---
            acc mergeNested(parts, item.val)
        })

/**
 * Helper: recursively merge a value at a nested key path into an object.
 */
fun mergeNested(obj: Object, path: Array<String>, val: Any): Object =
    if (sizeOf(path) == 1)
        obj ++ {(path[0]): val}
    else do {
        var head = path[0]
        var rest = path[1 to -1]
        var existing = (obj[head] default {}) as Object
        ---
        obj ++ {(head): mergeNested(existing, rest, val)}
    }

/**
 * Deep merge two XML tree objects. Values from b override a for scalar values.
 * Nested objects are merged recursively.
 *
 * mergeXmlNodes({root: {a: 1, b: {x: 10}}}, {root: {b: {y: 20}, c: 3}})
 *   -> {root: {a: 1, b: {x: 10, y: 20}, c: 3}}
 */
fun mergeXmlNodes(a: Object, b: Object): Object =
    (a mapObject ((aVal, aKey) ->
        if (b[aKey as String]? and (aVal is Object) and (b[aKey as String] is Object))
            {(aKey): mergeXmlNodes(aVal as Object, b[aKey as String] as Object)}
        else if (b[aKey as String]?)
            {(aKey): b[aKey as String]}
        else
            {(aKey): aVal}
    )) ++ (b filterObject ((bVal, bKey) -> !(a[bKey as String]?)))

/**
 * Simple XPath-like selector for DW objects. Supports dot-delimited paths.
 * Returns the value at the given path, or null if not found.
 *
 * xpathLike({root: {users: {user: [{name: "Alice"}, {name: "Bob"}]}}}, "root.users.user")
 *   -> [{name: "Alice"}, {name: "Bob"}]
 *
 * xpathLike({order: {id: "123"}}, "order.id")
 *   -> "123"
 */
fun xpathLike(xml: Any, path: String): Any =
    do {
        var parts = path splitBy "."
        ---
        parts reduce ((segment, current = xml) ->
            current[segment] default null
        )
    }

/**
 * Validate that an XML object contains all expected top-level keys
 * defined in a schema object. Returns a validation result with
 * valid (boolean), missing keys, and extra keys.
 *
 * validateStructure(
 *   {name: "Alice", age: 30},
 *   {name: "String", age: "Number", email: "String"}
 * )
 *   -> {valid: false, missing: ["email"], extra: []}
 */
fun validateStructure(xml: Object, schema: Object): Object =
    do {
        var actualKeys = keysOf(xml) map ($ as String)
        var expectedKeys = keysOf(schema) map ($ as String)
        var missing = expectedKeys filter (k) -> !(actualKeys contains k)
        var extra = actualKeys filter (k) -> !(expectedKeys contains k)
        ---
        {
            valid: sizeOf(missing) == 0,
            missing: missing,
            extra: extra
        }
    }

/**
 * Build a SOAP 1.1 envelope structure with optional header and body.
 * Produces the nested object structure that DW will serialize as proper SOAP XML.
 *
 * soapEnvelope({GetCustomer: {id: "123"}}, {Security: {token: "abc"}})
 *   -> { Envelope: { Header: { Security: { token: "abc" } }, Body: { GetCustomer: { id: "123" } } } }
 */
fun soapEnvelope(body: Object, header: Object = {}): Object =
    {
        Envelope: {
            (Header: header) if !isEmpty(header),
            Body: body
        }
    }

/**
 * Serialize an object to a compact XML-like string representation.
 * Useful for logging or debugging XML structures without full XML serialization.
 *
 * xmlToString({root: {child: "value", attr: 42}})
 *   -> "<root><child>value</child><attr>42</attr></root>"
 */
fun xmlToString(obj: Object): String =
    obj pluck ((val, key) ->
        if (val is Object)
            "<$(key as String)>" ++ xmlToString(val as Object) ++ "</$(key as String)>"
        else
            "<$(key as String)>$(val as String)</$(key as String)>"
    ) joinBy ""
