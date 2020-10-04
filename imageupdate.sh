#!/usr/bin/env bash

set -e

# This script helps update an operator deployment in a Deployment config or a
# ClusterServiceVersion config file with the RELATED_IMAGEs env vars from an
# image list file. All the existing RELATED_IMAGE prefixed env vars are removed
# and replaced by the related image env vars in the image list.
#
# Image list format:
# ---
# # imagelist.yaml
# - name: RELATED_IMAGE_MY_APP
#   value: registry.example.com/example/my-app:v0.1.0
# - name: RELATED_IMAGE_SIDECAR
#   value: registry.example.com/example/sidecar:v0.5.0
#
# ---
#
# IMAGE_LIST_FILE - File containing a list of images with env var name.
# TARGET_DEPLOYMENT_NAME - Name of the operator Deployment.
# TARGET_CONTAINER_NAME - Name of the operator container in Deployment.
# TARGET_FILE - The file to be updated with related images. Deployment or a
# 	ClusterServiceVersion config file.
#
# It read the Kind metadata of the target file to identify CSV or Deployment
# config. When the target is a Deployment config, TARGET_DEPLOYMENT_NAME is
# optional.
#
# Example command:
# $ IMAGE_LIST_FILE=image-0.1.0.yaml TARGET_DEPLOYMENT_NAME=my-operator \
# 	TARGET_CONTAINER_NAME=my-operator \
# 	TARGET_FILE=my-operator.v0.1.0.clusterserviceversion.yaml \
# 	imageupdate.sh

RELATED_IMAGE_PREFIX="RELATED_IMAGE"

if [ -z "$IMAGE_LIST_FILE" ]; then
	echo "Error: IMAGE_LIST_FILE must be set"
	exit 1
fi

if [ -z "$TARGET_FILE" ]; then
	echo "Error: TARGET_FILE must be set"
	exit 1
fi

if [ -z "$TARGET_CONTAINER_NAME" ]; then
	echo "Error: TARGET_CONTAINER_NAME must be set"
	exit 1
fi

# Read imagelist length.
TOTAL_IMAGES=$(yq r $IMAGE_LIST_FILE --length)

DEPLOYMENTS_PATH=""

KIND=$(yq r $TARGET_FILE kind)

# If the file is a CSV config, get the Deployment path.
if [ "$KIND" == "ClusterServiceVersion" ]; then
	echo "Target file identified as a ClusterServiceVersion config."

	# TODO: Check the number of deployments before failing. In case of a
	# single deployment, assign it as TARGET_DEPLOYMENT_NAME.
	if [ -z "$TARGET_DEPLOYMENT_NAME" ]; then
		echo "Error: TARGET_DEPLOYMENT_NAME must be set for a CSV file"
		exit 1
	fi

	# Get the target deployment.
	DEPLOYMENTS_PATH="spec.install.spec.deployments"
	deployments=$(yq r $TARGET_FILE $DEPLOYMENTS_PATH --length)
	echo "Found $deployments deployments"
	TARGET_DEPLOYMENT_FOUND=false
	DEPLOYMENT_INDEX=0
	for ((i=0; i<deployments; i++)); do
		dname=$(yq r $TARGET_FILE $DEPLOYMENTS_PATH[$i].name)
		if [ "${dname}" == $TARGET_DEPLOYMENT_NAME ]; then
			DEPLOYMENT_INDEX=$i
			TARGET_DEPLOYMENT_FOUND=true
			echo "Found target deployment $TARGET_DEPLOYMENT_NAME"
			break
		fi
	done

	if [ ! $TARGET_DEPLOYMENT_FOUND ]; then
		echo "Target deployment $TARGET_DEPLOYMENT_NAME not found"
	fi
elif [ "$KIND" == "Deployment" ]; then
	echo "Target file identified as a Deployment config."
else
	echo "Error: Unknown target config file. Must be Deployment or a ClusterServiceVersion config"
	exit 1
fi

# Get the path to containers.
if [ -z $DEPLOYMENTS_PATH ]; then
	CONTAINERS_PATH="spec.template.spec.containers"
else
	CONTAINERS_PATH="$DEPLOYMENTS_PATH[$DEPLOYMENT_INDEX].spec.template.spec.containers"
fi

# Get the target container.
containers=$(yq r $TARGET_FILE $CONTAINERS_PATH --length)
echo "Found $containers containers"
TARGET_CONTAINER_FOUND=false
CONTAINER_INDEX=0
for ((j=0; j<containers; j++)); do
	cname=$(yq r $TARGET_FILE $CONTAINERS_PATH[$j].name)
	if [ "${cname}" == $TARGET_CONTAINER_NAME ]; then
		CONTAINER_INDEX=$j
		TARGET_CONTAINER_FOUND=true
		echo "Found target container $TARGET_CONTAINER_NAME"
		break
	fi
done

if [ ! $TARGET_CONTAINER_FOUND ]; then
	echo "Target container $TARGET_CONTAINER_NAME not found"
	exit 1
fi

# Delete all the env vars with prefix RELATED_IMAGE from the last item in the
# list to avoid index change.
ENVS_PATH="$CONTAINERS_PATH[$CONTAINER_INDEX].env"
envs=$(yq r $TARGET_FILE $ENVS_PATH --length)

# If env vars aren't empty, check for RELATED_IMAGE prefixed env vars.
if [ ! -z $envs ]; then
	for ((k=$(($envs-1)); k>=0; k--)); do
		CURRENT_ENV_PATH="$ENVS_PATH[$k]"
		key=$(yq r $TARGET_FILE $CURRENT_ENV_PATH.name)
		if [[ "${key}" == $RELATED_IMAGE_PREFIX* ]]; then
			echo "$key: RELATED_IMAGE env var prefix found. Delete env var."
			# Delete the env var inline.
			yq d -i $TARGET_FILE $CURRENT_ENV_PATH
		fi
	done
fi

envVarsLeft=$(yq r $TARGET_FILE $ENVS_PATH --length)

# If there are no env vars, set envVarsLeft to 0.
if [ -z $envVarsLeft ]; then
	envVarsLeft=0
fi

# Add all the RELATED_IMAGEs from the image list and write as env vars.
RELATED_IMAGE_INDEX=0
echo "Adding new related images env vars..."
for ((l=$envVarsLeft; l<$(($envVarsLeft+$TOTAL_IMAGES)); l++)); do
	# Read related image at the image index and write to env vars.
	yq w -i $TARGET_FILE $ENVS_PATH[$l].name "$(yq r $IMAGE_LIST_FILE [$RELATED_IMAGE_INDEX].name)"
	yq w -i $TARGET_FILE $ENVS_PATH[$l].value "$(yq r $IMAGE_LIST_FILE [$RELATED_IMAGE_INDEX].value)"
	RELATED_IMAGE_INDEX=$(($RELATED_IMAGE_INDEX+1))
done

echo "All env vars of the target container:"
yq r $TARGET_FILE $ENVS_PATH
