pipeline {
  agent any

  environment {
    QUAY_HOST = 'mkok-dev.quaydev.org'
    QUAY_OAUTH_TOKEN = ${QUAY_OAUTH}
    QUAY_ORG = 'performance-test'
    ES_HOST = 'mkok-dev-quay-es-elastic-system.apps.quaydev-rosa.cv2k.p1.openshiftapps.com 
'
    ES_PORT = '80'
    PYTHONUNBUFFERED = ''
    ES_INDEX = 'quay'
    PUSH_PULL_IMAGE = 'quay.io/marckok/quay'
    PUSH_PULL_ES_INDEX = 'quay_push_pull'
    PUSH_PULL_NUMBERS = '10'
    TARGET_HIT_SIZE = '1000'
    CONCURRENCY = '10'
    TEST_NAMESPACE = 'performance-test'
    TEST_PHASES = 'LOAD,RUN,DELETE'

    JOB_YAML = "${WORKSPACE}/deploy/job.yaml"
    REPO_URL = "https://github.com/Marcusk19/quay-performance-scripts.git"
  }
  stages {
    stage('Clone Repo') {
      steps {
        script {
          git credentialsId: 'jenkins-user-github', url: 'https://github.com/Marcusk19/quay-performance-scripts.git'
            sh "git branch -a"
            sh "git checkout pipeline"
            sh "ls -lart ./*"
            sh "pwd"
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
