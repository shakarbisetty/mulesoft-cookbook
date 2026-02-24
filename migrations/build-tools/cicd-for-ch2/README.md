## Update CI/CD Pipelines for CloudHub 2.0
> Migrate CI/CD pipelines from CloudHub 1.0 to CloudHub 2.0 deployment targets

### When to Use
- Moving deployments from CloudHub 1.0 to CloudHub 2.0
- Setting up new CI/CD for Mule applications
- Need GitHub Actions, Jenkins, or GitLab CI for Mule deployments

### Configuration / Code

#### 1. GitHub Actions Pipeline

```yaml
name: Deploy to CloudHub 2.0
on:
  push:
    branches: [main]

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17
          cache: maven

      - name: Configure Maven
        run: |
          mkdir -p ~/.m2
          cat > ~/.m2/settings.xml << EOF
          <settings>
            <servers>
              <server>
                <id>anypoint-exchange-v3</id>
                <username>~~~Client~~~</username>
                <password>${AP_CLIENT_ID}~?~${AP_CLIENT_SECRET}</password>
              </server>
            </servers>
          </settings>
          EOF
        env:
          AP_CLIENT_ID: ${{ secrets.AP_CLIENT_ID }}
          AP_CLIENT_SECRET: ${{ secrets.AP_CLIENT_SECRET }}

      - name: Build and Test
        run: mvn clean test

      - name: Deploy to CloudHub 2.0
        run: mvn deploy -DmuleDeploy -Pcloudhub2
        env:
          AP_CLIENT_ID: ${{ secrets.AP_CLIENT_ID }}
          AP_CLIENT_SECRET: ${{ secrets.AP_CLIENT_SECRET }}
          SECURE_KEY: ${{ secrets.SECURE_KEY }}
```

#### 2. Jenkins Pipeline

```groovy
pipeline {
    agent any
    tools {
        maven 'Maven-3.9'
        jdk 'JDK-17'
    }
    environment {
        AP_CLIENT_ID = credentials('anypoint-client-id')
        AP_CLIENT_SECRET = credentials('anypoint-client-secret')
        SECURE_KEY = credentials('mule-secure-key')
    }
    stages {
        stage('Build') {
            steps {
                sh 'mvn clean package -DskipTests'
            }
        }
        stage('Test') {
            steps {
                sh 'mvn test'
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }
        stage('Deploy') {
            when {
                branch 'main'
            }
            steps {
                sh 'mvn deploy -DmuleDeploy -Pcloudhub2'
            }
        }
    }
}
```

#### 3. Maven Deployment Profile

```xml
<profile>
    <id>cloudhub2</id>
    <build>
        <plugins>
            <plugin>
                <groupId>org.mule.tools.maven</groupId>
                <artifactId>mule-maven-plugin</artifactId>
                <version>4.2.0</version>
                <configuration>
                    <cloudhub2Deployment>
                        <uri>https://anypoint.mulesoft.com</uri>
                        <muleVersion>4.6.0</muleVersion>
                        <target>Shared Space</target>
                        <provider>MC</provider>
                        <environment>Production</environment>
                        <replicas>2</replicas>
                        <vCores>0.5</vCores>
                        <applicationName>${project.artifactId}</applicationName>
                        <connectedAppClientId>${AP_CLIENT_ID}</connectedAppClientId>
                        <connectedAppClientSecret>${AP_CLIENT_SECRET}</connectedAppClientSecret>
                        <connectedAppGrantType>client_credentials</connectedAppGrantType>
                        <properties>
                            <secure.key>${SECURE_KEY}</secure.key>
                        </properties>
                    </cloudhub2Deployment>
                </configuration>
            </plugin>
        </plugins>
    </build>
</profile>
```

### How It Works
1. CI/CD pipeline builds, tests, and deploys Mule applications
2. Connected App credentials authenticate with Anypoint Platform
3. Maven plugin 4.x handles CloudHub 2.0 deployment
4. Secure properties key is injected at deploy time

### Migration Checklist
- [ ] Create Connected App with deployment scopes
- [ ] Store credentials in CI/CD secret manager
- [ ] Update Maven plugin to 4.x
- [ ] Add `cloudhub2Deployment` profile
- [ ] Update pipeline scripts (GitHub Actions, Jenkins, etc.)
- [ ] Test deployment to staging environment
- [ ] Configure environment-specific variables
- [ ] Set up deployment approvals for production

### Gotchas
- Connected App needs `Runtime Manager > Manage Applications` scope
- Maven settings.xml must have Exchange credentials for dependency resolution
- JDK version in CI must match target runtime requirements
- Deployment verification may take time; add polling/wait steps
- Parallel deployments to same target may conflict

### Related
- [maven-plugin-3x-to-4x](../maven-plugin-3x-to-4x/) - Maven plugin upgrade
- [ch1-app-to-ch2](../../cloudhub/ch1-app-to-ch2/) - CloudHub migration
- [platform-permissions](../../security/platform-permissions/) - Connected Apps
