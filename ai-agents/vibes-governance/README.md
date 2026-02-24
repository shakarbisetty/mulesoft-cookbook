## Vibes Governance
> Governance framework for AI-generated MuleSoft integrations with risk-based approval workflows.

### When to Use
- Your organization is adopting Vibes and needs guardrails for AI-generated code
- You need to define what Vibes can build autonomously vs what requires human review
- You are establishing compliance-compatible workflows for generated integrations
- You want a risk-based decision matrix for Vibes approval routing

### Configuration / Code

**Governance decision matrix by risk level:**

| Risk Level | Criteria | Vibes Autonomy | Review Required | Example |
|-----------|----------|----------------|-----------------|---------|
| **Low** | Internal API, no PII, no DB writes, dev/sandbox only | Generate + deploy to sandbox | Developer self-review | GET endpoint returning static config |
| **Medium** | Internal API with DB reads, non-PII data, staging | Generate + developer review | Peer code review | Customer list query, inventory lookup |
| **High** | DB writes, external API calls, PII handling | Generate only | Developer + architect review | Order processing, payment integration |
| **Critical** | Financial transactions, PHI/PII storage, compliance-scoped | Not recommended | Full review board | Payment processing, health records, audit trails |

**Approval workflow — Mule application YAML (pipeline definition):**

```yaml
# .github/workflows/vibes-governance.yml
name: Vibes Governance Gate

on:
  pull_request:
    paths:
      - 'src/main/mule/**'
    labels:
      - 'vibes-generated'

jobs:
  classify-risk:
    runs-on: ubuntu-latest
    outputs:
      risk_level: ${{ steps.assess.outputs.risk_level }}
    steps:
      - uses: actions/checkout@v4

      - name: Assess risk level
        id: assess
        run: |
          RISK="low"

          # Check for database write operations
          if grep -rq 'db:insert\|db:update\|db:delete\|db:bulk-insert' src/main/mule/; then
            RISK="high"
          fi

          # Check for database read operations
          if grep -rq 'db:select\|db:stored-procedure' src/main/mule/; then
            [ "$RISK" = "low" ] && RISK="medium"
          fi

          # Check for external HTTP calls
          if grep -rq 'http:request' src/main/mule/; then
            [ "$RISK" = "low" ] && RISK="medium"
          fi

          # Check for PII field names
          if grep -riq 'ssn\|social.security\|date.of.birth\|credit.card\|password\|secret' src/main/mule/; then
            RISK="critical"
          fi

          # Check for financial operations
          if grep -riq 'payment\|charge\|refund\|transfer\|debit\|credit' src/main/mule/; then
            RISK="critical"
          fi

          # Check for hardcoded credentials (always flag)
          if grep -rq 'password="\|token="\|apiKey="' src/main/mule/; then
            echo "::error::Hardcoded credentials detected in Vibes-generated code"
            RISK="critical"
          fi

          echo "risk_level=$RISK" >> $GITHUB_OUTPUT
          echo "Risk assessment: $RISK"

  gate-review:
    needs: classify-risk
    runs-on: ubuntu-latest
    steps:
      - name: Apply review requirements
        uses: actions/github-script@v7
        with:
          script: |
            const risk = '${{ needs.classify-risk.outputs.risk_level }}';
            const pr = context.payload.pull_request;

            const reviewPolicy = {
              low: { reviewers: 1, teams: [], label: 'risk:low' },
              medium: { reviewers: 1, teams: ['mule-developers'], label: 'risk:medium' },
              high: { reviewers: 2, teams: ['mule-developers', 'architects'], label: 'risk:high' },
              critical: { reviewers: 3, teams: ['mule-developers', 'architects', 'security'], label: 'risk:critical' }
            };

            const policy = reviewPolicy[risk];

            // Add risk label
            await github.rest.issues.addLabels({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: pr.number,
              labels: [policy.label, 'vibes-generated']
            });

            // Request team reviews
            if (policy.teams.length > 0) {
              await github.rest.pulls.requestReviewers({
                owner: context.repo.owner,
                repo: context.repo.repo,
                pull_number: pr.number,
                team_reviewers: policy.teams
              });
            }

            // Post review requirements comment
            const body = `## Vibes Governance Review\n\n` +
              `**Risk Level:** ${risk.toUpperCase()}\n` +
              `**Required Approvals:** ${policy.reviewers}\n` +
              `**Review Teams:** ${policy.teams.join(', ') || 'Developer self-review'}\n\n` +
              `### Review Checklist\n` +
              `- [ ] Error handling covers all connector error types\n` +
              `- [ ] No hardcoded credentials or URLs\n` +
              `- [ ] Connection configs use secure properties\n` +
              `- [ ] DataWeave transforms are null-safe\n` +
              `- [ ] MUnit tests exist with >80% coverage\n` +
              `- [ ] Logging includes correlationId, no PII\n` +
              (risk === 'high' || risk === 'critical' ?
                `- [ ] Architect has reviewed data flow diagram\n` +
                `- [ ] Security review of data handling\n` : '') +
              (risk === 'critical' ?
                `- [ ] Compliance team sign-off\n` +
                `- [ ] Penetration test results attached\n` : '');

            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: pr.number,
              body: body
            });
```

**Policy document — what Vibes can build autonomously:**

```yaml
# vibes-governance-policy.yaml
vibes_policy:
  version: "1.0"
  effective_date: "2026-01-01"

  autonomous_allowed:
    description: "Vibes can generate and developer can self-deploy to sandbox"
    conditions:
      - environment: [dev, sandbox]
      - data_classification: [public, internal]
      - operations: [read_only]
      - external_calls: false
      - pii_handling: false
    examples:
      - "GET endpoint returning configuration data"
      - "DataWeave transformation utility flows"
      - "Logging and monitoring sub-flows"
      - "Health check endpoints"

  review_required:
    description: "Vibes generates, human reviews before any deployment"
    conditions:
      - environment: [staging, production]
      - data_classification: [confidential]
      - operations: [read, write]
      - external_calls: true
    review_process:
      - developer_review: "Fix Vibes common issues (see code review patterns)"
      - peer_review: "Second developer validates logic and error handling"
      - architect_review: "For high/critical risk only"
    examples:
      - "CRUD API with database operations"
      - "Integration with external SaaS APIs"
      - "Event-driven flows with Anypoint MQ"

  not_recommended:
    description: "Vibes should not be used; build manually"
    conditions:
      - compliance: [SOX, HIPAA, PCI-DSS, GDPR_sensitive]
      - operations: [financial_transactions, phi_storage]
    rationale: "Compliance auditors require full traceability of code authorship and review"
    examples:
      - "Payment processing flows"
      - "Patient health record integrations"
      - "Financial reporting pipelines"
      - "Authentication/authorization flows"
```

**Audit trail — tracking Vibes-generated code:**

```xml
<!-- Add to every Vibes-generated flow as a comment header -->
<!--
    Generation Method: MuleSoft Vibes
    Generated Date: 2026-02-15
    Prompt Summary: Customer lookup API with MySQL backend
    Risk Assessment: MEDIUM
    Reviewed By: developer@company.com (2026-02-16)
    Approved By: architect@company.com (2026-02-17)
    PR: #142
    Modifications from generated:
      - Added error handler (CONNECTIVITY, TIMEOUT, NOT_FOUND)
      - Externalized DB config to secure properties
      - Added null-safety in DataWeave transforms
      - Added MUnit tests (85% coverage)
-->
```

### How It Works
1. Developer generates a Mule flow using Vibes, opens a PR with the `vibes-generated` label
2. The GitHub Actions workflow scans the generated code to automatically assess risk level
3. Based on risk, the workflow assigns appropriate reviewers and posts a tailored checklist
4. Reviewers validate the code against the checklist, applying fixes from the code review patterns guide
5. Required approvals (1-3 depending on risk) must be obtained before merge
6. An audit trail comment is added to the flow XML documenting the generation, review, and approval chain
7. For critical-risk flows, the policy recommends manual development instead of Vibes generation

### Gotchas
- **Compliance requirements (SOX, HIPAA) need extra review**: Regulated environments require provable code authorship. Vibes-generated code may not satisfy audit requirements without extensive documentation of the review and modification process
- **Risk classification is heuristic**: Automated scanning for keywords like "payment" or "SSN" can produce false positives. The human reviewer is the final authority on risk level
- **Vibes output evolves**: As Vibes improves, the governance policy should be revisited quarterly. What required manual building today may be safe to generate tomorrow
- **Team training required**: Governance is only effective if reviewers know what to look for. Pair the governance workflow with the code review patterns training
- **Audit trail maintenance**: The XML comment header must be updated on every modification. Stale audit trails are worse than no audit trail
- **Multi-flow applications**: Risk is assessed per PR, not per flow. A PR with one low-risk and one high-risk flow gets the higher risk classification

### Related
- [Vibes Code Review Patterns](../vibes-code-review-patterns/)
- [Vibes Prompt Engineering](../vibes-prompt-engineering/)
- [Vibes MUnit Generation](../../devops/testing/vibes-munit-generation/)
