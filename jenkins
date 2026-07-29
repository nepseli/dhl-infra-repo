pipeline {
    agent any

    parameters {
        choice(
            name: 'AWS_REGION', 
            choices: ['us-east-1', 'us-west-2', 'eu-west-1', 'ap-south-1'], 
            description: 'Select target AWS Region'
        )
        string(
            name: 'AMI_ID', 
            defaultValue: 'ami-0c7217cdde317cfec', 
            description: 'Provide a valid AMI ID matching your chosen region'
        )
        choice(
            name: 'SERVER_TYPE', 
            choices: ['t2.micro', 't3.micro', 't2.small', 't3.medium'], 
            description: 'Select the hardware sizing'
        )
    }

    environment {
        AWS_CRED = credentials('aws-creds')
    }

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
                    // Initializes backend S3 storage and locking configurations
                    sh 'terraform init'
                }
            }
        }

        stage('Terraform Plan & Approve') {
            steps {
                dir('terraform') {
                    // Generates execution plan and saves it as a secure static artifact
                    sh """
                        terraform plan \
                        -var="aws_region=${params.AWS_REGION}" \
                        -var="ami_id=${params.AMI_ID}" \
                        -var="server_type=${params.SERVER_TYPE}" \
                        -out=tfplan
                    """
                }
                
                // Pauses execution and places a 15-minute lock threshold
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
                    // Instantiates the server and releases the DynamoDB lock
                    sh 'terraform apply tfplan'
                }
            }
        }
    }
    
    post {
        aborted {
            echo "Pipeline aborted or timed out. State lock has been safely released."
        }
    }
}
