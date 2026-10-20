
pipeline {
    agent {
        label 'jenkins-agent'
    }

    stages {
        stage('Check Image Build Tools') {
            steps {
                sh '''
                    echo "=== OS ==="
                    cat /etc/os-release | head -n 5
        
                    echo "=== Available tools ==="
                    for tool in docker buildctl buildah podman; do
                        if command -v "$tool" >/dev/null 2>&1; then
                            echo "$tool: available"
                            "$tool" --version 2>/dev/null || true
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
                    echo "README content:"
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
    }
}
