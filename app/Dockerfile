# syntax=docker/dockerfile:1

ARG ATLANTIS_VERSION=v0.27.2

FROM ghcr.io/runatlantis/atlantis:${ATLANTIS_VERSION} AS base

# Default tool versions installed in that image

ARG ASDF_VERSION=v0.14.0
ARG K8S_VERSION=1.30.0
ARG HELM_VERSION=3.14.4
ARG TF_VERSION=1.5.7
ARG TG_VERSION=0.55.13
ARG TG_ATLANTIS_VERSION=1.17.4
ARG CONFTEST_VERSION=0.50.0
ARG GLAB_VERSION=1.37.0
ARG GOJQ_VERSION=0.12.14
ARG YQ_VERSION=4.42.1
ARG AZURE_CLI_VERSION=2.58.0
ARG AWS_CLI_VERSION=2.13.25-r0
ARG CHECKOV_VERSION=3.2.74
ARG INFRACOST_VERSION=0.10.35
ARG TFLINT_VERSION=0.50.3
ARG TERRAFORM_DOCS_VERSION=0.17.0

USER root

RUN set -ex && \
    apk update && \
    apk add py3-pip curl aws-cli=${AWS_CLI_VERSION} && \
    apk add --virtual=build gcc libffi-dev musl-dev openssl-dev python3-dev cargo make unzip && \
    pip install --upgrade pip --break-system-packages && \
    pip install --upgrade setuptools --break-system-packages && \
    ###
    ### Ensure Azure cli version is present and validated
    ### with --break-system-packages due to https://peps.python.org/pep-0668/
    pip install azure-cli==${AZURE_CLI_VERSION} --break-system-packages && \
    az --version && \
    ### cleanup build dependencies
    apk del build

# Download and install terragrunt-atlantis-config
RUN curl -LOs https://github.com/transcend-io/terragrunt-atlantis-config/releases/download/v${TG_ATLANTIS_VERSION}/terragrunt-atlantis-config_${TG_ATLANTIS_VERSION}_linux_amd64.tar.gz && \
    tar xzf terragrunt-atlantis-config_${TG_ATLANTIS_VERSION}_linux_amd64.tar.gz && \
    mv terragrunt-atlantis-config_${TG_ATLANTIS_VERSION}_linux_amd64/terragrunt-atlantis-config_${TG_ATLANTIS_VERSION}_linux_amd64 /usr/bin/terragrunt-atlantis-config && \
    chmod a+x /usr/bin/terragrunt-atlantis-config && \
    rm -rf terragrunt-atlantis-config_${TG_ATLANTIS_VERSION}_linux_amd64*

# Download and install asdf
USER atlantis

RUN git clone --quiet https://github.com/asdf-vm/asdf.git $HOME/.asdf --branch ${ASDF_VERSION}

ENV PATH=$PATH:/home/atlantis/.asdf/bin:/home/atlantis/.asdf/shims

# Create .profile and source asdf inside
# ASDF_DIR is not automatically detected for sh
RUN echo 'export ASDF_DIR=$HOME/.asdf' >> $HOME/.profile && \
    echo '. $HOME/.asdf/asdf.sh' >> $HOME/.profile && \
    chown $USER.root $HOME/.profile && \
    chmod u+rw $HOME/.profile

# Install all needed plugins
RUN asdf plugin-add kubectl && \
    asdf plugin-add helm && \
    asdf plugin-add terragrunt && \
    asdf plugin-add terraform && \
    asdf plugin-add conftest && \
    asdf plugin-add glab && \
    asdf plugin-add gojq && \
    asdf plugin-add tflint && \
    asdf plugin-add terraform-docs && \
    asdf plugin-add yq && \
    asdf plugin-add checkov && \
    asdf plugin-add infracost

# Install default versions and define them globally
RUN asdf install kubectl ${K8S_VERSION} && \
    asdf install helm ${HELM_VERSION} && \
    asdf install terraform ${TF_VERSION} && \
    asdf install terragrunt ${TG_VERSION} && \
    asdf install conftest ${CONFTEST_VERSION} && \
    asdf install glab ${GLAB_VERSION} && \
    asdf install gojq ${GOJQ_VERSION} && \
    asdf install tflint ${TFLINT_VERSION} && \
    asdf install terraform-docs ${TERRAFORM_DOCS_VERSION} && \
    asdf install yq ${YQ_VERSION} && \
    asdf install checkov ${CHECKOV_VERSION} && \
    asdf install infracost ${INFRACOST_VERSION} && \
    asdf global kubectl ${K8S_VERSION} && \
    asdf global helm ${HELM_VERSION} && \
    asdf global terraform ${TF_VERSION} && \
    asdf global terragrunt ${TG_VERSION} && \
    asdf global conftest ${CONFTEST_VERSION} && \
    asdf global glab ${GLAB_VERSION} && \
    asdf global gojq ${GOJQ_VERSION} && \
    asdf global tflint ${TFLINT_VERSION} && \
    asdf global terraform-docs ${TERRAFORM_DOCS_VERSION} && \
    asdf global yq ${YQ_VERSION} && \
    asdf global checkov ${CHECKOV_VERSION} && \
    asdf global infracost ${INFRACOST_VERSION}

# Additional cleanup for non default terraform versions, pip cache, tmp
RUN pip cache purge

USER root

RUN rm -f /usr/local/bin/terraform* && \
    pip cache purge && \
    rm -rf /tmp/*

# Add 'alias' `jq` to `gojq`
RUN echo -e '#!/bin/sh \nexec gojq "$@"' > /usr/local/bin/jq && chmod +x /usr/local/bin/jq

# Set atlantis login shell to sh
RUN sed -i s#atlantis:/sbin/nologin#atlantis:/bin/sh#g /etc/passwd

COPY check-gitlab-approvals.sh /usr/local/bin/check-gitlab-approvals.sh
COPY pull-gitlab-variables.sh /usr/local/bin/pull-gitlab-variables.sh

RUN chmod a+x /usr/local/bin/check-gitlab-approvals.sh && \
    chmod a+x /usr/local/bin/pull-gitlab-variables.sh

USER atlantis
# Add GitHub and GitLab to known keys file for safe SSH connections
RUN mkdir -p $HOME/.ssh && \
    chmod 0700 $HOME/.ssh && \
    touch $HOME/.ssh/known_hosts && \
    chmod 0600 $HOME/.ssh/known_hosts && \
    ssh-keyscan -H github.com >> $HOME/.ssh/known_hosts && \
    ssh-keyscan -H gitlab.com >> $HOME/.ssh/known_hosts

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["server"]
