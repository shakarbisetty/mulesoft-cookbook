## API Lifecycle Management
> Manage APIs through design, implementation, deployment, deprecation, and retirement phases.

### When to Use
- Establishing a formal API lifecycle process
- Coordinating across teams who design, build, and operate APIs
- Governance compliance requiring lifecycle documentation

### Configuration / Code

**Lifecycle stages in API Manager:**
```
┌──────────┐    ┌────────────┐    ┌──────────┐    ┌────────────┐    ┌─────────┐
│  Design  │───>│   Build    │───>│  Deploy  │───>│ Deprecate  │───>│ Retire  │
│  (RAML)  │    │  (Mule 4)  │    │  (CH2)   │    │ (Sunset)   │    │ (410)   │
└──────────┘    └────────────┘    └──────────┘    └────────────┘    └─────────┘
```

**API Manager status transitions:**
```bash
# Promote through environments
anypoint-cli-v4 api-mgr api promote \
  --source Development \
  --target Production \
  --apiInstanceId 12345

# Deprecate an API version
anypoint-cli-v4 api-mgr api deprecate \
  --apiInstanceId 12345 \
  --message "Please migrate to v2 by March 2025"
```

### How It Works
1. **Design**: API spec created in Design Center, reviewed via governance
2. **Build**: Implementation scaffolded from spec, tested with MUnit
3. **Deploy**: Published to runtime, policies applied, documented in Exchange
4. **Deprecate**: Deprecation headers added, migration guides published
5. **Retire**: API removed, 410 responses returned, resources freed

### Gotchas
- Skip phases at your peril — "code first" APIs accumulate governance debt
- API Manager tracks lifecycle status — use it for visibility
- Exchange is the single source of truth for API contracts
- Retirement without proper deprecation notice breaks client trust

### Related
- [Deprecation Sunset](../deprecation-sunset/) — deprecation implementation
- [Backward Compatible](../backward-compatible/) — non-breaking changes
