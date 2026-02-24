## Bitbucket Pipelines for MuleSoft
> Bitbucket Pipelines with Jira integration, deployment tracking, and parallel steps

### When to Use
- Your team uses Bitbucket Cloud for source control
- You want automatic Jira deployment tracking via Bitbucket integrations
- You need a simple YAML-based CI/CD without managing Jenkins infrastructure

### Configuration

**bitbucket-pipelines.yml**
```yaml
image: maven:3.9-eclipse-temurin-17

definitions:
  caches:
    maven: ~/.m2/repository
  steps:
    - step: &build-test
        name: Build & Test
        caches:
          - maven
        script:
          - mvn clean package -B
        artifacts:
          - target/*.jar
          - target/surefire-reports/**

    - step: &deploy
        name: Deploy to CloudHub 2.0
        caches:
          - maven
        script:
          - |
            mvn mule:deploy -B \
              -Dmule.artifact=target/*.jar \
              -Danypoint.connectedApp.clientId=$CONNECTED_APP_ID \
              -Danypoint.connectedApp.clientSecret=$CONNECTED_APP_SECRET \
              -Danypoint.connectedApp.grantType=client_credentials \
              -Danypoint.environment=$DEPLOY_ENV \
              -Danypoint.businessGroup=$ORG_ID \
              -Dcloudhub2.target=$CH2_TARGET \
              -Dcloudhub2.replicas=$CH2_REPLICAS \
              -Dcloudhub2.vCores=$CH2_VCORES

pipelines:
  branches:
    develop:
      - step: *build-test
      - step:
          <<: *deploy
          name: Deploy to DEV
          deployment: dev

    release/*:
      - step: *build-test
      - step:
          <<: *deploy
          name: Deploy to QA
          deployment: qa

  tags:
    'v*':
      - step: *build-test
      - step:
          <<: *deploy
          name: Deploy to PROD
          deployment: production
          trigger: manual

  pull-requests:
    '**':
      - step: *build-test
```

**Deployment environment variables** (set in Bitbucket settings):

| Environment | Variable | Value |
|---|---|---|
| dev | `DEPLOY_ENV` | `DEV` |
| dev | `CH2_REPLICAS` | `1` |
| dev | `CH2_VCORES` | `0.1` |
| qa | `DEPLOY_ENV` | `QA` |
| qa | `CH2_REPLICAS` | `2` |
| qa | `CH2_VCORES` | `0.1` |
| production | `DEPLOY_ENV` | `PROD` |
| production | `CH2_REPLICAS` | `2` |
| production | `CH2_VCORES` | `0.2` |

### How It Works
1. **YAML anchors** (`&build-test`, `&deploy`) reduce duplication across branch pipelines
2. **Deployment environments** map to Bitbucket's deployment tracking — shows deploy history per environment
3. **Jira integration** automatically links deployments to Jira issues when commit messages contain issue keys (e.g., `MULE-123`)
4. **Pull request pipelines** run build and test on every PR without deploying
5. Production deploys require `trigger: manual` for approval
6. Artifacts from the build step automatically flow to the deploy step

### Gotchas
- Bitbucket Pipelines has a 4GB memory limit per step; large Mule projects may need the `size: 2x` option (8GB)
- Secure variables must be configured per deployment environment in Repository Settings > Deployments
- The `deployment` keyword must match a pre-configured environment name exactly
- Bitbucket Pipes (e.g., `atlassian/jira-create-deployment`) can enhance tracking but add execution time
- Maximum 100 minutes per pipeline on the free tier; MUnit suites can be slow

### Related
- [gitlab-ci](../gitlab-ci/) — GitLab CI equivalent
- [jenkins](../jenkins/) — Jenkinsfile equivalent
- [trunk-based-dev](../trunk-based-dev/) — Trunk-based workflow
