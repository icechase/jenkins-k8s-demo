
pipeline {
    agent {
        label 'jenkins-agent'
    }

    stages {
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
