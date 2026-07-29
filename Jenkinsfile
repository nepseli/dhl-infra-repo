pipeline {
    agent any

    environment {
        TF_VAR_region = "ap-southeast-1"
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/nepseli/dhl-infra-repo.git'
            }
        }

        stage('Terraform Init') {
            steps {
                sh '''
                cd terraform
                terraform init
                '''
            }
        }

        stage('Terraform Plan') {
            steps {
                sh '''
                cd terraform
                terraform plan -out=tfplan
                '''
            }
        }

        stage('Approve Deployment') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    input message: "Apply Terraform changes?"
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                sh '''
                cd terraform
                terraform apply -auto-approve tfplan
                '''
            }
        }
    }

    post {
        always {
            echo "Pipeline completed."
        }
    }
}
