FROM ubuntu:20.04
COPY imageupdate.sh /imageupdate.sh
RUN apt-get update && apt-get install curl -y

# TODO: Use multistate build.
RUN curl -Lo /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/3.4.0/yq_linux_amd64 && \
	chmod +x /usr/local/bin/yq

WORKDIR /github/workspace

# Setup a non-root user using the build args. This is required to avoid file
# permissions in the generated files inside the container.
# Refer: https://vsupalov.com/docker-shared-permissions/
# ARG USER_ID
# ARG GROUP_ID

# RUN addgroup --gid $GROUP_ID user
# RUN adduser --disabled-password --gecos '' --uid $USER_ID --gid $GROUP_ID user
# TODO: Find a way to pass docker build args in github actions build.
RUN addgroup --gid 1001 user
RUN adduser --disabled-password --gecos '' --uid 1001 --gid 1001 user
USER user

ENTRYPOINT ["/imageupdate.sh"]
