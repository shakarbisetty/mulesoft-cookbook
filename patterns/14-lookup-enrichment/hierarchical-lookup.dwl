/**
 * Pattern: Hierarchical Lookup
 * Category: Lookup & Enrichment
 * Difficulty: Advanced
 *
 * Description: Build a parent-child hierarchy tree from flat data using
 * a parent ID reference. Common for org charts, product categories,
 * bill of materials (BOM), and folder/menu structures.
 *
 * Input (application/json):
 * [
 *   { "id": "1", "name": "Company", "parentId": null },
 *   { "id": "2", "name": "Engineering", "parentId": "1" },
 *   { "id": "3", "name": "Marketing", "parentId": "1" },
 *   { "id": "4", "name": "Frontend", "parentId": "2" },
 *   { "id": "5", "name": "Backend", "parentId": "2" },
 *   { "id": "6", "name": "Content", "parentId": "3" },
 *   { "id": "7", "name": "SEO", "parentId": "3" },
 *   { "id": "8", "name": "React Team", "parentId": "4" },
 *   { "id": "9", "name": "API Team", "parentId": "5" }
 * ]
 *
 * Output (application/json):
 * {
 *   "id": "1",
 *   "name": "Company",
 *   "children": [
 *     {
 *       "id": "2",
 *       "name": "Engineering",
 *       "children": [
 *         { "id": "4", "name": "Frontend", "children": [
 *             { "id": "8", "name": "React Team", "children": [] }
 *         ]},
 *         { "id": "5", "name": "Backend", "children": [
 *             { "id": "9", "name": "API Team", "children": [] }
 *         ]}
 *       ]
 *     },
 *     {
 *       "id": "3",
 *       "name": "Marketing",
 *       "children": [
 *         { "id": "6", "name": "Content", "children": [] },
 *         { "id": "7", "name": "SEO", "children": [] }
 *       ]
 *     }
 *   ]
 * }
 */
%dw 2.0
output application/json

// Index children by parentId for O(1) lookup
var childrenByParent = payload groupBy ($.parentId default "ROOT")

// Recursively build tree from a node
fun buildTree(nodeId: String): Object = do {
    var node = (payload filter $.id == nodeId)[0]
    var children = childrenByParent[nodeId] default []
    ---
    {
        id: node.id,
        name: node.name,
        children: children map (child) -> buildTree(child.id)
    }
}

// Find root nodes (parentId is null)
var roots = payload filter $.parentId == null
---
if (sizeOf(roots) == 1)
    buildTree(roots[0].id)
else
    roots map (root) -> buildTree(root.id)

// Alternative — flat hierarchy with depth/path:
// fun addPath(items, parentId, path, depth) =
//     (items filter $.parentId == parentId) flatMap (item) ->
//         [item ++ { path: "$(path)/$(item.name)", depth: depth }]
//         ++ addPath(items, item.id, "$(path)/$(item.name)", depth + 1)
// ---
// addPath(payload, null, "", 0)
