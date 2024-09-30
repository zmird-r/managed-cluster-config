ARTIFACT_DIR="${ARTIFACT_DIR:-/tmp/artifacts}"
[ ! -d "$ARTIFACT_DIR" ] && mkdir -p "$ARTIFACT_DIR"
TEMP_FILE=$(mktemp -p "$ARTIFACT_DIR" wif_templates_XXXXXX)

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    echo "Error: yq is not installed. Please install yq to proceed."
    exit 0
fi

SERVICE_ACCOUNT_ID_LENGTH=50
SERVICE_ACCOUNT_ROLE_ID_LENGTH=51

MALFORMED_FILES=0
while IFS= read -r YAML_FILE; do
  ERROR_MESSAGE=""

  # Checking service accounts
  SERVICE_ACCOUNTS_IDS=$(yq e '.service_accounts[].id' "$YAML_FILE")
  while IFS= read -r ID; do
      if (( ${#ID} > $SERVICE_ACCOUNT_ID_LENGTH )); then
          ERROR_MESSAGE+=$"SERVICE ACCOUNT: '$id' is ${#id} characters long.\n"
      fi
  done <<< "$SERVICE_ACCOUNTS_IDS"

  # Checking roles
  ROLE_IDS=$(yq e '.service_accounts[].roles[].id' "$YAML_FILE")
  while IFS= read -r ID; do
      if (( ${#ID} > $SERVICE_ACCOUNT_ROLE_ID_LENGTH )); then
          ERROR_MESSAGE+=$"ROLE: '$ID' is ${#id} characters long.\n"
      fi

      # Correct format examples:
      # role_name_v4.17 (custom names)
      # compute.storageAdmin (gcp permission format)
      if [[ ! ( "$ID" =~ ^[a-z0-9_]+_v4\.[0-9]+$ || "$ID" =~ ^[a-zA-Z]+(\.[a-zA-Z]+)+(\.\*)?$ ) ]]; then
          ERROR_MESSAGE+=$"ROLE: '$ID' wrong format.\n"
      fi
  done <<< "$ROLE_IDS"


  if [[ -n $ERROR_MESSAGE ]]; then
      echo $YAML_FILE ":" >> "$TEMP_FILE"
      echo -e $ERROR_MESSAGE >> "$TEMP_FILE"

      ((MALFORMED_FILES++))
  fi

done < <(find  ./resources/wif/4.** -type f)

# Final result
if (( MALFORMED_FILES == 0 )); then
    echo "All checks passed successfully."
else
    echo "$MALFORMED_FILES malformed file(s) found."
    exit 1
fi
