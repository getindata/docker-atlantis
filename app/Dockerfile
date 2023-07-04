# syntax=docker/dockerfile:1
ARG ATLANTIS_BASE_VERSION=2023.03.01-alpine
# The runatlantis/atlantis-base is created by docker-base/Dockerfile.
FROM ghcr.io/runatlantis/atlantis-base:${ATLANTIS_BASE_VERSION} AS base

# Default tool versions installed in that image
ARG ATLANTIS_VERSION=v0.23.3
ARG ASDF_VERSION=v0.11.3
ARG K8S_VERSION=1.25.5
ARG HELM_VERSION=3.11.2
ARG TF_VERSION=1.4.2
ARG TG_VERSION=0.45.0
ARG TG_ATLANTIS_VERSION=1.16.0
ARG CONFTEST_VERSION=v0.35.0
ARG GLAB_VERSION=1.26.0
ARG GOJQ_VERSION=0.12.13
ARG YQ_VERSION=4.9.8
ARG AZURE_CLI_VERSION=2.46.0
ARG CHECKOV_VERSION=2.1.244
ARG INFRACOST_VERSION=v0.10.18
ARG TFLINT_VERSION=0.45.0
ARG TERRAFORM_DOCS_VERSION=0.16.0
ARG AWS_CLI_VERSION=2.12.6-r0

RUN set -ex && \
    apk update && \
    apk add bash py3-pip curl && \
    apk add --virtual=build gcc libffi-dev musl-dev openssl-dev python3-dev cargo make curl unzip

###
### Install Checkov
###
RUN set -ex && \
    pip install --upgrade pip && \
    pip install --upgrade setuptools && \
    pip install checkov==${CHECKOV_VERSION}

# Download and install Infracost
RUN curl -LOs https://github.com/infracost/infracost/releases/download/${INFRACOST_VERSION}/infracost-linux-amd64.tar.gz && \
    tar xzf infracost-linux-amd64.tar.gz && \
    mv infracost-linux-amd64 /usr/bin/infracost && \
    chmod a+x /usr/bin/infracost && \
    rm -rf infracost-linux-amd64*

###
### Ensure Azure cli version is present and validated
###
RUN set -eux \
    && pip install azure-cli==${AZURE_CLI_VERSION} \
    && az --version

###
### Ensure AWS cli version is present and validated
###
RUN set -eux \
    && apk add --no-cache aws-cli-${AWS_CLI_VERSION} \
    && aws --version

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
    asdf plugin-add gojq && \
    asdf plugin-add tflint && \
    asdf plugin-add terraform-docs && \
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
    asdf install gojq ${GOJQ_VERSION} && \
    asdf install tflint ${TFLINT_VERSION} && \
    asdf install terraform-docs ${TERRAFORM_DOCS_VERSION} && \
    asdf install yq ${YQ_VERSION} && \
    asdf global kubectl ${K8S_VERSION} && \
    asdf global helm ${HELM_VERSION} && \
    asdf global terraform ${TF_VERSION} && \
    asdf global terragrunt ${TG_VERSION} && \
    asdf global conftest ${CONFTEST_VERSION} && \
    asdf global glab ${GLAB_VERSION} && \
    asdf global gojq ${GOJQ_VERSION} && \
    asdf global tflint ${TFLINT_VERSION} && \
    asdf global terraform-docs ${TERRAFORM_DOCS_VERSION} && \
    asdf global yq ${YQ_VERSION}"

# Additional cleanup
RUN rm -rf /tmp/*
# Add 'alias' `jq` to `gojq`
RUN echo -e '#!/bin/bash \nexec gojq "$@"' > /usr/local/bin/jq && chmod +x /usr/local/bin/jq

# Set atlantis login shell to bash
RUN sed -i s#atlantis:/sbin/nologin#atlantis:/bin/bash#g /etc/passwd

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY check-gitlab-approvals.sh /usr/local/bin/check-gitlab-approvals.sh
COPY pull-gitlab-variables.sh /usr/local/bin/pull-gitlab-variables.sh

RUN chmod a+x /usr/local/bin/docker-entrypoint.sh && \
    chmod a+x /usr/local/bin/check-gitlab-approvals.sh && \
    chmod a+x /usr/local/bin/pull-gitlab-variables.sh

USER atlantis
# Add GitHub and GitLab to known keys file for safe SSH connections
RUN mkdir -p /home/atlantis/.ssh && \
    chmod 0700 /home/atlantis/.ssh && \
    touch /home/atlantis/.ssh/known_hosts && \
    chmod 0600 /home/atlantis/.ssh/known_hosts && \
    ssh-keyscan -H github.com >> /home/atlantis/.ssh/known_hosts && \
    ssh-keyscan -H gitlab.com >> /home/atlantis/.ssh/known_hosts

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["server"]
