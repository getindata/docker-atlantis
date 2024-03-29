#!/bin/bash
# Script loads variables from GitLab for a specified repository and prints them on stdout as a formatted string (see:
# https://www.runatlantis.io/docs/custom-workflows.html#multiple-environment-variables-multienv-command)
# It's intention is to allow run multiple workloads with different set of permissions on a single Atlantis instance.
#
# This script makes great use of `jq` and `glab` commands and they should be installed
# and available in $PATH prior script execution
#
# We assume that env variables are populated correctly (according to Atlantis documentation)
# and script is executed in proper custom workflow context:
# - ATLANTIS_GITLAB_TOKEN
# - ATLANTIS_GITLAB_HOSTNAME (if private GitLab is used)
# - HEAD_REPO_OWNER
# - HEAD_REPO_NAME
# - REPO_REL_DIR - currently the script will use GitLab's environment scope (and `*`) from a directly nested directory under `environments/`
#                  e.g. `environments/dev/gcp` -> `dev`
#
# Other than Atlantis custom workflow context environment variables there are additional flags to tweak the script behaviour:
# - ALLOWLIST_FILE - specifies what `file` type variables are allowed, e.g. GOOGLE_APPLICATION_CREDENTIALS
# - ALLOWLIST_ENV_VAR - specifies what `env_var` type variables are allowed, e.g. AWS_ACCESS_KEY_ID,AWS_SECRET_ACCESS_KEY
# - FIXED_ENV_VARS - specifies environment variables that will be appended to the result string, e.g. ARM_USE_MSI=false,LOG_LEVEL=warn

# Variable needed for `glab`
export GITLAB_TOKEN=${ATLANTIS_GITLAB_TOKEN}
if [ -v ATLANTIS_GITLAB_HOSTNAME ] && [ ! -z "$ATLANTIS_GITLAB_HOSTNAME" ]; then
  # if env set and not empty set GITLAB_HOST
  export GITLAB_HOST="https://${ATLANTIS_GITLAB_HOSTNAME}"
fi

ENV_SCOPE=$(echo $REPO_REL_DIR | sed -nE 's/environments\/([^/]+).*/\1/p')
: "${ENV_SCOPE:=*}"

ENCODED_REPO_NAME=$(jq -rn --arg x "${HEAD_REPO_OWNER}/${HEAD_REPO_NAME}" '$x|@uri')
API_RESPONSE=$(glab api projects/$ENCODED_REPO_NAME/variables)
MULTIENV_RESULT=""

# default values for allowlist environment variables:
ALLOWLIST_ENV_VAR="${ALLOWLIST_ENV_VAR:-AWS_ACCESS_KEY_ID,AWS_SECRET_ACCESS_KEY}"
ALLOWLIST_FILE="${ALLOWLIST_FILE:-GOOGLE_APPLICATION_CREDENTIALS}"
FIXED_ENV_VARS="${FIXED_ENV_VARS:-ARM_USE_MSI=false}"


ALLOWLIST_ENV_VAR_ARRAY=($(printf '%s\n' ${ALLOWLIST_ENV_VAR//,/ } | sort))
readarray -t ENV_VAR_VARIABLES < <(echo "$API_RESPONSE" | jq -c ".[] | select(.variable_type == \"env_var\" and (.environment_scope == \"$ENV_SCOPE\" or .environment_scope == \"*\")) | {key, value, env: (if .environment_scope == \"$ENV_SCOPE\" then 1 else 2 end)}" | jq -cs 'sort_by(.key, .env) | unique_by(.key) | .[] | {key, value}')
for v in "${ENV_VAR_VARIABLES[@]}"
do
  name=$(echo $v | jq -r '.key')
  if [[ " ${ALLOWLIST_ENV_VAR_ARRAY[*]} " =~ " $name " ]]; then
    content=$(echo $v | jq -r '.value')
    MULTIENV_RESULT+="${name}=${content}",
  else
    :
    # TODO: Atlantis couldn't handle anything printed on stderr - only dynamic variables should be outputted
    # >&2 echo "Not allowed environment variable: $name. Skipped..."
  fi
done

ALLOWLIST_FILE_ARRAY=($(printf '%s\n' ${ALLOWLIST_FILE//,/ } | sort))
readarray -t FILE_VARIABLES < <(echo "$API_RESPONSE" | jq -c ".[] | select(.variable_type == \"file\" and (.environment_scope == \"$ENV_SCOPE\" or .environment_scope == \"*\")) | {key, value, env: (if .environment_scope == \"$ENV_SCOPE\" then 1 else 2 end)}" | jq -cs 'sort_by(.key, .env) | unique_by(.key) | .[] | {key, value}')
for v in "${FILE_VARIABLES[@]}"
do
  name=$(echo $v | jq -r '.key')
  if [[ " ${ALLOWLIST_FILE_ARRAY[*]} " =~ " $name " ]]; then
    randomized_name="${PWD}/${name}_$RANDOM"
    content=$(echo "$v" | jq -r '.value')
    echo "$content" > $randomized_name
    MULTIENV_RESULT+="${name}=${randomized_name}",
  else
    :
    # TODO: Atlantis couldn't handle anything printed on stderr - only dynamic variables should be outputted
    # >&2 echo "Not allowed file variable: $name. Skipped..."
  fi
done

ENV_VARS=$(echo $API_RESPONSE | jq -cr "[.[] | select(.variable_type == \"env_var\" and (.environment_scope == \"$ENV_SCOPE\" or .environment_scope == \"*\")).key] | sort | .[]" | uniq)
ENV_VARS_TO_MASK=($(comm -23 <(printf '%s\n' ${ALLOWLIST_ENV_VAR_ARRAY[@]}) <(printf '%s\n' ${ENV_VARS[@]})))
for v in ${ENV_VARS_TO_MASK[@]}
do
  MULTIENV_RESULT+="${v}=",
done

FILES=$(echo $API_RESPONSE | jq -cr "[.[] | select(.variable_type == \"file\" and (.environment_scope == \"$ENV_SCOPE\" or .environment_scope == \"*\")).key] | sort | .[]" | uniq)
FILES_TO_MASK=($(comm -23 <(printf '%s\n' ${ALLOWLIST_FILE_ARRAY[@]}) <(printf '%s\n' ${FILES[@]})))
for v in ${FILES_TO_MASK[@]}
do
  MULTIENV_RESULT+="${v}=",
done

MULTIENV_RESULT+="${FIXED_ENV_VARS}"

echo ${MULTIENV_RESULT%,}
