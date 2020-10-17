# related-image-update

[![Test](https://github.com/darkowlzz/related-image-update/workflows/Test/badge.svg)](https://github.com/darkowlzz/related-image-update/actions?query=workflow%3ATest)
[![Action in workflow](https://github.com/darkowlzz/related-image-update/workflows/Action%20in%20workflow/badge.svg)](https://github.com/darkowlzz/related-image-update/actions?query=workflow%3A%22Action+in+workflow%22)

Github Action to update kubernetes operator Deployment and
[OLM](olm.operatorframework.io/) ClusterServiceVersion configs with
RELATED_IMAGEs.

In a kubernetes operators, when the operator configures some resource with a
container image, the default values of the container images can be set in the
operator using environment variables. These environment variables are generally
prefixed with `RELATED_IMAGE`, like `RELATED_IMAGE_SIDECAR`. This is used by
some operator providers to overwrite the images with correct image reference
when installing in isolated environments with its own container image registry.

related-image-update can be used to automatically update the `RELATED_IMAGE`
env vars in operator Deployment and ClusterServiceVersion configs. Given an
image list containing the environment variable name and image name, a target
deployment name and a target container name, it can populate the environment
variables as per the image list. It removes any previous `RELATED_IMAGE`
prefixed env vars. They can be moved into the image list file.

An example image list file:

```yaml
# imagelist.yaml
- name: RELATED_IMAGE_MY_APP
  value: registry.example.com/example/my-app:v0.2.0
- name: RELATED_IMAGE_SIDECAR
  value: registry.example.com/example/sidecar:v0.2.0
- name: RELATED_IMAGE_HELPER_X
  value: registry.example.com/example/helper-x:v1.0.1
- name: RELATED_IMAGE_SCHEDULER
  value: registry.example.com/example/scheduler:v1.2.0
- name: OPERATOR_IMAGE
  value: registry.example.com/example/operator:v1.0.0
```

As an additional feature, operator's image can also be updated. The image
should be in the image list with name `OPERATOR_IMAGE`. For a Deployment
config, it'll update the operator's container image and for a CSV config, it'll
update the `metadata.annotations.containerImage` and the operator container
image under Deployment.

## Usage

```yaml
    - uses: actions/checkout@v2
    - name: related-image-update action
      uses: darkowlzz/related-image-update@master
      with:
        imageListFile: testdata/imagelist-0.2.0.yaml
        targetFile: testdata/bundle/manifests/memcached-operator.clusterserviceversion.yaml
        deploymentName: memcached-operator-controller-manager
        containerName: manager
```

This will read the image list `testdata/imagelist-0.2.0.yaml` and update the
deployment `memcached-operator-controller-manager` for container `manager` with
`RELATED_IMAGE` env vars in the image list file.

**NOTE**: When the `targetFile` is a kubernetes Deployment config,
`deploymentName` input is not required.

## Action inputs

| Name | Description |
| --- | --- |
| `imageListFile` | Image list file. |
| `targetFile` | Target Deployment or ClusterServiceVersion file to update. |
| `deploymentName` | Target deployment name (required for CSV file). |
| `containerName` | Target container name. |

## Using without github actions

### Container image

related-image-update can be used with the container image
`ghcr.io/darkowlzz/related-image-update:test`.

```console
$ docker run --rm \
	-v $PWD:/github/workspace \
	-e IMAGE_LIST_FILE=<path/to/image-list-file> \
	-e TARGET_FILE=<path/to/target-file> \
	-e TARGET_DEPLOYMENT_NAME=<deployment-name> \
	-e TARGET_CONTAINER_NAME=<container-name> \
	-u "$(shell id -u):$(shell id -g)" \
	ghcr.io/darkowlzz/related-image-update:test
```

This will populate the target file `$TARGET_FILE` with images from the image
list.

**NOTE**: Mounting to the working directory to `/github/workspace` is required
because the container image is made to work in github actions environment.

### Script

To use related-image-update directly on host using the `imageupdate.sh` script,
install [`yq`](https://github.com/mikefarah/yq/) first. The image update uses
yq for parsing yaml files. Ensure that it's available in the $PATH.
Run:

```console
$ IMAGE_LIST_FILE=image-0.1.0.yaml TARGET_DEPLOYMENT_NAME=my-operator \
 	TARGET_CONTAINER_NAME=my-operator \
 	TARGET_FILE=my-operator.v0.1.0.clusterserviceversion.yaml \
 	imageupdate.sh
```

This will populate the target file `$TARGET_FILE` with images from the image
list.
