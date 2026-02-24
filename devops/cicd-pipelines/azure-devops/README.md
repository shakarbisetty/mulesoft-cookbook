## Azure DevOps Pipelines for MuleSoft
> Azure Pipelines with service connections, variable groups, and multi-stage deploy

### When to Use
- Your organization standardizes on Azure DevOps for CI/CD
- You need variable groups per environment for configuration isolation
- You want approval gates and service connection security boundaries

### Configuration

**azure-pipelines.yml**
```yaml
trigger:
  branches:
    include:
      - main
      - develop
      - release/*

pool:
  vmImage: "ubuntu-latest"

variables:
  - group: mulesoft-common
  - name: mavenOpts
    value: "-Dmaven.repo.local=$(Pipeline.Workspace)/.m2/repository"

stages:
  - stage: Build
    displayName: "Build & Test"
    jobs:
      - job: BuildAndTest
        steps:
          - task: Cache@2
            inputs:
              key: 'maven | "$(Agent.OS)" | pom.xml'
              restoreKeys: |
                maven | "$(Agent.OS)"
              path: $(Pipeline.Workspace)/.m2/repository
            displayName: "Cache Maven"

          - task: Maven@4
            inputs:
              mavenPomFile: "pom.xml"
              goals: "clean package"
              options: "-B"
              javaHomeOption: "JDKVersion"
              jdkVersionOption: "1.17"
            displayName: "Build"

          - task: Maven@4
            inputs:
              mavenPomFile: "pom.xml"
              goals: "test"
              javaHomeOption: "JDKVersion"
              jdkVersionOption: "1.17"
              publishJUnitResults: true
              testResultsFiles: "**/surefire-reports/TEST-*.xml"
            displayName: "MUnit Tests"

          - publish: $(System.DefaultWorkingDirectory)/target
            artifact: mule-artifact
            displayName: "Publish Artifact"

  - stage: DeployDev
    displayName: "Deploy to DEV"
    dependsOn: Build
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/develop'))
    variables:
      - group: mulesoft-dev
    jobs:
      - deployment: DeployDev
        environment: "mulesoft-dev"
        strategy:
          runOnce:
            deploy:
              steps:
                - download: current
                  artifact: mule-artifact
                - task: Maven@4
                  inputs:
                    mavenPomFile: "pom.xml"
                    goals: "mule:deploy"
                    options: >-
                      -B
                      -Dmule.artifact=$(Pipeline.Workspace)/mule-artifact/*.jar
                      -Danypoint.connectedApp.clientId=$(CONNECTED_APP_ID)
                      -Danypoint.connectedApp.clientSecret=$(CONNECTED_APP_SECRET)
                      -Danypoint.connectedApp.grantType=client_credentials
                      -Danypoint.environment=DEV
                      -Dcloudhub2.replicas=1
                      -Dcloudhub2.vCores=0.1
                    javaHomeOption: "JDKVersion"
                    jdkVersionOption: "1.17"
                  displayName: "Deploy to CloudHub 2.0 DEV"

  - stage: DeployProd
    displayName: "Deploy to PROD"
    dependsOn: Build
    condition: and(succeeded(), startsWith(variables['Build.SourceBranch'], 'refs/tags/'))
    variables:
      - group: mulesoft-prod
    jobs:
      - deployment: DeployProd
        environment: "mulesoft-prod"
        strategy:
          runOnce:
            deploy:
              steps:
                - download: current
                  artifact: mule-artifact
                - task: Maven@4
                  inputs:
                    mavenPomFile: "pom.xml"
                    goals: "mule:deploy"
                    options: >-
                      -B
                      -Dmule.artifact=$(Pipeline.Workspace)/mule-artifact/*.jar
                      -Danypoint.connectedApp.clientId=$(CONNECTED_APP_ID)
                      -Danypoint.connectedApp.clientSecret=$(CONNECTED_APP_SECRET)
                      -Danypoint.connectedApp.grantType=client_credentials
                      -Danypoint.environment=PROD
                      -Dcloudhub2.replicas=2
                      -Dcloudhub2.vCores=0.2
                    javaHomeOption: "JDKVersion"
                    jdkVersionOption: "1.17"
                  displayName: "Deploy to CloudHub 2.0 PROD"
```

### How It Works
1. **Variable groups** (`mulesoft-common`, `mulesoft-dev`, `mulesoft-prod`) isolate secrets per environment
2. **Service connections** are not needed for Anypoint — Connected App credentials are stored in variable groups
3. **Deployment jobs** use Azure Environments, enabling approval gates and deployment history
4. The artifact is built once and downloaded in each deploy stage (no rebuild)
5. Conditions on `Build.SourceBranch` control which stages run

### Gotchas
- Mark `CONNECTED_APP_SECRET` as a secret variable in each variable group
- Azure Pipelines caches are scoped per branch by default; the `Cache@2` key includes `pom.xml` hash
- The `deployment` job type requires an Azure Environment to be pre-created
- For YAML-based approvals, configure environment checks in Azure DevOps UI, not in the YAML
- Use `Maven@4` task (not `Maven@3`) for Java 17 support

### Related
- [gitlab-ci](../gitlab-ci/) — GitLab equivalent
- [jenkins](../jenkins/) — Jenkinsfile equivalent
- [secure-properties](../../environments/secure-properties/) — Encrypt sensitive values in Mule config
