## Design Center to Code-First API Development
> Migrate from Design Center GUI to code-first API development in Git

### When to Use
- Team wants API specs in version control
- Need CI/CD for API specification validation
- Design Center collaboration limitations
- Adopting Anypoint Code Builder

### Configuration / Code

#### 1. Export from Design Center

```bash
anypoint-cli-v4 designcenter project download \
    --name "Customer API" \
    --output ./api-specs/customer-api/
```

#### 2. Git Repository Structure

```
api-specs/
  customer-api/
    customer-api.raml
    types/
    examples/
    exchange.json
  .github/workflows/
    api-governance.yml
```

#### 3. Exchange Metadata

```json
{
    "main": "customer-api.raml",
    "name": "Customer API",
    "classifier": "raml",
    "groupId": "com.mycompany",
    "assetId": "customer-api",
    "version": "1.0.0"
}
```

#### 4. GitHub Actions Pipeline

```yaml
name: API Governance
on:
  pull_request:
    paths: ['api-specs/**']
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm install -g @stoplight/spectral-cli @aml-org/amf-client-js
      - name: Validate specs
        run: |
          for spec in api-specs/*/exchange.json; do
            dir=$(dirname "$spec")
            main=$(jq -r '.main' "$spec")
            amf parse "$dir/$main" --validate
          done
  publish:
    needs: validate
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Publish to Exchange
        env:
          ANYPOINT_CLIENT_ID: $${{ secrets.ANYPOINT_CLIENT_ID }}
          ANYPOINT_CLIENT_SECRET: $${{ secrets.ANYPOINT_CLIENT_SECRET }}
        run: anypoint-cli-v4 exchange asset upload --organization "My Org"
```

### How It Works
1. API specs authored as code in Git
2. PRs trigger validation (parsing, linting, governance)
3. Merge to main triggers Exchange publishing
4. Exchange is consumer source of truth; Git is author source of truth

### Migration Checklist
- [ ] Export all specs from Design Center
- [ ] Set up Git repository structure
- [ ] Add `exchange.json` metadata per API
- [ ] Configure CI pipeline
- [ ] Train team on code-first workflow
- [ ] Configure branch protection

### Gotchas
- Design Center interactive mocking lost (use Prism)
- Exchange versioning must be managed manually
- Some Design Center features unavailable in code-first mode

### Related
- [fragment-library-migration](../fragment-library-migration/) - Reusable type libraries
- [studio-to-acb](../../build-tools/studio-to-acb/) - IDE migration
