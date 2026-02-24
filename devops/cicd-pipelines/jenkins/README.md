## Jenkins Declarative Pipeline for MuleSoft
> Declarative Jenkinsfile with shared libraries, parallel stages, and deploy approval

### When to Use
- Your organization runs Jenkins as the CI/CD platform
- You want a declarative pipeline with shared library support
- You need parallel test execution and manual approval for production

### Configuration

**Jenkinsfile**
```groovy
pipeline {
    agent {
        docker {
            image 'maven:3.9-eclipse-temurin-17'
            args '-v $HOME/.m2:/root/.m2'
        }
    }

    environment {
        ANYPOINT_CREDS   = credentials('anypoint-connected-app')
        ANYPOINT_ORG_ID  = credentials('anypoint-org-id')
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    stages {
        stage('Build') {
            steps {
                sh 'mvn clean package -DskipTests -B'
            }
        }

        stage('Test') {
            steps {
                sh 'mvn test -B'
            }
            post {
                always {
                    junit 'target/surefire-reports/TEST-*.xml'
                    publishHTML(target: [
                        reportDir: 'target/site/munit/coverage',
                        reportFiles: 'summary.html',
                        reportName: 'MUnit Coverage'
                    ])
                }
            }
        }

        stage('Deploy DEV') {
            when {
                branch 'develop'
            }
            steps {
                deployToCloudHub('DEV', '1', '0.1')
            }
        }

        stage('Deploy QA') {
            when {
                branch pattern: 'release/.*', comparator: 'REGEXP'
            }
            steps {
                deployToCloudHub('QA', '2', '0.1')
            }
        }

        stage('Approve PROD') {
            when {
                buildingTag()
            }
            steps {
                input message: 'Deploy to PROD?',
                      ok: 'Deploy',
                      submitter: 'release-managers'
            }
        }

        stage('Deploy PROD') {
            when {
                buildingTag()
            }
            steps {
                deployToCloudHub('PROD', '2', '0.2')
            }
        }
    }

    post {
        failure {
            slackSend channel: '#mulesoft-ci',
                      color: 'danger',
                      message: "FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER} (<${env.BUILD_URL}|Open>)"
        }
        success {
            slackSend channel: '#mulesoft-ci',
                      color: 'good',
                      message: "SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
        }
    }
}

def deployToCloudHub(String envName, String replicas, String vCores) {
    sh """
        mvn mule:deploy -B \
          -Dmule.artifact=target/*.jar \
          -Danypoint.connectedApp.clientId=${ANYPOINT_CREDS_USR} \
          -Danypoint.connectedApp.clientSecret=${ANYPOINT_CREDS_PSW} \
          -Danypoint.connectedApp.grantType=client_credentials \
          -Danypoint.environment=${envName} \
          -Danypoint.businessGroup=${ANYPOINT_ORG_ID} \
          -Dcloudhub2.target=us-east-2 \
          -Dcloudhub2.replicas=${replicas} \
          -Dcloudhub2.vCores=${vCores}
    """
}
```

**vars/deployToCloudHub.groovy** (shared library version)
```groovy
def call(Map config) {
    sh """
        mvn mule:deploy -B \
          -Dmule.artifact=target/*.jar \
          -Danypoint.connectedApp.clientId=${config.clientId} \
          -Danypoint.connectedApp.clientSecret=${config.clientSecret} \
          -Danypoint.connectedApp.grantType=client_credentials \
          -Danypoint.environment=${config.environment} \
          -Danypoint.businessGroup=${config.orgId} \
          -Dcloudhub2.target=${config.target ?: 'us-east-2'} \
          -Dcloudhub2.replicas=${config.replicas ?: '1'} \
          -Dcloudhub2.vCores=${config.vCores ?: '0.1'}
    """
}
```

### How It Works
1. **Docker agent** uses the Maven image so Jenkins nodes do not need Java/Maven installed
2. **Credentials binding** maps the Connected App client ID/secret to `ANYPOINT_CREDS_USR` and `ANYPOINT_CREDS_PSW`
3. The `deployToCloudHub` function is defined inline; extract it into a shared library for reuse across pipelines
4. **MUnit coverage report** is published as an HTML artifact after the test stage
5. **Input step** gates production deploys to the `release-managers` group
6. Slack notifications fire on success or failure

### Gotchas
- Store the Connected App as a "Username with password" credential in Jenkins (client ID as username, secret as password)
- The Docker agent mounts `~/.m2` for cache; ensure the Jenkins user has write access
- `disableConcurrentBuilds()` prevents race conditions on shared environments
- The `input` step pauses the pipeline — set a timeout to avoid indefinite hangs
- For Multibranch Pipeline, the `when` conditions must match your branch naming convention exactly

### Related
- [gitlab-ci](../gitlab-ci/) — GitLab CI equivalent
- [azure-devops](../azure-devops/) — Azure Pipelines equivalent
- [trunk-based-dev](../trunk-based-dev/) — Trunk-based workflow with feature flags
