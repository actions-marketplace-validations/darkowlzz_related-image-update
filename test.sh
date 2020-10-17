#!/usr/bin/env bash

set -e

SRC_CSV_NO_ENV_VARS="testdata/bundle-no-env-vars/manifests/memcached-operator.clusterserviceversion.yaml"
SRC_CSV_WITH_ENV_VARS="testdata/bundle-existing-env-vars/manifests/memcached-operator.clusterserviceversion.yaml"
SRC_CSV_WITH_MULTI_DEPLOYMENTS="testdata/bundle-multiple-deployments/manifests/memcached-operator.clusterserviceversion.yaml"
TEST_CSV="testdata/csv.yaml"

SRC_DEPLOYMENT_NO_ENV_VARS="testdata/config-no-env-vars/manager/manager.yaml"
SRC_DEPLOYMENT_WITH_ENV_VARS="testdata/config-existing-env-vars/manager/manager.yaml"
TEST_DEPLOYMENT="testdata/deployment.yaml"

TEST_IMAGE_LIST="testdata/imagelist-0.2.0.yaml"
OPERATOR_IMAGE_NAME="registry.example.com/example/operator:v1.0.0"

# Helper for printing error.
echoerr() {
	printf "ERROR: %s\n" "$*" >&2;
	exit 1
}

# $1 - actual number of env vars
# $2 - expected number of env vars
check_env_vars_count () {
	if [ $1 -ne $2 ]; then
		echoerr "expected $2 env vars to exists, got $1"
	fi
}

# $1 - target file that's updated.
# $2 - operator image.
check_operator_image () {
	if ! grep $2 $1 ; then
		echoerr "expected $1 to contain \"$2\""
	fi
}

test_csv_update_no_env_vars () {
	echo "== Test if image update works in a CSV config with no env vars"

	cp $SRC_CSV_NO_ENV_VARS $TEST_CSV

	export IMAGE_LIST_FILE=$TEST_IMAGE_LIST
	export TARGET_FILE=$TEST_CSV
	export TARGET_DEPLOYMENT_NAME=memcached-operator-controller-manager
	export TARGET_CONTAINER_NAME=manager

	./imageupdate.sh

	WANT_OPERATOR_IMAGE=$OPERATOR_IMAGE_NAME
	WANT_ENV_VARS=4
	envVarsCount=$(yq r $TARGET_FILE spec.install.spec.deployments[0].spec.template.spec.containers[0].env --length)

	check_env_vars_count $envVarsCount $WANT_ENV_VARS
	check_operator_image $TARGET_FILE $WANT_OPERATOR_IMAGE

	# Cleanup.
	rm $TEST_CSV
}

test_csv_update_with_env_vars () {
	echo "== Test if image update works in a CSV config with env vars"

	cp $SRC_CSV_WITH_ENV_VARS $TEST_CSV

	export IMAGE_LIST_FILE=$TEST_IMAGE_LIST
	export TARGET_FILE=$TEST_CSV
	export TARGET_DEPLOYMENT_NAME=memcached-operator-controller-manager
	export TARGET_CONTAINER_NAME=manager

	./imageupdate.sh

	WANT_OPERATOR_IMAGE=$OPERATOR_IMAGE_NAME
	WANT_ENV_VARS=6
	envVarsCount=$(yq r $TARGET_FILE spec.install.spec.deployments[0].spec.template.spec.containers[0].env --length)

	check_env_vars_count $envVarsCount $WANT_ENV_VARS
	check_operator_image $TARGET_FILE $WANT_OPERATOR_IMAGE

	# Cleanup.
	rm $TEST_CSV
}

test_csv_update_with_multiple_deployments () {
	echo "== Test if image update works in a CSV config with multiple deployments"

	cp $SRC_CSV_WITH_MULTI_DEPLOYMENTS $TEST_CSV

	export IMAGE_LIST_FILE=$TEST_IMAGE_LIST
	export TARGET_FILE=$TEST_CSV
	export TARGET_DEPLOYMENT_NAME=memcached-operator-controller-manager
	export TARGET_CONTAINER_NAME=manager

	./imageupdate.sh

	WANT_OPERATOR_IMAGE=$OPERATOR_IMAGE_NAME
	WANT_ENV_VARS=6
	envVarsCount=$(yq r $TARGET_FILE spec.install.spec.deployments[0].spec.template.spec.containers[0].env --length)

	check_env_vars_count $envVarsCount $WANT_ENV_VARS
	check_operator_image $TARGET_FILE $WANT_OPERATOR_IMAGE

	# Cleanup.
	rm $TEST_CSV
}

test_deployment_update_no_env_vars () {
	echo "== Test if image update works in a Deployment config with no env vars"

	cp $SRC_DEPLOYMENT_NO_ENV_VARS $TEST_DEPLOYMENT

	export IMAGE_LIST_FILE=$TEST_IMAGE_LIST
	export TARGET_FILE=$TEST_DEPLOYMENT
	export TARGET_DEPLOYMENT_NAME=controller-manager
	export TARGET_CONTAINER_NAME=manager

	./imageupdate.sh

	WANT_OPERATOR_IMAGE=$OPERATOR_IMAGE_NAME
	WANT_ENV_VARS=4
	envVarsCount=$(yq r $TARGET_FILE spec.template.spec.containers[0].env --length)

	check_env_vars_count $envVarsCount $WANT_ENV_VARS
	check_operator_image $TARGET_FILE $WANT_OPERATOR_IMAGE

	# Cleanup.
	rm $TEST_DEPLOYMENT
}

test_deployment_update_with_env_vars () {
	echo "== Test if image update works in a Deployment config with env vars"

	cp $SRC_DEPLOYMENT_WITH_ENV_VARS $TEST_DEPLOYMENT

	export IMAGE_LIST_FILE=$TEST_IMAGE_LIST
	export TARGET_FILE=$TEST_DEPLOYMENT
	export TARGET_DEPLOYMENT_NAME=controller-manager
	export TARGET_CONTAINER_NAME=manager

	./imageupdate.sh

	WANT_OPERATOR_IMAGE=$OPERATOR_IMAGE_NAME
	WANT_ENV_VARS=6
	envVarsCount=$(yq r $TARGET_FILE spec.template.spec.containers[0].env --length)

	check_env_vars_count $envVarsCount $WANT_ENV_VARS
	check_operator_image $TARGET_FILE $WANT_OPERATOR_IMAGE

	# Cleanup.
	rm $TEST_DEPLOYMENT
}

# Install yq.
make yq
sudo cp bin/yq /usr/local/bin

# Run tests.
test_csv_update_no_env_vars
test_csv_update_with_env_vars
test_csv_update_with_multiple_deployments
test_deployment_update_no_env_vars
test_deployment_update_with_env_vars
