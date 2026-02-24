## GitLab CI/CD for MuleSoft
> Full GitLab pipeline with build, MUnit test, and deploy to CloudHub 2.0

### When to Use
- Your organization uses GitLab as the primary source control platform
- You need automated build, test, and deploy for Mule 4 applications
- You want environment-specific deployments triggered by branch or tag conventions

### Configuration

**.gitlab-ci.yml**
```yaml
stages:
  - build
  - test
  - deploy-dev
  - deploy-qa
  - deploy-prod

variables:
  MAVEN_OPTS: "-Dmaven.repo.local=$CI_PROJECT_DIR/.m2/repository"
  CONNECTED_APP_ID: $CONNECTED_APP_CLIENT_ID
  CONNECTED_APP_SECRET: $CONNECTED_APP_CLIENT_SECRET
  ORG_ID: $ANYPOINT_ORG_ID

cache:
  key: "$CI_COMMIT_REF_SLUG"
  paths:
    - .m2/repository/

build:
  stage: build
  image: maven:3.9-eclipse-temurin-17
  script:
    - mvn clean package -DskipTests
  artifacts:
    paths:
      - target/*.jar
    expire_in: 1 hour

unit-test:
  stage: test
  image: maven:3.9-eclipse-temurin-17
  script:
    - mvn test
  artifacts:
    when: always
    reports:
      junit: target/surefire-reports/TEST-*.xml
    paths:
      - target/surefire-reports/

deploy-dev:
  stage: deploy-dev
  image: maven:3.9-eclipse-temurin-17
  script:
    - |
      mvn deploy -DmuleDeploy \
        -Dmule.artifact=target/*.jar \
        -Danypoint.connectedApp.clientId=$CONNECTED_APP_ID \
        -Danypoint.connectedApp.clientSecret=$CONNECTED_APP_SECRET \
        -Danypoint.connectedApp.grantType=client_credentials \
        -Danypoint.environment=DEV \
        -Danypoint.businessGroup=$ORG_ID \
        -Dcloudhub2.target=us-east-2 \
        -Dcloudhub2.replicas=1 \
        -Dcloudhub2.vCores=0.1
  only:
    - develop
  environment:
    name: dev

deploy-qa:
  stage: deploy-qa
  image: maven:3.9-eclipse-temurin-17
  script:
    - |
      mvn deploy -DmuleDeploy \
        -Dmule.artifact=target/*.jar \
        -Danypoint.connectedApp.clientId=$CONNECTED_APP_ID \
        -Danypoint.connectedApp.clientSecret=$CONNECTED_APP_SECRET \
        -Danypoint.connectedApp.grantType=client_credentials \
        -Danypoint.environment=QA \
        -Danypoint.businessGroup=$ORG_ID \
        -Dcloudhub2.target=us-east-2 \
        -Dcloudhub2.replicas=2 \
        -Dcloudhub2.vCores=0.1
  only:
    - /^release\/.*$/
  environment:
    name: qa

deploy-prod:
  stage: deploy-prod
  image: maven:3.9-eclipse-temurin-17
  script:
    - |
      mvn deploy -DmuleDeploy \
        -Dmule.artifact=target/*.jar \
        -Danypoint.connectedApp.clientId=$CONNECTED_APP_ID \
        -Danypoint.connectedApp.clientSecret=$CONNECTED_APP_SECRET \
        -Danypoint.connectedApp.grantType=client_credentials \
        -Danypoint.environment=PROD \
        -Danypoint.businessGroup=$ORG_ID \
        -Dcloudhub2.target=us-east-2 \
        -Dcloudhub2.replicas=2 \
        -Dcloudhub2.vCores=0.2
  only:
    - tags
  when: manual
  environment:
    name: production
```

### How It Works
1. **Build stage** compiles the Mule app and produces a deployable JAR artifact
2. **Test stage** runs MUnit tests and publishes JUnit XML reports to GitLab
3. **Deploy stages** use the Mule Maven Plugin with Connected App credentials (no username/password)
4. Maven cache is keyed per branch to speed up subsequent builds
5. Production deploy requires manual approval via `when: manual`
6. Artifacts pass between stages so the same JAR is deployed everywhere

### Gotchas
- Store `CONNECTED_APP_CLIENT_ID` and `CONNECTED_APP_CLIENT_SECRET` as masked CI/CD variables in GitLab project settings
- The Connected App must have the CloudHub Developer role on each target environment
- `mvn deploy -DmuleDeploy` both uploads to Exchange and deploys to CH2; use `mvn mule:deploy` if you only want the runtime deploy
- Maven cache can grow large; set a TTL or clear periodically
- Ensure your `pom.xml` has the `mule-maven-plugin` with `cloudhub2Deployment` configuration

### Related
- [azure-devops](../azure-devops/) — Azure Pipelines equivalent
- [jenkins](../jenkins/) — Jenkinsfile equivalent
- [no-rebuild-promotion](../../environments/no-rebuild-promotion/) — Promote the same JAR without rebuilding
