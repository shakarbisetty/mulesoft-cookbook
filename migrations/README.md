# MuleSoft Migration Recipes

Production-grade migration guides for MuleSoft platform upgrades, runtime migrations, and architectural modernization.

**51 recipes** across 11 categories (including the pre-existing Java 17 guide).

## Categories

| Category | Recipes | Description |
|---|---|---|
| [java-17](./java-17/) | 1 | Complete Java 17 migration guide (pre-existing) |
| [java-versions](./java-versions/) | 6 | Recipes for migrating between Java versions in MuleSoft environments |
| [runtime-upgrades](./runtime-upgrades/) | 6 | Recipes for upgrading Mule runtime versions and migrating from Mule 3 to 4 |
| [cloudhub](./cloudhub/) | 7 | Recipes for migrating between CloudHub versions and deployment models |
| [dataweave](./dataweave/) | 2 | Recipes for DataWeave-specific migration issues |
| [api-specs](./api-specs/) | 5 | Recipes for migrating between API specification formats |
| [connectors](./connectors/) | 5 | Recipes for upgrading and replacing MuleSoft connectors |
| [security](./security/) | 4 | Recipes for migrating security configurations and access control |
| [monitoring](./monitoring/) | 4 | Recipes for migrating observability and monitoring infrastructure |
| [build-tools](./build-tools/) | 5 | Recipes for migrating build tools, CI/CD, and development environments |
| [architecture](./architecture/) | 6 | Recipes for migrating architectural patterns |

## Recipe Format

Each recipe follows a standard format:

- **When to Use** - Scenarios requiring this migration
- **Configuration / Code** - Production-grade XML, POM, CLI, and code snippets
- **How It Works** - Step-by-step explanation
- **Migration Checklist** - Actionable checklist
- **Gotchas** - Common mistakes and edge cases
- **Related** - Cross-references to related recipes

## Suggested Migration Paths

```
Mule 3 + Java 8
  |-> mule3-to-4-mma + transport-to-connector
  |-> java8-to-11 + jaxb-removal
  |-> mule44-to-46
  |-> java11-to-17-encapsulation + mule46-to-49
  |-> ch1-app-to-ch2 (or cloudhub-to-rtf)
```
