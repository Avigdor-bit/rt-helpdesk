pipeline {
    agent {
        label 'helpdesk-build'
    }

    options {
        timestamps()
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
        timeout(time: 45, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '15'))
    }

    environment {
        AWS_REGION = 'il-central-1'
        ECR_REGISTRY = '391924456595.dkr.ecr.il-central-1.amazonaws.com'
        IMAGE_REPOSITORY = '391924456595.dkr.ecr.il-central-1.amazonaws.com/rt-helpdesk'
        COMPOSE_PROJECT_NAME = "rt-ci-${BUILD_NUMBER}"
    }

    stages {
        stage('Checkout trusted main') {
            steps {
                checkout scm

                sh '''
                    set -eu
                    git fetch origin main
                    test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)"
                '''

                script {
                    env.RELEASE_SHA = sh(
                        script: 'git rev-parse HEAD',
                        returnStdout: true
                    ).trim()
                }
            }
        }

        stage('Run integration tests') {
            steps {
                sh '''
                    set -eu

                    # This workspace is isolated from the persistent application.
                    # setup_env.py is allowed here only when .env is absent.
                    test -f .env || python3 scripts/setup_env.py

                    cleanup_test_db() {
                        docker compose --profile test stop test-db >/dev/null 2>&1 || true
                        docker compose --profile test rm -f test-db >/dev/null 2>&1 || true
                    }

                    trap cleanup_test_db EXIT

                    docker compose --profile test run --build --rm tests
                '''
            }
        }

        stage('Build runtime image') {
            steps {
                sh '''
                    set -eu

                    docker build \
                        --target runtime \
                        --build-arg APP_VERSION="$RELEASE_SHA" \
                        -t "$IMAGE_REPOSITORY:$RELEASE_SHA" .
                '''
            }
        }

        stage('Publish image to ECR') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'rt-helpdesk-ecr-publisher',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    )
                ]) {
                    sh '''
                        set +x
                        set -eu

                        unset AWS_SESSION_TOKEN
                        unset AWS_PROFILE
                        unset AWS_DEFAULT_PROFILE
                        unset AWS_ENDPOINT_URL
                        unset AWS_ENDPOINT_URL_STS
                        unset AWS_ENDPOINT_URL_ECR

                        export AWS_DEFAULT_REGION="$AWS_REGION"
                        export AWS_PAGER=""

                        DOCKER_CONFIG="$(mktemp -d)"
                        chmod 700 "$DOCKER_CONFIG"
                        export DOCKER_CONFIG

                        cleanup_registry_credentials() {
                            docker logout "$ECR_REGISTRY" >/dev/null 2>&1 || true
                            rm -rf "$DOCKER_CONFIG"
                        }

                        trap cleanup_registry_credentials EXIT

                        echo "Authenticating to Amazon ECR..."

                        aws ecr get-login-password \
                            --region "$AWS_REGION" |
                            docker login \
                                --username AWS \
                                --password-stdin "$ECR_REGISTRY"

                        echo "Pushing commit-tagged image..."

                        docker push "$IMAGE_REPOSITORY:$RELEASE_SHA"

                        echo "Recording published image digest..."

                        docker image inspect \
                            --format '{{index .RepoDigests 0}}' \
                            "$IMAGE_REPOSITORY:$RELEASE_SHA" \
                            > release-image.txt

                        test -s release-image.txt
                    '''
                }

                script {
                    env.RELEASE_IMAGE = readFile('release-image.txt').trim()

                    if (!(env.RELEASE_IMAGE ==~ /.+@sha256:[0-9a-f]{64}/)) {
                        error('Published image reference is not digest-pinned.')
                    }
                }

                archiveArtifacts(
                    artifacts: 'release-image.txt',
                    fingerprint: true
                )
            }
        }

        stage('Deploy to application host') {
            steps {
                input(
                    message: "Deploy ${env.RELEASE_IMAGE} to the helpdesk application?",
                    ok: 'Deploy'
                )

                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'rt-helpdesk-deploy-ssh',
                        keyFileVariable: 'DEPLOY_SSH_KEY',
                        usernameVariable: 'DEPLOY_SSH_USER'
                    )
                ]) {
                    sh '''
                        set +x
                        set -eu

                        test "$DEPLOY_SSH_USER" = "deploy"
                        test -f reference/scripts/release.sh

                        printf '%s\n' "$RELEASE_SHA" |
                            grep -Eq '^[a-f0-9]{40}$'

                        printf '%s\n' "$RELEASE_IMAGE" |
                            grep -Eq '^391924456595[.]dkr[.]ecr[.]il-central-1[.]amazonaws[.]com/rt-helpdesk@sha256:[a-f0-9]{64}$'

                        echo "Deploying verified image to application host..."

                        ssh \
                            -i "$DEPLOY_SSH_KEY" \
                            -o IdentitiesOnly=yes \
                            -o BatchMode=yes \
                            -o StrictHostKeyChecking=yes \
                            -o UserKnownHostsFile=/home/buildagent/.ssh/known_hosts \
                            -o ConnectTimeout=10 \
                            "$DEPLOY_SSH_USER@10.0.1.138" \
                            "bash -s -- helpdesk '$RELEASE_IMAGE' '$RELEASE_SHA'" \
                            < reference/scripts/release.sh
                    '''
                }
            }
        }
    }

    post {
        always {
            sh 'docker compose --profile test down --volumes --remove-orphans || true'
            deleteDir()
        }
    }
}
