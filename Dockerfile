ARG ATLANTIS_BASE_VERSION=2022.09.08
# The runatlantis/atlantis-base is created by docker-base/Dockerfile.
FROM ghcr.io/runatlantis/atlantis-base:${ATLANTIS_BASE_VERSION} AS base

# Default tool versions installed in that image
ARG ATLANTIS_VERSION=v0.19.8
ARG ASDF_VERSION=v0.10.2
ARG K8S_VERSION=1.25.0
ARG HELM_VERSION=3.8.0
ARG TF_VERSION=1.2.3
ARG TG_VERSION=0.38.4
ARG TG_ATLANTIS_VERSION=1.15.0
ARG CONFTEST_VERSION=v0.34.0
ARG GLAB_VERSION=1.22.0
ARG JQ_VERSION=1.6
ARG YQ_VERSION=4.9.8


# Install awscli and checkov dependencies 
# RUN apk --no-cache add grep zlib-dev libffi-dev gcompat groff openssl3-dev python3 python3-dev py3-pip build-base gcc && \
#     pip3 --no-cache-dir install wheel && \
#     pip3 --no-cache-dir install checkov && \
#     pip3 cache purge && \
#     apk --no-cache del python3-dev build-base gcc

# Download and install Atlantis
RUN curl -LOs https://github.com/runatlantis/atlantis/releases/download/${ATLANTIS_VERSION}/atlantis_linux_amd64.zip && \
    unzip atlantis_linux_amd64.zip -d /usr/bin && \
    chmod a+x /usr/bin/atlantis && \
    rm atlantis_linux_amd64.zip

# Download and install terragrunt-atlantis-config
RUN curl -LOs https://github.com/transcend-io/terragrunt-atlantis-config/releases/download/v${TG_ATLANTIS_VERSION}/terragrunt-atlantis-config_${TG_ATLANTIS_VERSION}_linux_amd64.tar.gz && \
    tar xzf terragrunt-atlantis-config_${TG_ATLANTIS_VERSION}_linux_amd64.tar.gz && \
    mv terragrunt-atlantis-config_${TG_ATLANTIS_VERSION}_linux_amd64/terragrunt-atlantis-config_${TG_ATLANTIS_VERSION}_linux_amd64 /usr/bin/terragrunt-atlantis-config && \
    chmod a+x /usr/bin/terragrunt-atlantis-config && \
    rm -rf terragrunt-atlantis-config_${TG_ATLANTIS_VERSION}_linux_amd64*

# Download and install asdf, create .profile and source asdf inside
RUN gosu atlantis bash -l -c " \
    git clone --quiet https://github.com/asdf-vm/asdf.git /home/atlantis/.asdf --branch ${ASDF_VERSION} && \
    echo '. /home/atlantis/.asdf/asdf.sh' >> /home/atlantis/.profile && \
    chown atlantis.atlantis /home/atlantis/.profile && \
    chmod u+rw /home/atlantis/.profile"

# Install all needed plugins
RUN gosu atlantis bash -l -c " \
    asdf plugin-add kubectl && \
    asdf plugin-add helm && \
    asdf plugin-add terragrunt && \
    asdf plugin-add terraform && \
    asdf plugin-add conftest && \
    asdf plugin-add glab && \
    asdf plugin-add jq && \
    asdf plugin-add yq"
# Install default versions and define them globally
RUN gosu atlantis bash -l -c " \
    cd /home/atlantis/ && \
    asdf install kubectl ${K8S_VERSION} && \
    asdf install helm ${HELM_VERSION} && \
    asdf install terraform ${TF_VERSION} && \
    asdf install terragrunt ${TG_VERSION} && \
    asdf install conftest ${CONFTEST_VERSION} && \
    asdf install glab ${GLAB_VERSION} && \
    asdf install jq ${JQ_VERSION} && \
    asdf install yq ${YQ_VERSION} && \
    asdf global kubectl ${K8S_VERSION} && \
    asdf global helm ${HELM_VERSION} && \
    asdf global terraform ${TF_VERSION} && \
    asdf global terragrunt ${TG_VERSION} && \
    asdf global conftest ${CONFTEST_VERSION} && \
    asdf global glab ${GLAB_VERSION} && \
    asdf global jq ${JQ_VERSION} && \
    asdf global yq ${YQ_VERSION}"

# Additional cleanup
RUN rm -rf /tmp/*

# Set atlantis login shell to bash
RUN sed -i s#atlantis:/sbin/nologin#atlantis:/bin/bash#g /etc/passwd

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY check-gitlab-approvals.sh /usr/local/bin/check-gitlab-approvals.sh

RUN chmod a+x /usr/local/bin/docker-entrypoint.sh && \
    chmod a+x /usr/local/bin/check-gitlab-approvals.sh

USER atlantis

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["server"]