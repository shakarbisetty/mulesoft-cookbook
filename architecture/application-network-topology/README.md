## Application Network Topology
> Map your API catalog as a network graph to find bottlenecks, single points of failure, and shadow APIs

### When to Use
- You have 50+ APIs in production and cannot visualize how they interconnect
- You need to assess the blast radius of changing or retiring a specific API
- Stakeholders ask "what depends on X?" and nobody can answer confidently
- You are planning a platform migration and need to sequence API moves by dependency order
- API reuse KPIs need hard data instead of guesswork

### Configuration / Code

#### Application Network as a Graph

```
Every API is a node. Every dependency is a directed edge.

              ┌─────────────────┐
              │  exp-mobile-app  │  fan-in: 0 (leaf consumer)
              └────────┬────────┘  fan-out: 2
                       │
           ┌───────────┴───────────┐
           ▼                       ▼
  ┌─────────────────┐    ┌─────────────────┐
  │  prc-orders     │    │  prc-customers   │  fan-in: 3 (heavily reused)
  │  fan-in: 2      │    │  fan-in: 3       │  fan-out: 2
  │  fan-out: 3     │    │  fan-out: 2      │
  └──┬────┬────┬────┘    └────┬────┬───────┘
     │    │    │              │    │
     ▼    │    ▼              ▼    ▼
  ┌──────┐│ ┌──────────┐ ┌──────┐ ┌──────────┐
  │sys-  ││ │sys-       │ │sys-  │ │sys-      │
  │order-││ │inventory  │ │crm   │ │loyalty   │
  │db    ││ │           │ │      │ │          │
  └──────┘│ └───────────┘ └──────┘ └──────────┘
          │
          ▼
  ┌──────────────┐
  │sys-payment   │  fan-in: 4 (CRITICAL — single point of failure)
  │              │  fan-out: 1
  └──────┬───────┘
         ▼
  ┌──────────────┐
  │ Payment      │
  │ Gateway      │
  │ (external)   │
  └──────────────┘
```

#### Key Metrics

| Metric | Formula | What It Tells You |
|--------|---------|-------------------|
| **Fan-In** (consumers) | Count of APIs that call this API | Reuse level. High fan-in = high value, high blast radius |
| **Fan-Out** (dependencies) | Count of APIs this API calls | Coupling level. High fan-out = fragile, many failure modes |
| **Criticality Score** | `fan-in × (1 + fan-out/10)` | Prioritization for DR, monitoring, and testing investment |
| **Depth** | Longest dependency chain from consumer to backend | Latency indicator. Depth > 4 suggests over-layering |
| **Orphan APIs** | APIs with fan-in = 0 and not a consumer entry point | Candidates for retirement |
| **Single Point of Failure** | APIs where removing them disconnects the graph | Must have DR, high availability, circuit breakers |

#### Anypoint CLI Script to Extract Dependencies

```bash
#!/bin/bash
# extract-api-dependencies.sh
# Extracts API dependency data from Anypoint Platform for graph analysis

# Prerequisites:
# - anypoint-cli installed and authenticated
# - jq installed

ORG_ID="your-org-id"
ENV_NAME="Production"
OUTPUT_FILE="api_network.json"

echo '{"nodes": [], "edges": []}' > "$OUTPUT_FILE"

# Step 1: List all APIs in the environment
echo "Fetching API list..."
APIS=$(anypoint-cli api-mgr:api:list \
    --organizationId "$ORG_ID" \
    --environmentName "$ENV_NAME" \
    --output json 2>/dev/null)

# Step 2: For each API, extract metadata
echo "$APIS" | jq -c '.[]' | while read -r api; do
    API_ID=$(echo "$api" | jq -r '.id')
    API_NAME=$(echo "$api" | jq -r '.assetId')
    API_VERSION=$(echo "$api" | jq -r '.assetVersion')

    # Add node
    jq --arg name "$API_NAME" --arg id "$API_ID" --arg version "$API_VERSION" \
        '.nodes += [{"id": $id, "name": $name, "version": $version}]' \
        "$OUTPUT_FILE" > tmp.json && mv tmp.json "$OUTPUT_FILE"

    # Step 3: Get contracts (who consumes this API)
    CONTRACTS=$(anypoint-cli api-mgr:contract:list \
        --apiInstanceId "$API_ID" \
        --organizationId "$ORG_ID" \
        --environmentName "$ENV_NAME" \
        --output json 2>/dev/null)

    echo "$CONTRACTS" | jq -c '.[]' | while read -r contract; do
        CLIENT_APP=$(echo "$contract" | jq -r '.applicationName')
        jq --arg from "$CLIENT_APP" --arg to "$API_NAME" \
            '.edges += [{"from": $from, "to": $to, "type": "consumes"}]' \
            "$OUTPUT_FILE" > tmp.json && mv tmp.json "$OUTPUT_FILE"
    done
done

echo "Network graph exported to $OUTPUT_FILE"
echo "Nodes: $(jq '.nodes | length' $OUTPUT_FILE)"
echo "Edges: $(jq '.edges | length' $OUTPUT_FILE)"

# Step 4: Calculate metrics
echo ""
echo "=== Top 10 APIs by Fan-In (most consumed) ==="
jq -r '.edges | group_by(.to) | map({api: .[0].to, fanIn: length}) | sort_by(-.fanIn) | .[:10][] | "\(.fanIn)\t\(.api)"' "$OUTPUT_FILE"

echo ""
echo "=== Orphan APIs (fan-in = 0, not entry points) ==="
jq -r '
  (.edges | map(.to) | unique) as $consumed |
  (.edges | map(.from) | unique) as $consumers |
  .nodes | map(.name) | map(select(. as $n | ($consumed | index($n)) == null and ($consumers | index($n)) == null))
' "$OUTPUT_FILE"
```

#### Visualizing the Network

Once you have `api_network.json`, visualize it:

```
Option 1: Graphviz (quick, local)

  # Convert JSON to DOT format
  jq -r '"digraph APINetwork {",
    "  rankdir=LR;",
    "  node [shape=box, style=rounded];",
    (.edges[] | "  \"\(.from)\" -> \"\(.to)\";"),
    "}"' api_network.json > network.dot

  dot -Tpng network.dot -o network.png

Option 2: D3.js force-directed graph (interactive, share with stakeholders)

  Load api_network.json into a D3 force-directed graph.
  Color nodes by tier (experience=blue, process=green, system=orange).
  Size nodes by fan-in (bigger = more consumed).

Option 3: Anypoint Visualizer (built-in, if licensed)

  Anypoint Platform > Visualizer
  Automatically maps dependencies from runtime call data.
  No script needed, but requires Titanium subscription.
```

#### Dependency Impact Matrix

Before changing or retiring an API, generate an impact matrix:

```
Retiring sys-payment-gateway:

  Direct dependents (fan-in=1 hop):
    ├─ prc-order-orchestration  ←── IMPACTED
    ├─ prc-subscription-billing ←── IMPACTED
    └─ prc-refund-processing    ←── IMPACTED

  Indirect dependents (fan-in=2 hops):
    ├─ exp-mobile-checkout      ←── IMPACTED (via prc-order-orchestration)
    ├─ exp-web-store            ←── IMPACTED (via prc-order-orchestration)
    └─ exp-partner-portal       ←── IMPACTED (via prc-subscription-billing)

  Total blast radius: 6 APIs, 3 consumer applications
  Risk: HIGH — requires coordinated migration plan
```

### How It Works
1. **Extract** API data from Anypoint Platform using the CLI script or Anypoint Visualizer
2. **Build the graph** — nodes are APIs, edges are dependencies (call relationships + contract registrations)
3. **Calculate metrics** — fan-in, fan-out, criticality score, depth for every node
4. **Identify risks** — single points of failure (high fan-in, no redundancy), over-layered chains (depth > 4), orphan APIs
5. **Act on findings** — add circuit breakers to critical APIs, retire orphans, collapse unnecessary tiers
6. **Repeat quarterly** — the network evolves; metrics should be tracked over time

### Gotchas
- **Shadow APIs not in the catalog break the graph.** If teams deploy APIs without registering them in API Manager or Exchange, they are invisible. Your dependency map is only as complete as your catalog. Enforce Exchange publishing as part of CI/CD
- **Versioning breaks dependency tracking.** If `prc-orders-v1` and `prc-orders-v2` are tracked as separate nodes, fan-in splits. Normalize by asset ID, not by version
- **Runtime dependencies differ from design-time.** A RAML spec might not list all backends an API calls (e.g., dynamic dispatch, runtime configuration). Anypoint Visualizer captures runtime calls, which is more accurate than spec analysis
- **High fan-in is not always good.** An API with fan-in of 20 is valuable but also a liability. Any breaking change or downtime affects 20 consumers. Invest proportionally in testing, monitoring, and backward compatibility
- **The graph changes faster than you think.** A quarterly review is minimum. Consider automating the extraction script as a scheduled pipeline that alerts on topology changes (new orphans, sudden fan-in changes, new critical-path APIs)

### Related
- [C4E Setup Playbook](../c4e-setup-playbook/) — C4E uses network topology data to measure reuse rate and API adoption KPIs
- [API-Led Anti-Patterns](../api-led-anti-patterns/) — Network depth > 4 often signals unnecessary tiers
- [Multi-Region DR Strategy](../multi-region-dr-strategy/) — Critical-path APIs (high criticality score) need DR investment
