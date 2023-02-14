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
# - HEAD_REPO_OWNER
# - HEAD_REPO_NAME
# - REPO_REL_DIR - currently the script will use GitLab's environment scope (and `*`) from last nested directory matching `dev|test|prod|staging` regex
#
# Other than Atlantis custom workflow context environment variables there are 2 additional flags to tweak the script behaviour:
# - ALLOWLIST_FILE - specifies what `file` type variables are allowed, e.g. GOOGLE_APPLICATION_CREDENTIALS
# - ALLOWLIST_ENV_VAR - specifies what `env_var` type variables are allowed, e.g. AWS_ACCESS_KEY_ID,AWS_SECRET_ACCESS_KEY

# Variable needed for `glab`
export GITLAB_TOKEN=${ATLANTIS_GITLAB_TOKEN}

ENV_SCOPE=$(echo $REPO_REL_DIR | sed -nE 's/.*\/(dev|test|prod|staging)\/.*/\1/p')
: "${ENV_SCOPE:=*}"

ENCODED_REPO_NAME=$(jq -rn --arg x "${HEAD_REPO_OWNER}/${HEAD_REPO_NAME}" '$x|@uri')
API_RESPONSE=$(glab api projects/$ENCODED_REPO_NAME/variables)
MULTIENV_RESULT=""


ALLOWLIST_ENV_VAR_ARRAY=($(printf '%s\n' ${ALLOWLIST_ENV_VAR//,/ } | sort))
ENV_VAR_VARIABLES=$(echo $API_RESPONSE | jq -c ".[] | select(.variable_type == \"env_var\" and (.environment_scope == \"$ENV_SCOPE\" or .environment_scope == \"*\")) | {key, value}" | jq -cs 'sort_by(.key) | .[]')
for v in $ENV_VAR_VARIABLES
do
  name=$(echo $v | jq -r '.key')
  if [[ " ${ALLOWLIST_ENV_VAR_ARRAY[*]} " =~ " $name " ]]; then
    content=$(echo $v | jq -r '.value')
    MULTIENV_RESULT+="${name}=${content}",
  else
    echo "Not allowed environment variable: $name. Skipped..."
  fi
done

ALLOWLIST_FILE_ARRAY=($(printf '%s\n' ${ALLOWLIST_FILE//,/ } | sort))
FILE_VARIABLES=$(echo $API_RESPONSE | jq -c ".[] | select(.variable_type == \"file\" and (.environment_scope == \"$ENV_SCOPE\" or .environment_scope == \"*\")) | {key, value}" | jq -cs 'sort_by(.key) | .[]')
for v in $FILE_VARIABLES
do
  name=$(echo $v | jq -r '.key')
  if [[ " ${ALLOWLIST_FILE_ARRAY[*]} " =~ " $name " ]]; then
    randomized_name=${name}_$RANDOM
    content=$(echo $v | jq -r '.value')
    echo $content > $randomized_name
    MULTIENV_RESULT+="${name}=${randomized_name}",
  else
    echo "Not allowed file variable: $name. Skipped..."
  fi
done

ENV_VARS=$(echo $API_RESPONSE | jq -cr "[.[] | select(.variable_type == \"env_var\" and (.environment_scope == \"$ENV_SCOPE\" or .environment_scope == \"*\")).key] | sort | .[]")
ENV_VARS_TO_MASK=($(comm -23 <(printf '%s\n' ${ALLOWLIST_ENV_VAR_ARRAY[@]}) <(printf '%s\n' ${ENV_VARS[@]})))
for v in $ENV_VARS_TO_MASK
do
  MULTIENV_RESULT+="${v}=",
done

FILES=$(echo $API_RESPONSE | jq -cr "[.[] | select(.variable_type == \"file\" and (.environment_scope == \"$ENV_SCOPE\" or .environment_scope == \"*\")).key] | sort | .[]")
FILES_TO_MASK=($(comm -23 <(printf '%s\n' ${ALLOWLIST_FILE_ARRAY[@]}) <(printf '%s\n' ${FILES[@]})))
for v in $FILES_TO_MASK
do
  MULTIENV_RESULT+="${v}=",
done

echo ${MULTIENV_RESULT%,}
