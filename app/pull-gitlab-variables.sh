#!/bin/bash

# arguments:
# - ATLANTIS_GITLAB_TOKEN
# - HEAD_REPO_OWNER
# - HEAD_REPO_NAME
# - ALLOWLIST_FILE e.g. GOOGLE_APPLICATION_CREDENTIALS
# - ALLOWLIST_ENV_VAR e.g. AWS_ACCESS_KEY_ID,AWS_SECRET_ACCESS_KEY


ALLOWLIST_ENV_VAR_ARRAY=($(printf '%s\n' ${ALLOWLIST_ENV_VAR//,/ } | sort))
ALLOWLIST_FILE_ARRAY=($(printf '%s\n' ${ALLOWLIST_FILE//,/ } | sort))

# Variable needed for `glab`
export GITLAB_TOKEN=${ATLANTIS_GITLAB_TOKEN}

ENCODED_REPO_NAME=$(jq -rn --arg x "${HEAD_REPO_OWNER}/${HEAD_REPO_NAME}" '$x|@uri')
API_RESPONSE=$(glab api projects/$ENCODED_REPO_NAME/variables)
MULTIENV_RESULT=""


ENV_VAR_VARIABLES=$(echo $API_RESPONSE | jq -c '.[] | select(.variable_type == "env_var") | {key, value, environment_scope}' | jq -cs 'sort_by(.key) | .[]')
for v in $ENV_VAR_VARIABLES
do
  name=$(echo $v | jq -r '.key')
  content=$(echo $v | jq -r '.value')
  MULTIENV_RESULT+="${name}=${content}",
done

ENV_VARS=$(echo $API_RESPONSE | jq -cr '[.[] | select(.variable_type == "env_var").key] | sort | .[]')
RESULT=($(comm -13 <(printf '%s\n' ${ALLOWLIST_ENV_VAR_ARRAY[@]}) <(printf '%s\n' ${ENV_VARS[@]})))

if [ ${#RESULT[@]} -gt 0 ]; then
  printf "Not allowed environment variables: [%s]\n" $(IFS=,; printf %s "${RESULT[*]}")
  exit 1;
fi

FILE_VARIABLES=$(echo $API_RESPONSE | jq -c '.[] | select(.variable_type == "file") | {key, value, environment_scope}' | jq -cs 'sort_by(.key) | .[]')
for v in $FILE_VARIABLES
do
  name=$(echo $v | jq -r '.key')
  randomized_name=${name}_$RANDOM
  content=$(echo $v | jq -r '.value')
  echo $content > $randomized_name
  MULTIENV_RESULT+="${name}=${randomized_name}",
done

FILES=$(echo $API_RESPONSE | jq -cr '[.[] | select(.variable_type == "file").key] | sort | .[]')
RESULT=($(comm -13 <(printf '%s\n' ${ALLOWLIST_FILE_ARRAY[@]}) <(printf '%s\n' ${FILES[@]})))

if [ ${#RESULT[@]} -gt 0 ]; then
  printf "Not allowed file variables: [%s]\n" $(IFS=,; printf %s "${RESULT[*]}")
  exit 1;
fi

MULTIENV_RESULT=${MULTIENV_RESULT%,}
echo $MULTIENV_RESULT
