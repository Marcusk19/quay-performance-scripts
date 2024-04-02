pipeline {
  agent any

  environment {
    QUAY_HOST = 'mkok-dev.quaydev.org'
    QUAY_OAUTH_TOKEN = ''
    QUAY_ORG = ''
    ES_HOST = ''
    ES_PORT = ''
    PYTHONUNBUFFERED = ''
    ES_INDEX = ''
    PUSH_PULL_IMAGE = ''
    PUSH_PULL_ES_INDEX = ''
    PUSH_PULL_NUMBERS = ''
    TARGET_HIT_SIZE = ''
    CONCURRENCY = ''
    TEST_NAMESPACE = ''
    TEST_PHASES = 'LOAD,RUN,DELETE'

    JOB_YAML = "quay-performance-scripts/deploy/job.yaml"
    REPO_URL = "https://github.com/Marcusk19/quay-performance-scripts.git"
  }
  stages {
    stage('Clone Repo') {
      steps {
        script {
          git credentialsId: 'jenkins-user-github', url: 'https://github.com/Marcusk19/quay-performance-scripts.git'
            sh "ls -lart ./*"
            sh "git branch -a"
            sh "git checkout pipeline"
        }
      }
    }
    stage('Deploy') {
      steps {
        withKubeConfig([credentialsId: 'kubeconfig-sa']) {
          sh '''
            kubectl apply -f "$JOB_YAML" 
          '''
        }
      }
    }
  }
}
