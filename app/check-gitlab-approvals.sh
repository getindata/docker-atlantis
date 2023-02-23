#!/bin/bash
# Script checks if GitLab MR was approved by allowed user. It's intention is to work around
# free GitLab limitations (no CODEOWNERS, required approvals).
#
# This script makes great use of yq, jq, glab commands and they should be installed
# and availiable in $PATH priror script execution
#
# Approvers configuration can be set in number of ways:
# - By pointing `APPROVAL_CONFIG_PATH` environment variable to proper APPROVAL_CONFIG yaml file
# - By passing path to APPROVAL_CONFIG yaml file as the first input argument to this script
# - By directly populating `APPROVAL_CONFIG` environment variable with configuration
#
# APPROVAL_CONFIG is a `yaml` file with list of approved GitLab usernames per project, example:
# ---
# repository:
#   REPOSITORY:
#     allowed_approvers:
#       - GITLAB_USERNAME
#   getindata/devops/dummy-test-project:
#     allowed_approvers:
#       - john.doe
#   getindata/devops/aws/gid-aws-terragrunt-platform:
#     allowed_approvers:
#       - jane.doe
#       - example_username
#
# We assume that env variables are populated correctly (according to Atlantis dockumentation)
# and script is executed in proper custom workflow context:
# - ATLANTIS_GITLAB_TOKEN
# - HEAD_REPO_OWNER
# - HEAD_REPO_NAME
# - PULL_NUM

# Get approval-config.yaml file path from: environment variable or 1st argument, 
# use default when nothing is set
if [ $# -gt 0 ]; then
  # if ARG is passed to script, use it
  APPROVAL_CONFIG_PATH=${1}
elif [ ! -v APPROVAL_CONFIG_PATH ] || [ -z "$APPROVAL_CONFIG_PATH" ]; then
  # if env is not set or is empty set default
  APPROVAL_CONFIG_PATH="/atlantis-data/approval-config.yaml"
fi

# Variable needed for `glab`
export GITLAB_TOKEN=${ATLANTIS_GITLAB_TOKEN}

REPO_NAME="${HEAD_REPO_OWNER}/${HEAD_REPO_NAME}"

# Declare arrays
declare -a APPROVERS_ALLOWED
declare -a APPROVERS_GITLAB
declare -a RESULT

# Get repository approvers configuration
if [ -v APPROVAL_CONFIG ] && [ ! -z "$APPROVAL_CONFIG" ]; then
  # If env is set and not empty - read approvers configuration yaml directly from ENV
  APPROVERS_ALLOWED=($(yq --null-input eval "env(APPROVAL_CONFIG)" | yq eval ".repository.$REPO_NAME.allowed_approvers.[]" - | sort))
elif [ -f $APPROVAL_CONFIG_PATH ]; then
  # If file passed through APPROVAL_CONFIG_PATH env exists, try to parse it
  APPROVERS_ALLOWED=($(yq eval ".repository.$REPO_NAME.allowed_approvers.[]" ${APPROVAL_CONFIG_PATH} | sort))
else
  printf "GitLab approval configuration file not found in '%s' nor in \$APPROVAL_CONFIG - will not continue...\n" ${APPROVAL_CONFIG_PATH}
  exit 1;
fi

# Get list of MR approvals from GitLab API
APPROVERS_GITLAB=($(jq -rn --arg x "${REPO_NAME}" '$x|@uri' | xargs -i glab api projects/{}/merge_requests/$PULL_NUM/approvals | jq '.approved_by[].user.username' | tr -d \" | sort))

# Find intersection between Allowed and Actual approvers of MR
RESULT=($(comm -12 <(printf '%s\n' ${APPROVERS_ALLOWED[@]}) <(printf '%s\n' ${APPROVERS_GITLAB[@]})))

if [ ${#RESULT[@]} -gt 0 ]; then
  printf "MR approved correctly by [%s]\n" $(IFS=,; printf %s "${RESULT[*]}")
elif [ ${#APPROVERS_ALLOWED[@]} -eq 0 ]; then
  printf "Missing or bad configuration for '$REPO_NAME' repo in approval configuration - will not continue...\n"
  exit 1;
else
  printf "Your MR has to be approved by at least one of those users [%s] to continue !!!\n" $(IFS=,; printf %s "${APPROVERS_ALLOWED[*]}")
  exit 1;
fi
