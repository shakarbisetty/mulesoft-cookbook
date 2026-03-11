/**
 * Pattern: Tail Recursion
 * Category: Advanced Patterns
 * Difficulty: Advanced
 * Description: Use tail-recursive functions with the @TailRec annotation for
 * stack-safe recursion on large datasets. Standard recursion in DataWeave can
 * overflow the stack on deep structures. Tail recursion with an accumulator
 * lets DW optimize the call into a loop, handling thousands of iterations.
 *
 * Input (application/json):
 * {
 *   "tree": {
 *     "name": "Root",
 *     "children": [
 *       {
 *         "name": "A",
 *         "children": [
 *           {
 *             "name": "A1",
 *             "children": []
 *           },
 *           {
 *             "name": "A2",
 *             "children": []
 *           }
 *         ]
 *       },
 *       {
 *         "name": "B",
 *         "children": [
 *           {
 *             "name": "B1",
 *             "children": []
 *           }
 *         ]
 *       }
 *     ]
 *   }
 * }
 *
 * Output (application/json):
 * [
 * {"name": "All Products", "depth": 0, "path": "All Products"},
 * {"name": "Electronics", "depth": 1, "path": "All Products > Electronics"},
 * {"name": "Laptops", "depth": 2, "path": "All Products > Electronics > Laptops"},
 * {"name": "Monitors", "depth": 2, "path": "All Products > Electronics > Monitors"},
 * {"name": "4K Monitors", "depth": 3, "path": "All Products > Electronics > Monitors > 4K Monitors"},
 * {"name": "Ultrawide Monitors", "depth": 3, "path": "All Products > Electronics > Monitors > Ultrawide Monitors"},
 * {"name": "Furniture", "depth": 1, "path": "All Products > Furniture"},
 * {"name": "Desks", "depth": 2, "path": "All Products > Furniture > Desks"},
 * {"name": "Chairs", "depth": 2, "path": "All Products > Furniture > Chairs"}
 * ]
 */
%dw 2.0
output application/json
@TailRec()
fun flattenTree(queue, acc = []) = if (isEmpty(queue)) acc
  else do {
    var current = queue[0]
    var rest = queue[1 to -1] default []
    ---
    flattenTree(rest ++ (current.children default []), acc << {name: current.name})
  }
---
flattenTree([payload.tree])
