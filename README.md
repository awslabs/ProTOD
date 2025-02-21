# ProTOD

Professional-Tools-On-Demand is a flexible web interface for engagement automation.

Goals

- We focus on automation and on repeatable outcomes
- We use one simple and intuitive interface and do not sacrifice simplicity for the sake of automating everything
- We make it easy to understand the tool used and how the options affect the output

---

## Install ProTOD

### Prerequisites

1. An AWS account. Best if you create a new AWS account dedicated to ProTOD
1. AWS Command Line Interface (AWS CLI v2)
2. Bash version >= 3.
3. Finch from <https://github.com/runfinch/finch> (Replaces Docker Desktop)

### Installation

#### DNS and Certificate Instruction for Amazon Route 53 and Amazon Certificate Manager
1. Create a DNS domain in Route 53
2. Create a certificate in Certificate Manager for the FQDN you'll use with ProTOD.
   1. This certificate should be created in the same region where you'll deploy ProTOD.
   2. You will need to authorize this certificate by creating a CNAME in your delegated DNS namespace.

#### DNS and Certificate Instruction for all other cases
1. Create a DNS domain
2. Create a certificate the FQDN you'll use with ProTOD.

#### Installation Continued ...
3. Create a new S3 bucket in the region where you'll be deploying ProTOD. This will be used during the build process.
4. Download the ProTOD source code
5. From Terminal, start a bash shell by running:
       ```bash```

6. Connect your AWS CLI to your AWS account.
7. Change to the scripts directory
      ```cd scripts```

8. Set the default region of your AWS CLI to the region where you'd like ProTOD to be deployed, for example:
      ```export AWS_DEFAULT_REGION=us-east-1```

9. Install dependencioes
   1. MacOS: run the environment setup script

      ```. ./setup-env.sh```

      *Note: Make sure to copy the entire command. The leading period tells bash to 'source' the script when running*
   2. All others, install the following dependencies:
      - Docker
      - AWS CLI
      - Python
        - pip3
        - pip3 install -r taph/requirements.txt
        - pip3 install virtualenv pytest pytest-cov bandit safety

10. Run the ProTOD build script.
      ```. ./build-protod.sh --stack <STACK NAME> --bucket <BUILD BUCKET NAME> --cognito <COGNITO DOMAIN NAME> --dns <FQDN> --email <EMAIL> --build-all```

      *Note: Make sure to copy the entire command. The leading period tells bash to 'source' the script when running*

   All arguments and at least one flag are required:

      1. (Required) ```--stack``` (Name of CloudFormation stack to create)
      2. (Required) ```--bucket``` (S3 build bucket you created)
      3. (Required) ```--cognito``` (Cognito user pool to create)
      4. (Required) ```--dns``` (ProTOD FQDN, specified in ACM certificate)
      5. (Required) ```--email``` (Email to receive administrative alerts)
      6. ```--build-infra``` : Deploy infrastructure via CloudFormation
      7. ```--build-web``` : Build and push the web frontend
      8. ```--enable``` : Enable S3 Lambda notification, Fargate front end, updates Secrets Manager secret
      9. ```--disable```: Disables S3 Lambda notification, Fargate front end, ELB logging
      10. ```--build-db``` : Populate the DynamoDB table
      11. ```--build-tools``` : Build and push all tool containers
      12. ```--build-all```  : Builds ProTOD in it's entirety

11. Once complete, create a CNAME in your DNS namespace for the FQDN you chose for ProTOD.
   1. The value of the CNAME should be set to the ALB DNS name, provided by the build script.
