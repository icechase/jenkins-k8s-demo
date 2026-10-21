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
    }
}
