pipeline {
    agent {
        label 'jenkins-agent'
    }

    options {
        disableConcurrentBuilds()
    }

    stages {
        stage('Check Image Build Tools') {
            steps {
                sh '''
                    echo "=== Available tools on normal agent ==="
                    for tool in docker buildctl buildah podman; do
                        if command -v "$tool" >/dev/null 2>&1; then
                            echo "$tool: available"
                        else
                            echo "$tool: not installed"
                        fi
                    done

                    echo "=== BuildKit socket check ==="
                    if [ -S /run/buildkit/buildkitd.sock ]; then
                        echo "BuildKit socket found"
                    else
                        echo "BuildKit socket not found"
                    fi
                '''
            }
        }

        stage('1 - Checkout Verification') {
            steps {
                echo '=== Git Checkout Verification ==='

                sh '''
                    echo "Current directory:"
                    pwd

                    echo "Git version:"
                    git --version

                    echo "Repository files:"
                    ls -la

                    echo "Git remote:"
                    git remote -v

                    echo "Current commit:"
                    git log -1 --oneline
                '''
            }
        }

        stage('2 - Read Repository') {
            steps {
                echo '=== Read README ==='

                sh '''
                    cat README.md
                '''
            }
        }

        stage('3 - Build Result') {
            steps {
                sh '''
                    mkdir -p output
                    echo "Git checkout succeeded!" > output/result.txt
                    echo "Repository: jenkins-k8s-demo" >> output/result.txt
                    echo "Build number: $BUILD_NUMBER" >> output/result.txt

                    cat output/result.txt
                '''

                archiveArtifacts(
                    artifacts: 'output/result.txt',
                    fingerprint: true
                )
            }
        }

        stage('4 - Build OCI Image') {
            agent {
                kubernetes {
                    cloud 'microk8s'
                    label 'jenkins-buildkit-agent'
                    defaultContainer 'jnlp'
                }
            }

            steps {
                echo '=== Checkout source on BuildKit agent ==='

                checkout scm

                echo '=== Build OCI image with BuildKit ==='

                
                container('buildkit') {
                    withCredentials([
                        usernamePassword(
                            credentialsId: 'ghcr-push-credentials',
                            usernameVariable: 'GHCR_USER',
                            passwordVariable: 'GHCR_TOKEN'
                        )
                    ]) {
                        sh '''
                            set +x
                            set -eu
                
                            # Create a temporary Docker authentication directory
                            export DOCKER_CONFIG="$(mktemp -d)"
                            trap 'rm -rf "$DOCKER_CONFIG"' EXIT
                
                            # Create GHCR authentication data without printing the token
                            AUTH="$(printf '%s' "$GHCR_USER:$GHCR_TOKEN" \
                                | base64 | tr -d '\\n')"
                
                            printf '{"auths":{"ghcr.io":{"auth":"%s"}}}\\n' \
                                "$AUTH" > "$DOCKER_CONFIG/config.json"
                
                            chmod 600 "$DOCKER_CONFIG/config.json"
                
                            # Verify BuildKit is available
                            buildctl --version
                            test -f Dockerfile
                
                            # Build the image and push it to GHCR
                            buildctl-daemonless.sh build \
                                --progress=plain \
                                --frontend dockerfile.v0 \
                                --local context=. \
                                --local dockerfile=. \
                                --output "type=image,name=ghcr.io/icechase/jenkins-k8s-demo:${BUILD_NUMBER},push=true"
                
                            echo "GHCR push command completed successfully."
                        '''
                    }
                }


            }
        }

        
stage('Deploy to Kubernetes') {
    agent {
        label 'jenkins-deploy-agent'
    }

    steps {
        lock(resource: 'jenkins-k8s-demo-deploy') {
            echo "Acquired deployment lock: jenkins-k8s-demo-deploy"

            container('kubectl') {
                script {
                    def previousImage = sh(
                        script: '''
                            kubectl get deployment jenkins-k8s-demo \
                              -n default \
                              -o jsonpath='{.spec.template.spec.containers[?(@.name=="nginx")].image}'
                        ''',
                        returnStdout: true
                    ).trim()

                    if (!previousImage) {
                        error('Cannot determine previous image; aborting deployment')
                    }

                    def newImage =
                        "ghcr.io/icechase/jenkins-k8s-demo:${env.BUILD_NUMBER}"

                    echo "Previous image: ${previousImage}"
                    echo "New image: ${newImage}"

                    try {
                        sh """
                            set -eu

                            kubectl annotate deployment jenkins-k8s-demo \
                              -n default \
                              kubernetes.io/change-cause="Jenkins Build #${env.BUILD_NUMBER} deploying ${newImage}" \
                              --overwrite

                            kubectl set image deployment/jenkins-k8s-demo \
                              -n default nginx=${newImage}

                            kubectl rollout status deployment/jenkins-k8s-demo \
                              -n default --timeout=180s

                            ACTUAL_IMAGE=\$(kubectl get deployment jenkins-k8s-demo \
                              -n default \
                              -o jsonpath='{.spec.template.spec.containers[?(@.name=="nginx")].image}')

                            echo "Actual image: \$ACTUAL_IMAGE"

                            test "\$ACTUAL_IMAGE" = "${newImage}"

                            echo "=== HTTP Smoke Test ==="
                            curl -fsS --connect-timeout 5 --max-time 15 \
                              http://jenkins-k8s-temo.default.svc.cluster.local/ \
                              -o /tmp/smoke-body.txt

                            grep -F 'Hello from Jenkins CI!' /tmp/smoke-body.txt
                        """
                    } catch (err) {
                        echo "Deployment or smoke test failed: ${err.message}"
                        echo "Restoring previous image: ${previousImage}"

                        try {
                            sh """
                                set -eu

                                kubectl set image deployment/jenkins-k8s-demo \
                                  -n default nginx=${previousImage}

                                kubectl rollout status deployment/jenkins-k8s-demo \
                                  -n default --timeout=180s

                                ACTUAL_IMAGE=\$(kubectl get deployment jenkins-k8s-demo \
                                  -n default \
                                  -o jsonpath='{.spec.template.spec.containers[?(@.name=="nginx")].image}')

                                echo "Image after rollback: \$ACTUAL_IMAGE"
                                test "\$ACTUAL_IMAGE" = "${previousImage}"

                                echo "=== HTTP Smoke Test After Rollback ==="
                                curl -fsS --connect-timeout 5 --max-time 15 \
                                  http://jenkins-k8s-temo.default.svc.cluster.local/ \
                                  -o /tmp/rollback-body.txt

                                grep -F 'Hello from Jenkins CI!' /tmp/rollback-body.txt
                            """
                        } catch (rollbackErr) {
                            echo "CRITICAL: Rollback or post-rollback verification failed: ${rollbackErr.message}"
                        }

                        throw err
                    }
                }
            }
        }
    }
}



        




    }
}
