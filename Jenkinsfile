pipeline {
    agent {
        label 'jenkins-agent'
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

        
        

        stage('5 - Deploy to Kubernetes') {
            agent {
                kubernetes {
                    cloud 'microk8s'
                    label 'jenkins-deploy-agent'
                    defaultContainer 'jnlp'
                }
            }

            steps {
                echo '=== Deploy image to Kubernetes ==='

                container('kubectl') {
                    script {
                        // 1. 记录部署前的镜像
                        def previousImage = sh(
                            script: '''
                                set -eu
                                kubectl get deployment jenkins-k8s-demo \
                                    -n default \
                                    -o jsonpath='{.spec.template.spec.containers[?(@.name=="nginx")].image}'
                            ''',
                            returnStdout: true
                        ).trim()

                        def newImage = "ghcr.io/icechase/jenkins-k8s-demo:${env.BUILD_NUMBER}"

                        echo "Previous image: ${previousImage}"
                        echo "New image: ${newImage}"

                        try {
                            // 2. 部署、等待发布、验证镜像和 HTTP 页面
                            sh """
                                set -eu

                                CHANGE_CAUSE="Jenkins Build #${env.BUILD_NUMBER} deployed image ${newImage}"

                                echo "=== Record deployment cause ==="
                                kubectl annotate deployment jenkins-k8s-demo \
                                    kubernetes.io/change-cause="\$CHANGE_CAUSE" \
                                    -n default \
                                    --overwrite

                                echo "=== Update Deployment image ==="
                                kubectl set image \
                                    deployment/jenkins-k8s-demo \
                                    nginx="${newImage}" \
                                    -n default

                                echo "=== Wait for rollout ==="
                                kubectl rollout status \
                                    deployment/jenkins-k8s-demo \
                                    -n default \
                                    --timeout=180s

                                echo "=== Verify deployed image ==="
                                ACTUAL_IMAGE=\$(kubectl get deployment jenkins-k8s-demo \
                                    -n default \
                                    -o jsonpath='{.spec.template.spec.containers[?(@.name=="nginx")].image}')

                                echo "Actual image: \$ACTUAL_IMAGE"

                                if [ "\$ACTUAL_IMAGE" != "${newImage}" ]; then
                                    echo "ERROR: Deployed image does not match expected image."
                                    exit 1
                                fi

                                echo "=== HTTP Smoke Test ==="
                                URL="http://jenkins-k8s-temo.default.svc.cluster.local/"
                                HTTP_BODY=\$(curl -fsS --connect-timeout 5 --max-time 15 "\$URL")

                                printf '%s\\n' "\$HTTP_BODY"

                                if ! printf '%s\\n' "\$HTTP_BODY" | grep -q 'Hello from Jenkins CI!'; then
                                    echo "ERROR: Expected page content was not found."
                                    exit 1
                                fi

                                echo "Deployment and HTTP smoke test passed."
                            """

                        } catch (err) {
                            // 3. 发布失败，尝试回滚
                            echo "ERROR: Deployment or smoke test failed."
                            echo "Attempting Kubernetes rollout undo..."

                            try {
                                sh '''
                                    set -eu

                                    echo "=== Roll back Deployment ==="
                                    kubectl rollout undo \
                                        deployment/jenkins-k8s-demo \
                                        -n default

                                    echo "=== Wait for rollback ==="
                                    kubectl rollout status \
                                        deployment/jenkins-k8s-demo \
                                        -n default \
                                        --timeout=180s

                                    echo "=== Check image after rollback ==="
                                    kubectl get deployment jenkins-k8s-demo \
                                        -n default \
                                        -o jsonpath='{.spec.template.spec.containers[?(@.name=="nginx")].image}{"\\n"}'

                                    echo "=== HTTP check after rollback ==="
                                    URL="http://jenkins-k8s-temo.default.svc.cluster.local/"
                                    HTTP_BODY=$(curl -fsS --connect-timeout 5 --max-time 15 "$URL")

                                    printf '%s\\n' "$HTTP_BODY"

                                    if ! printf '%s\\n' "$HTTP_BODY" | grep -q 'Hello from Jenkins CI!'; then
                                        echo "ERROR: Application check after rollback failed."
                                        exit 1
                                    fi
                                '''

                                echo "Rollback completed and HTTP check passed."

                            } catch (rollbackErr) {
                                echo "CRITICAL: Automatic rollback or its verification failed."
                                echo "Rollback error: ${rollbackErr}"
                            }

                            // 4. 即使回滚成功，也保留原始发布失败状态
                            throw err
                        }
                    }
                }
            }
        }



    }
}
