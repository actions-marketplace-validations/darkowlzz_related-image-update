IMG_NAME ?= ghcr.io/darkowlzz/related-image-update
IMG_TAG ?= test
IMG = $(IMG_NAME):$(IMG_TAG)

YQ=bin/yq
YQ_VERSION=3.4.0
ARCH=amd64

docker-build: yq
	docker build -t ${IMG} \
		--build-arg USER_ID=$(shell id -u) \
		--build-arg GROUP_ID=$(shell id -g) \
		-f Dockerfile-dev \
		.

yq:
	mkdir -p bin
	@if [ ! -f $(YQ) ]; then \
		curl -Lo $(YQ) https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${ARCH} ;\
		chmod +x $(YQ) ;\
	fi
