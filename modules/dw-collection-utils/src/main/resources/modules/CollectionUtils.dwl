%dw 2.0
import * from dw::core::Arrays
import * from dw::core::Objects

/**
 * Module: CollectionUtils
 * Version: 1.0.0
 *
 * Reusable array and object utility functions for DataWeave 2.x.
 * Import with: import modules::CollectionUtils
 *
 * Functions (15):
 *   chunk, compact, intersection, difference, union, pick, omit,
 *   deepMerge, pivot, unpivot, flattenKeys, unique, partition,
 *   indexBy, countBy
 */

/**
 * Split an array into chunks of a given size.
 * chunk([1,2,3,4,5], 2) -> [[1,2],[3,4],[5]]
 */
fun chunk(arr: Array, size: Number): Array =
    if (sizeOf(arr) <= size) [arr]
    else [arr[0 to (size - 1)]] ++ chunk(arr[size to -1], size)

/**
 * Remove null and empty string values from an array.
 * compact([1, null, 2, "", 3, null]) -> [1, 2, 3]
 */
fun compact(arr: Array): Array =
    arr filter (item) -> item != null and item != ""

/**
 * Return elements present in both arrays.
 * intersection([1,2,3], [2,3,4]) -> [2,3]
 */
fun intersection(a: Array, b: Array): Array =
    a filter (item) -> b contains item

/**
 * Return elements in array a that are not in array b.
 * difference([1,2,3,4], [2,4]) -> [1,3]
 */
fun difference(a: Array, b: Array): Array =
    a filter (item) -> !(b contains item)

/**
 * Combine two arrays and remove duplicates.
 * union([1,2,3], [2,3,4,5]) -> [1,2,3,4,5]
 */
fun union(a: Array, b: Array): Array =
    (a ++ b) distinctBy $

/**
 * Select only specified keys from an object.
 * pick({a:1, b:2, c:3}, ["a","c"]) -> {a:1, c:3}
 */
fun pick(obj: Object, keys: Array<String>): Object =
    obj filterObject (val, key) -> keys contains (key as String)

/**
 * Remove specified keys from an object.
 * omit({a:1, b:2, c:3}, ["b"]) -> {a:1, c:3}
 */
fun omit(obj: Object, keys: Array<String>): Object =
    obj filterObject (val, key) -> !(keys contains (key as String))

/**
 * Recursively merge two objects. Values from b override a.
 * Nested objects are merged; non-object values from b win.
 * deepMerge({a:1, nested:{x:1, y:2}}, {a:9, nested:{y:99, z:3}})
 *   -> {a:9, nested:{x:1, y:99, z:3}}
 */
fun deepMerge(a: Object, b: Object): Object =
    a mapObject ((aVal, aKey) ->
        if (b[aKey as String]? and (aVal is Object) and (b[aKey as String] is Object))
            {(aKey): deepMerge(aVal as Object, b[aKey as String] as Object)}
        else if (b[aKey as String]?)
            {(aKey): b[aKey as String]}
        else
            {(aKey): aVal}
    ) ++ (b filterObject (bVal, bKey) -> !(a[bKey as String]?))

/**
 * Pivot an array of objects (rows) into a columnar object.
 * pivot([{name:"A",score:90},{name:"B",score:80}])
 *   -> {name:["A","B"], score:[90,80]}
 */
fun pivot(arr: Array<Object>): Object =
    do {
        var keys = keysOf(arr[0] default {}) map ($ as String)
        ---
        keys reduce ((key, acc = {}) ->
            acc ++ {(key): arr map $[key]}
        )
    }

/**
 * Unpivot a columnar object back to an array of row objects.
 * unpivot({name:["A","B"], score:[90,80]})
 *   -> [{name:"A",score:90},{name:"B",score:80}]
 */
fun unpivot(obj: Object): Array<Object> =
    do {
        var keys = keysOf(obj) map ($ as String)
        var len = sizeOf(valuesOf(obj)[0] default [])
        ---
        (0 to (len - 1)) map ((i) ->
            keys reduce ((key, acc = {}) ->
                acc ++ {(key): obj[key][i]}
            )
        )
    }

/**
 * Flatten nested object keys into dot-notation.
 * flattenKeys({a:{b:1, c:{d:2}}}, ".") -> {"a.b":1, "a.c.d":2}
 */
fun flattenKeys(obj: Object, sep: String): Object =
    obj mapObject ((val, key) ->
        if (val is Object)
            flattenKeys(val as Object, sep) mapObject ((innerVal, innerKey) ->
                {((key as String) ++ sep ++ (innerKey as String)): innerVal}
            )
        else
            {(key): val}
    )

/**
 * Remove duplicate values from an array.
 * unique([1,2,2,3,3,3]) -> [1,2,3]
 */
fun unique(arr: Array): Array =
    arr distinctBy $

/**
 * Split an array into two groups based on a predicate.
 * partition([1,2,3,4,5], (n) -> mod(n,2) == 0) -> {pass:[2,4], fail:[1,3,5]}
 */
fun partition(arr: Array, fn: (Any) -> Boolean): Object =
    {
        pass: arr filter (item) -> fn(item),
        fail: arr filter (item) -> !fn(item)
    }

/**
 * Index an array of objects by a key field, producing a keyed lookup object.
 * indexBy([{id:"a",val:1},{id:"b",val:2}], "id") -> {a:{id:"a",val:1}, b:{id:"b",val:2}}
 */
fun indexBy(arr: Array<Object>, key: String): Object =
    arr reduce ((item, acc = {}) ->
        acc ++ {((item[key] default "") as String): item}
    )

/**
 * Group array elements by a function result and count each group.
 * countBy([1,2,3,4,5], (n) -> if (mod(n,2)==0) "even" else "odd") -> {odd:3, even:2}
 */
fun countBy(arr: Array, fn: (Any) -> Any): Object =
    arr reduce ((item, acc = {}) -> do {
        var groupKey = fn(item) as String
        var current = (acc[groupKey] default 0) as Number
        ---
        acc ++ {(groupKey): current + 1}
    })
