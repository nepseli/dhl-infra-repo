pipeline {
    agent any

    parameters {
        choice(
            name: 'INSTANCE_TYPE',
            choices: ['t3.medium', 't3.small', 't3.large'],
            description: 'EC2 instance type for the Jenkins controller (region is fixed to ap-southeast-1; see ADR-0001)'
        )
    }

    // No AWS credentials block: the Jenkins controller runs on an EC2
    // instance with an IAM instance role (see terraform/iam.tf) that grants
    // exactly the permissions these stages need. The AWS SDK/Terraform pick
    // this up automatically - nothing to configure in Jenkins credentials.

    stages {
        stage('Checkout') {
            steps {
                cleanWs()
                checkout scm
            }
        }

        stage('Terraform Init') {
            steps {
                dir('terraform') {
                    // Uses the S3 backend in backend.tf (bootstrap/ must be
                    // applied once beforehand - see aws-console-setup-checklist.md).
                    sh 'terraform init -input=false'
                }
            }
        }

        stage('Terraform Plan & Approve') {
            steps {
                dir('terraform') {
                    sh """
                        terraform plan \
                        -var="instance_type=${params.INSTANCE_TYPE}" \
                        -out=tfplan
                    """
                }

                timeout(time: 15, unit: 'MINUTES') {
                    script {
                        input message: "Review the plan output above. Do you want to apply these infrastructure changes?",
                              ok: "Approve & Deploy"
                    }
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                dir('terraform') {
                    sh 'terraform apply -input=false tfplan'
                }
            }
        }
    }

    post {
        aborted {
            echo "Pipeline aborted or timed out. The DynamoDB lock is released automatically when the terraform process exits."
        }
    }
}
