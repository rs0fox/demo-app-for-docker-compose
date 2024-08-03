#!/bin/bash
# set -e
# This script shows how to build the Docker image and push it to a DockerHub repository.

# The argument to this script is the image name. This will be used as the image on the local
# machine and combined with the DockerHub username to form the repository name.
echo "Inside build_and_push.sh file"
DOCKER_IMAGE_NAME=$1
DOCKERHUB_USERNAME=$2

echo "Value of DOCKER_IMAGE_NAME is $DOCKER_IMAGE_NAME"
echo "Value of DOCKERHUB_USERNAME is $DOCKERHUB_USERNAME"

if [ "$DOCKER_IMAGE_NAME" == "" ] || [ "$DOCKERHUB_USERNAME" == "" ]; then
    echo "Usage: $0 <image-name> <dockerhub-username>"
    exit 1
fi

src_dir=$CODEBUILD_SRC_DIR

# Fetch DockerHub credentials from AWS Secrets Manager
echo "Fetching DockerHub credentials from AWS Secrets Manager..."
aws secretsmanager get-secret-value --secret-id dockerhub --query SecretString --output text > dockerhub.json

DOCKERHUB_USERNAME=$(jq -r '.username' dockerhub_credentials.json)
DOCKERHUB_PASSWORD=$(jq -r '.password' dockerhub_credentials.json)

echo "Logging in to DockerHub..."
echo $DOCKERHUB_PASSWORD | docker login --username $DOCKERHUB_USERNAME --password-stdin

# Get the account number associated with the current IAM credentials
account=$(aws sts get-caller-identity --query Account --output text)

if [ $? -ne 0 ]; then
    echo "Failed to get AWS account number."
    exit 255
fi

# Get the region defined in the current configuration (default to us-east-1 if none defined)
region=$AWS_REGION
if [ -z "$region" ]; then
    region="us-east-1"
fi
echo "Region value is: $region"

image_name=$DOCKER_IMAGE_NAME-$CODEBUILD_BUILD_NUMBER

fullname="${DOCKERHUB_USERNAME}/${DOCKER_IMAGE_NAME}:$image_name"
echo "fullname is $fullname"

# Change to the directory containing the Dockerfile
echo "Changing directory to ${CODEBUILD_SRC_DIR}/application/frontend"
cd ${CODEBUILD_SRC_DIR}/application/frontend || { echo "Failed to change directory to ${CODEBUILD_SRC_DIR}/application/frontend"; exit 1; }

# List files to verify Dockerfile is present
echo "Listing files in ${CODEBUILD_SRC_DIR}/application/frontend:"
ls -l

docker buildx create --name mybuilder --use
docker buildx inspect --bootstrap

docker buildx build --platform linux/amd64 -t ${fullname} .

echo "Docker build completed"
docker images

echo "Docker Push in Progress"
docker buildx build --platform linux/amd64,linux/arm64 --tag ${fullname} --push .
echo "Docker Push is Done"

if [ $? -ne 0 ]; then
    echo "Docker Push Event did not Succeed with Image ${fullname}"
    exit 1
else
    echo "Docker Push Event is Successful with Image ${fullname}"
fi
