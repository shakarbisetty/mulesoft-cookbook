/**
 * Pattern: GraphQL Response Flattening
 * Category: API Response Patterns
 * Difficulty: Intermediate
 * Description: Transform nested GraphQL query responses into flat, API-friendly
 * structures. Handles connection/edge/node patterns, nullable fields, aliased
 * queries, and pagination cursors common in GraphQL APIs like GitHub, Shopify,
 * and Salesforce DataGraph.
 *
 * Input (application/json):
 * {
 *   "data": {
 *     "organization": {
 *       "name": "Acme Corp",
 *       "repositories": {
 *         "totalCount": 42,
 *         "pageInfo": {
 *           "hasNextPage": true,
 *           "endCursor": "Y3Vyc29y"
 *         },
 *         "edges": [
 *           {
 *             "node": {
 *               "name": "api-gateway",
 *               "stargazerCount": 150,
 *               "primaryLanguage": {
 *                 "name": "Java"
 *               }
 *             }
 *           },
 *           {
 *             "node": {
 *               "name": "dw-utils",
 *               "stargazerCount": 89,
 *               "primaryLanguage": {
 *                 "name": "DataWeave"
 *               }
 *             }
 *           },
 *           {
 *             "node": {
 *               "name": "frontend",
 *               "stargazerCount": 45,
 *               "primaryLanguage": null
 *             }
 *           }
 *         ]
 *       }
 *     }
 *   }
 * }
 *
 * Output (application/json):
 * {
 * "org": "Acme Corp",
 * "totalRepos": 42,
 * "repos": [
 * {"name": "api-gateway", "stars": 150, "language": "Java"},
 * {"name": "dw-utils", "stars": 89, "language": "DataWeave"},
 * {"name": "frontend", "stars": 45, "language": "Unknown"}
 * ],
 * "pagination": {"hasNext": true, "cursor": "Y3Vyc29yOnYxOjQy"}
 * }
 */
%dw 2.0
output application/json
var org = payload.data.organization
var repos = org.repositories
---
{
  org: org.name,
  totalRepos: repos.totalCount,
  repos: repos.edges map (edge) -> ({
    name: edge.node.name, stars: edge.node.stargazerCount,
    language: edge.node.primaryLanguage.name default "Unknown"
  }),
  pagination: { hasNext: repos.pageInfo.hasNextPage, cursor: repos.pageInfo.endCursor }
}
