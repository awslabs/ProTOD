#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

function print_help () {
    echo "Optional arguments: --role"
    echo "          --web : Builds taph and redis containers for the frontend"
    echo "          --all-tools : Builds all tools containers"
    echo "          --build-source-images : Copies source images to ECR"
}

# Set script home directory
scriptdir=$(pwd)

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        '--web') web=true ;;
        '--all-tools') all_tools=true ;;
        '--build-source-images') sourceimages=true ;;
        '--help')
            print_help
            return 80 ;;
    esac
    shift
done

# Assume role, if specified
if [[ $buildrole ]]; then
    . ./assume-role.sh --role "$buildrole"
    if [[ $? != 0 ]]; then
        echo "<ERROR::build-containers.sh> ./scripts/assume-role.sh did not succeed."
        return 80
    fi
fi

# These vars are set by build-protod.sh. If this script is run independently, they must be exported manually
if ! { [ "$REGION" ] && [ "$ACCOUNT" ]; }; then
        echo "<ERROR::build-containers.sh> Export the REGION and ACCOUNT variables"
        return 80
fi

# Set container client
docker_client=$(command -v docker)
finch_client=$(command -v finch)
cpu_vendor=$(sysctl -a machdep.cpu.vendor)
if [[ $finch_client == *"finch"* ]]; then
    if [[ $cpu_vendor == *"GenuineIntel" ]]; then
        client="finch"
    else
        client="finch"
        platform="--platform=amd64"
    fi
fi
if [[ $docker_client = "alias docker=finch" ]]; then
	client="finch"
elif [[ $docker_client == *"docker"* ]]; then
	client="docker"
fi

# Error if no container client defined
if [[ -z $client ]]; then
	echo "<ERROR::build-containers.sh> Could not find local installation of docker or finch"
    return 80
fi

# Get ECR credentials
aws ecr get-login-password --region "$REGION" | $client login --username AWS --password-stdin "$ACCOUNT".dkr.ecr."$REGION".amazonaws.com

# Get the account ID
ACCOUNTID=$(aws sts get-caller-identity --query Account --output text)

# Import external containers
if [[ "$sourceimages" = true ]]; then
    sourceimages=""
    echo "<INFO::build-containers> BUILDING source images"
    external_images=("redis:7-alpine" \
                    "alpine:3.20" \
                    "python:3.11-alpine3.20" \
                    "checkmarx/kics:latest" \
                    "tenable/terrascan:1.19.2" \
                    "ghcr.io/terraform-linters/tflint-bundle:latest" \
                    "aquasec/tfsec:latest")
    for images in "${external_images[@]}"; do
        base_image=$(echo "$images" | cut -d':' -f1)
        product=$(echo "$base_image" | rev | cut -d'/' -f1 | rev)
        tag=$(echo "$images" | cut -d':' -f2)
        echo "product: $product"
        echo "base: $base_image, product: $product, tag: $tag"
        $client pull "$images"
        $client image tag "$base_image":"$tag" "$ACCOUNTID.dkr.ecr.$REGION.amazonaws.com/$product:$tag"
        aws ecr put-image-tag-mutability --repository-name "$product" --image-tag-mutability MUTABLE --region "$REGION" --no-cli-pager
        $client push "$ACCOUNTID.dkr.ecr.$REGION.amazonaws.com/$product:$tag"
        if [ $tag != "latest" ] ; then
            $client image tag "$base_image":"$tag" "$ACCOUNTID.dkr.ecr.$REGION.amazonaws.com/$product:latest"
            $client push "$ACCOUNTID.dkr.ecr.$REGION.amazonaws.com/$product:latest"
        fi
        aws ecr put-image-tag-mutability --repository-name "$product" --image-tag-mutability IMMUTABLE --region "$REGION" --no-cli-pager
    done
fi

# Build all tools
if [[ "$all_tools" = true ]]; then
    all_tools=""
    echo "INFO::build-containers> BUILDING protod-base"
    cd ../protod-tools || { echo "<ERROR::build-containers> Could not find ../protod-tools"; return 80;}
    $client build $platform -t protod-base -f Dockerfile-protod_base --build-arg ACCOUNT="$ACCOUNTID" --build-arg REGION="$REGION" .
    shopt -s nullglob
    files=$(find . -type f -name Dockerfile\* | sort)
    if [[ $files ]]; then
        for file in $files; do
            if [[ $file != "./Dockerfile-protod_base" ]]; then
                dockerfile=$(echo "$file" | cut -d - -f 2)
                echo "<INFO::build-containers> BUILDING $dockerfile"
                $client build $platform -t $dockerfile -f Dockerfile-$dockerfile --build-arg PROTOD_BASE=protod-base --build-arg ACCOUNT="$ACCOUNTID" --build-arg REGION="$REGION" . || exit
                tool_command=$(grep "tool_version=" ./supporting-files/script-$dockerfile.sh | sed -e 's/.*(//g' | sed -e 's/)//g') || exit
                echo -n "<INFO::$dockerfile version: "; $client run --network none --rm --entrypoint /bin/bash $dockerfile -c "${tool_command[@]}" || exit
                echo "<INFO::build-containers> UPLOADING $dockerfile"
                $client tag "$dockerfile":latest "$ACCOUNTID".dkr.ecr."$REGION".amazonaws.com/protod-"$dockerfile":latest || exit
                aws ecr put-image-tag-mutability --repository-name "protod-$dockerfile" --image-tag-mutability MUTABLE --region "$REGION" --no-cli-pager || exit
                $client push "$ACCOUNTID".dkr.ecr."$REGION".amazonaws.com/protod-"$dockerfile":latest || exit
                aws ecr put-image-tag-mutability --repository-name "protod-$dockerfile" --image-tag-mutability IMMUTABLE --region "$REGION" --no-cli-pager || exit
            fi
        done
    fi
    # Adding prowler compliance checks to ../taph/taph/static/checks3.txt
    echo "<INFO::build-containers> Added prowler compliance checks to ../taph/taph/static/checks3.txt"
    $client run --network none --entrypoint prowler prowler aws --list-compliance -b | grep "\- " | sed 's/- //g' > ../taph/taph/static/checks3.txt
    shopt -u nullglob
    cd $scriptdir || { echo "<ERROR::build-containers> Could not find $scriptdir"; return 80;}
fi

# Build taph and redis
if [[ "$web" = true ]]; then
    web=""
    echo "<INFO::build-containers> BUILDING taph"
    cd ../taph || { echo "<ERROR::build-containers> Could not find ../taph"; return 80;}
    $client build $platform -t taph -f Dockerfile-taph --build-arg ACCOUNT="$ACCOUNTID" --build-arg REGION="$REGION" . || exit
    echo -n "<INFO::taph version: "; $client run --network none --rm --entrypoint /bin/sh taph -c "gunicorn --version" || exit
    $client tag taph:latest "$ACCOUNTID".dkr.ecr."$REGION".amazonaws.com/protod-taph:latest || exit
    aws ecr put-image-tag-mutability --repository-name protod-taph --image-tag-mutability MUTABLE --region "$REGION" --no-cli-pager || exit
    $client push "$ACCOUNTID".dkr.ecr."$REGION".amazonaws.com/protod-taph:latest || exit
    aws ecr put-image-tag-mutability --repository-name protod-taph --image-tag-mutability IMMUTABLE --region "$REGION" --no-cli-pager || exit
    echo "<INFO::build-containers> BUILDING redis"
    $client build $platform -t redis -f Dockerfile-redis --build-arg ACCOUNT="$ACCOUNTID" --build-arg REGION="$REGION" . || exit
    echo -n "<INFO::redis version: "; $client run --network none --rm --entrypoint /bin/sh redis -c "redis-server --version" || exit
    $client tag redis:latest "$ACCOUNTID".dkr.ecr."$REGION".amazonaws.com/protod-redis:latest || exit
    aws ecr put-image-tag-mutability --repository-name protod-redis --image-tag-mutability MUTABLE --region "$REGION" --no-cli-pager || exit
    $client push "$ACCOUNTID".dkr.ecr."$REGION".amazonaws.com/protod-redis:latest || exit
    aws ecr put-image-tag-mutability --repository-name protod-redis --image-tag-mutability IMMUTABLE --region "$REGION" --no-cli-pager || exit
    cd $scriptdir || { echo "<ERROR::build-containers> Could not find $scriptdir"; return 80;}
fi

echo "<INFO::build-containers> Container build complete"
