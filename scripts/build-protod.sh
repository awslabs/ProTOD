#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

function print_help () {
    echo "Required arguments: --stack, --bucket, --cognito, --dns, --email"
    echo "          --stack <STACK> : Name of the new CloudFormation stack to create"
    echo "          --bucket <BUCKET> : Name of the ProTOD build S3 bucket you created."
    echo "          --cognito <COGNITO> : Name the new Cognito user pool to create (Do not use reserved word 'cognito', use only a-z 0-9 + = , . @ -)."
    echo "          --dns <DNS> : Enter the FQDN for ProTOD. This should match the certificate you created in ACM."
    echo "          --email <EMAIL> : Enter an Amazon email address to receive administrative alerts."
    echo "Optional arguments (one or more is requried): --delete, --build-infra, --build-web, --build-db, --build-tools, --build-all, --enable, --disable"
    echo "          --account <ACCOUNT> : AWS account to deploy ProTOD to."
    echo "          --role <IAMROLE> : IAM role to assume during build."
    echo "          --delete : Delete all components of ProTOD."
    echo "          --enable : Enables Fargate front end, turns on S3 Lambda trigger."
    echo "          --disable : Disables Fargate front end, turns off S3 Lambda trigger, turns off ELB logging."
    echo "          --build-infra : Builds the infrastructure."
    echo "          --build-web : Builds the web frontend."
    echo "          --build-db : Populates the DynamoDB table for the web frontend."
    echo "          --build-source-images : Copy source images to ECR"
    echo "          --build-tools : Builds container images for all ProTOD tools."
    echo "          --build-all : Builds all components of ProTOD."
}

# Set build home directory
HOMEDIR=$(pwd)
export HOMEDIR

# Determine if build is being executed by CodeBuild
if ([  "$CODEBUILD_BUILD_ARN" ]); then
    CODEBUILD_DEPLOY=true
else
    CODEBUILD_DEPLOY=false
fi

# If the script is run with no arguments, print the help
if [[ $# -eq 0 ]]; then
    print_help
    return 80
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        '--stack') STACKNAME=$2 ;;
        '--bucket') BUILDBUCKET=$2 ;;
        '--cognito') COGNITODOMAIN=$2 ;;
        '--dns') FQDN=$2 ;;
        '--email') EMAIL=$2 ;;
        '--account') ACCOUNT=$2 ;;
        '--role') buildrole=$2 ;;
        '--delete') delete=true; disable=true ;;
        '--enable') enable=true ;;
        '--disable') disable=true ;;
        '--build-infra') buildinfra=true ;;
        '--build-web') buildweb=true ;;
        '--build-db') builddb=true ;;
        '--build-tools') buildtools=true ;;
        '--build-source-images') sourceimages=true;;
        '--build-all') buildinfra=true; buildweb=true; enable=true; builddb=true; buildtools=true; sourceimages=true;;
        '--help')
            print_help
            return 80 ;;
    esac
    shift
done

# Ensure AWS CLI is connected.
aws sts get-caller-identity >/dev/null 2>&1
if [[ $? != 0 ]]; then
    echo "<ERROR::build-protod.sh> AWS CLI is not connected. Exiting. . ."
    return 80
fi

## Check for missing flags/arguments
# Check if at least one build flag is defined
if ([ -z "$buildinfra" ] && [ -z "$buildweb" ] && [ -z "$enable" ] && [ -z "$builddb" ] && [ -z "$buildtools" ] && [ -z "$disable" ] && [ -z "$delete" ] && [ -z "$sourceimages" ]); then
    print_help
    return 80
fi

# Determine if arguments are missing, trigger interactive setup if missing
interactive_setup=""
if ([ $delete ]); then
    # Delete flag only requires stackname, check for it
    if ([ -z "$STACKNAME" ] || [ -z $BUILDBUCKET ]); then
        echo "<ERROR::build-protod.sh> --delete flag requires --stack and --bucket arguments to be set. Exiting. . ."
        return 80
    fi
elif ([ $enable ] || [ $disable ] || [ $buildweb ] || [ $buildtools ] || [ $builddb ] || [ $sourceimages ]); then
    # Enable, disable, build-web, build-tools. build-db flags do not require any arguments. Continue
    :
elif ([ -z "$STACKNAME" ] || [ -z "$BUILDBUCKET" ] || [ -z "$COGNITODOMAIN" ] || [ -z "$FQDN" ] || [ -z "$EMAIL" ]); then
        # All other flags require arguments. Trigger interactive setup if any are missing
        echo 'One or more required build variables missing. Proceeding with interactive setup. . .'
        interactive_setup=true
fi

# Interactive setup
if ([ $interactive_setup ]) ; then
    ### These are build variables
    # The name of the CloudFormation stack, i.e. ProTOD, etc.
    echo -n "Name the new CloudFormation stack to create: "
    read STACKNAME

    # An existing bucket or a new one where to save the CloudFormation templates
    # This bucket must be in the same region where you are building ProTOD
    echo -n "Name of the ProTOD build S3 bucket you created: "
    read BUILDBUCKET

    ### These are the ProTOD variables which define ProTOD's AWS resources
    # The name of the Cognito User Pool
    echo -n "Name the new Cognito user pool to create (Do not use reserved word 'cognito', use only a-z 0-9 + = , . @ -): "
    read COGNITODOMAIN

    # The FQDN of the ProTOD URL. This should match the pProTODCertificate
    echo -n "Enter the FQDN for ProTOD. This should match the certificate you created in ACM: "
    read FQDN

    # Administrative email to receive alerts
    echo -n "Enter an Amazon email address to receive administrative alerts "
    read EMAIL

    # Validate each required build variable was defined
    if [ -z "$STACKNAME" ] || [ -z "$BUILDBUCKET" ] || [ -z "$COGNITODOMAIN" ] || [ -z "$FQDN" ] || [ -z "$EMAIL" ]; then
        echo 'One or more required build variables is missing, Setup cannot continue. Exiting. . .'
        return 80
    fi
    buildinfra=true
    buildweb=true
    enable=true
    builddb=true
    buildtools=true
    sourceimages=true
fi

# Normalize, validate user-defined Cognito domain does not contain invalid chars or reserved word(s).
disallowed_cognito_pattern="cognito"
COGNITODOMAIN=$(echo "$COGNITODOMAIN" | awk '{print tolower($0)}')
if [[ "$COGNITODOMAIN" =~ $disallowed_cognito_pattern ]]; then
    echo "Cognito domain may not contain the reserved word 'cognito'. Exiting. . ."
    return 80
fi

# Validate user-defined email is an Amazon address
allowed_email_pattern="^[A-Za-z0-9+]+@amazon\.com$"
if ! [[ "$EMAIL" =~ $allowed_email_pattern ]]; then
    echo "Please enter your amazon email address. Exiting. . ."
    return 80
fi
export STACKNAME
export BUILDBUCKET
export COGNITODOMAIN
export FQDN

# Export the AWS account ID and region to deploy to
# If deploying via CodeBuild, get account ID from environment if available
# Query CLI for account ID in all other scenarios
# Else, query from AWS CLI
if [[ $CODEBUILD_DEPLOY = true ]]; then
    REGION=$AWS_REGION
    if [[ $ACCOUNT ]]; then
        :
    else
        ACCOUNT=$(aws sts get-caller-identity --query 'Account' | tr -d '"')
    fi
else
    REGION=$(aws configure get region)
    ACCOUNT=$(aws sts get-caller-identity --query 'Account' | tr -d '"')
fi

export ACCOUNT
export REGION

# Assume role, if specified
if [[ $buildrole ]]; then
    . ./assume-role.sh --role $buildrole
    if [[ $? != 0 ]]; then
        echo "<ERROR::build-protod.sh> ./scripts/assume-role.sh did not succeed."
        return 80
    fi
fi

# The AWS-owned account ID for the ELB access logs varies per region. This selects the proper account
# Bash 3 hacky hashmap
alb_log_acct_id=( "us-east-1:127311923021" "us-east-2:033677994240" "us-west-1:027434742980" "us-west-2:797873946194" "af-south-1:098369216593" "ap-east-1:754344448648" "ap-southeast-3:589379963580" "ap-south-1:718504428378" "ap-northeast-3:383597477331" "ap-northeast-2:600734575887" "ap-southeast-1:114774131450" "ap-southeast-2:783225319266" "ap-northeast-1:582318560864" "ca-central-1:985666609251" "eu-central-1:054676820928" "eu-west-1:156460612806" "eu-west-2:652711504416" "eu-south-1:635631232127" "eu-west-3:009996457667" "eu-north-1:897822967062" "me-south-1:076674570225" "sa-east-1:507241528517" "us-gov-east-1:190560391635" "us-gov-west-1:048591011584")
for pair in "${alb_log_acct_id[@]}"; do
    KEY="${pair%%:*}"
    VALUE="${pair##*:}"
    if [ "$KEY" = "$REGION" ]; then
       ALBLOGACCOUNT=$VALUE
       export ALBLOGACCOUNT
    fi
done

## Get ARN of ACM certificate matching FQDN
# Get all ACM certificates in the account, then search their SANs for a match to the ProTOD DNS FQDN
all_certs=$(aws acm list-certificates --includes keyTypes=RSA_2048,RSA_3072,RSA_4096,EC_prime256v1,EC_secp384r1,EC_secp521r1 --output text --query 'CertificateSummaryList[].CertificateArn')
num_certs=$(echo $all_certs | wc -w )
matching_certs=()
for (( i=1; i<=$num_certs; i++ )); do
    search=""
    cert_arn=$(echo $all_certs | awk -v i="$i" '{print $i}')
    search=$(aws acm describe-certificate --certificate-arn $cert_arn --output text --query 'Certificate.SubjectAlternativeNames[?starts_with(@, `'$FQDN'`)]')
    if [[ $search ]]
    then
        matching_certs+=$cert_arn
    fi
done

num_matching_certs=$(echo ${#matching_certs[*]})
if [[ $num_matching_certs -eq 1 ]]; then
    # Export certificate ARN f one matching certificate found
    PROTODCERTIFICATE=$matching_certs
    export PROTODCERTIFICATE
elif [[ -z $num_matching_certs || $num_matching_certs -eq 0 ]]; then
    # If no matching certificates found, exit with an error
    echo "<ERROR::build-protod.sh> ACM certificate not found for $FQDN in $REGION (account ID: $ACCOUNT). Exiting. . ."
    return 80
else
    # If multiple matching certificates found, let the user choose the correct ARN
    echo "Multiple ACM certificates found for $FQDN in $REGION (account ID: $ACCOUNT)."
    echo "Select the correct certificate ARN from the list of matching certificates below."
    echo "0: Correct certificate not listed"
    for (( i=1; i<=$num_matching_certs; i++)); do
        echo "$i: ${matching_certs[$i]}"
    done
    printf "%s" "Enter the number corresponding to the correct certificate ARN: "
    read multi_cert_select

    # Validate user input
    if (( $multi_cert_select >= 1 && $multi_cert_select <= $num_matching_certs)); then
        PROTODCERTIFICATE=$matching_certs[$multi_cert_select]
        export PROTODCERTIFICATE
    else
        echo "<ERROR::build-protod.sh> ACM certificate not found for $FQDN in $REGION (account ID: $ACCOUNT). Exiting. . ."
        return 80
    fi
fi

# If build is being executed by CodeBuild, print build variables and proceed to next build step.
# Otherwise, run specified build
if [[ $CODEBUILD_DEPLOY = true ]]; then
    echo "<INFO::build-protod.sh> BUILD VARIABLES"
    echo "<INFO::build-protod.sh> Region: $REGION"
    echo "<INFO::build-protod.sh> AWS Account: $ACCOUNT"
    echo "<INFO::build-protod.sh> S3 Build bucket: $BUILDBUCKET"
    echo "<INFO::build-protod.sh> Cognito domain: $COGNITODOMAIN"
    echo "<INFO::build-protod.sh> ACM certificate ARN: $PROTODCERTIFICATE"
    echo "<INFO::build-protod.sh> FQDN: $FQDN"
    echo "<INFO::build-protod.sh> CloudFormation stack name: $STACKNAME"
    echo "<INFO::build-protod.sh> ALB log account: $ALBLOGACCOUNT"
fi

# Set Fargate desired count to 0, disable S3 Lambda trigger, Inspector & Security Hub
if [[ $disable = true ]]; then
    disable=""
    echo "<INFO::build-protod.sh> Running ./scripts/update-infra.sh --disable"
    . ./update-infra.sh --disable
    if [[ $? = 80 ]]; then
        echo "<ERROR::build-protod.sh> ./scripts/update-infra.sh --disable did not succeed"
        return 80
    fi
fi

# Deletes ProTOD
if [[ $delete = true ]]; then
    delete=""
    echo "<INFO::build-protod.sh> Running ./scripts/delete-protod.sh"
    . ./delete-protod.sh
    if [[ $? = 80 ]]; then
        echo "<ERROR::build-protod.sh> ./scripts/delete-protod.sh did not succeed"
        return 80
    fi
    return 0
fi

# Build ProTOD
# This infrastructure deploys Fargate but does not spin up any services/tasks until dependent resources are created.
if [[ $buildinfra = true ]]; then
    buildinfra=""
    echo "<INFO::build-protod.sh> Running ./scripts/build-infra.sh"
    . ./build-infra.sh
    if [[ $? = 80 ]]; then
        echo "<ERROR::build-protod.sh> ./scripts/build-infra.sh did not succeed"
        return 80
    fi
fi

# Copy source images into ECR
if [[ $sourceimages = true ]]; then
    sourceimages=""
    echo "<INFO::build-protod.sh> Running ./build-containers.sh --build-source-images"
    . ./build-containers.sh --build-source-images
    if [[ $? != 0 ]]; then
        echo "<ERROR::build-protod.sh> ./protod-tools/build-tools.sh did not succeed."
        return 80
    fi
fi

# Builds the taph and redis containers and uploads them to ECR
if [[ $buildweb = true ]]; then
    buildweb=""
    echo "<INFO::build-protod.sh> Running ./build-containers.sh --web"
    . ./build-containers.sh --web
    if [[ $? != 0 ]]; then
        echo "<ERROR::build-protod.sh> ./build-containers.sh --web did not succeed"
        return 80
    fi
fi

# Set Fargate desired count to 1, enable S3 Lambda trigger, set secret values, enable Inspector & Security Hub
if [[ $enable = true ]]; then
    enable=""
    echo "<INFO::build-protod.sh> Running ./scripts/update-infra.sh --enable"
    . ./update-infra.sh --enable
    if [[ $? = 80 ]]; then
        echo "<ERROR::build-protod.sh> ./scripts/update-infra.sh --enable did not succeed"
        return 80
    fi
fi

# Load the DynamoDB Tools table
if [[ $builddb = true ]]; then
    cd ../taph/taph/modules
    builddb=""
    echo "<INFO::build-protod.sh> Populating DynamoDB table"
    python3 ./dbsetup.py --region $REGION
    cd $HOMEDIR
fi

# Build the AWS ECR environment, containers, and uploads them to ECR
if [[ $buildtools = true ]]; then
    buildtools=""
    echo "<INFO::build-protod.sh> Running ./build-containers.sh --all-tools"
    . ./build-containers.sh --all-tools
    if [[ $? != 0 ]]; then
        echo "<ERROR::build-protod.sh> ./protod-tools/build-tools.sh did not succeed."
        return 80
    fi
fi

ALBURL=$(aws cloudformation list-exports --query 'Exports[?Name==`FrontEndALBURL`].Value' --output text)
export ALBURL

echo "-----------------------------------------------------------------"
echo "Your ALB DNS name is $ALBURL"
if [[ $FQDN ]]; then
echo "Update the CNAME of $FQDN with the DNS name of the ALB"
fi
echo ""
echo "Your ALB logging account ID is $ALBLOGACCOUNT"
echo "Your ProTOD ACS certificate ARN is $PROTODCERTIFICATE"
echo "-----------------------------------------------------------------"
