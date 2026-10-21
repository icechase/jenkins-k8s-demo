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
                    sh '''
                        set -eu

                        echo "=== BuildKit version ==="
                        buildctl --version

                        echo "=== Verify Dockerfile ==="
                        test -f Dockerfile
                        cat Dockerfile

                        echo "=== Prepare output directory ==="
                        mkdir -p output

                        echo "=== Build OCI image ==="
                        buildctl-daemonless.sh build \
                            --progress=plain \
                            --frontend dockerfile.v0 \
                            --local context=. \
                            --local dockerfile=. \
                            --output type=oci,dest=output/jenkins-k8s-demo.tar

                        echo "=== Verify build output ==="
                        test -s output/jenkins-k8s-demo.tar
                        ls -lh output/jenkins-k8s-demo.tar

                        echo "OCI image build succeeded."
                    '''
                }

                archiveArtifacts(
                    artifacts: 'output/jenkins-k8s-demo.tar',
                    fingerprint: true
                )
            }
        }
    }
}
