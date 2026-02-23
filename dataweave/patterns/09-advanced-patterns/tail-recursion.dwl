/**
 * Pattern: Tail Recursion
 * Category: Advanced Patterns
 * Difficulty: Advanced
 *
 * Description: Use tail-recursive functions with the @TailRec annotation for
 * stack-safe recursion on large datasets. Standard recursion in DataWeave can
 * overflow the stack on deep structures. Tail recursion with an accumulator
 * lets DW optimize the call into a loop, handling thousands of iterations.
 *
 * Input (application/json):
 * {
 *   "nestedCategories": {
 *     "name": "All Products",
 *     "children": [
 *       {
 *         "name": "Electronics",
 *         "children": [
 *           {"name": "Laptops", "children": []},
 *           {"name": "Monitors", "children": [
 *             {"name": "4K Monitors", "children": []},
 *             {"name": "Ultrawide Monitors", "children": []}
 *           ]}
 *         ]
 *       },
 *       {
 *         "name": "Furniture",
 *         "children": [
 *           {"name": "Desks", "children": []},
 *           {"name": "Chairs", "children": []}
 *         ]
 *       }
 *     ]
 *   }
 * }
 *
 * Output (application/json):
 * [
 *   {"name": "All Products", "depth": 0, "path": "All Products"},
 *   {"name": "Electronics", "depth": 1, "path": "All Products > Electronics"},
 *   {"name": "Laptops", "depth": 2, "path": "All Products > Electronics > Laptops"},
 *   {"name": "Monitors", "depth": 2, "path": "All Products > Electronics > Monitors"},
 *   {"name": "4K Monitors", "depth": 3, "path": "All Products > Electronics > Monitors > 4K Monitors"},
 *   {"name": "Ultrawide Monitors", "depth": 3, "path": "All Products > Electronics > Monitors > Ultrawide Monitors"},
 *   {"name": "Furniture", "depth": 1, "path": "All Products > Furniture"},
 *   {"name": "Desks", "depth": 2, "path": "All Products > Furniture > Desks"},
 *   {"name": "Chairs", "depth": 2, "path": "All Products > Furniture > Chairs"}
 * ]
 */
%dw 2.0
output application/json

// Flatten a tree into a list using tail-recursive helper
// The queue pattern: process head, enqueue children, recurse on rest
@TailRec()
fun flattenTree(
    queue: Array<{node: Object, depth: Number, path: String}>,
    acc: Array = []
): Array =
    if (isEmpty(queue)) acc
    else do {
        var current = queue[0]
        var rest = queue[1 to -1] default []
        var children = (current.node.children default []) map (child) -> {
            node: child,
            depth: current.depth + 1,
            path: current.path ++ " > " ++ child.name
        }
        ---
        flattenTree(
            rest ++ children,
            acc << {
                name: current.node.name,
                depth: current.depth,
                path: current.path
            }
        )
    }
---
flattenTree([{
    node: payload.nestedCategories,
    depth: 0,
    path: payload.nestedCategories.name
}])

// Alternative 1 — tail-recursive sum (simple example):
// @TailRec()
// fun sum(arr: Array<Number>, acc: Number = 0): Number =
//     if (isEmpty(arr)) acc
//     else sum(arr[1 to -1] default [], acc + arr[0])
// ---
// sum([1, 2, 3, 4, 5])  // Output: 15

// Alternative 2 — tail-recursive flatten with depth limit:
// @TailRec()
// fun flattenToDepth(queue: Array, acc: Array = [], maxDepth: Number = 3): Array =
//     if (isEmpty(queue)) acc
//     else do {
//         var current = queue[0]
//         var rest = queue[1 to -1] default []
//         var children = if (current.depth < maxDepth)
//             (current.node.children default []) map {node: $, depth: current.depth + 1}
//             else []
//         ---
//         flattenToDepth(rest ++ children, acc << current.node.name, maxDepth)
//     }

// Tip: @TailRec() only works when the recursive call is the LAST operation
// in the function. If you do anything after the recursive call, it won't
// be optimized and may still overflow on large inputs.
