#!/bin/sh

# ANSI color codes
GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m" # No Color

# Configuration variables
bw_key_item_name="age-keys"
bw_ts_auth_name="ts-auth"
bw_org_id="e522f52b-1511-459f-af82-b26a010147e7"
bw_collection_id="4669f78e-49b3-407c-8506-b26a010147f3"
talos_node_ip="192.168.1.101"

# Function to print success messages
success_msg() {
  printf "${GREEN}%s${NC}\n" "$1"
}

# Function to print error messages
error_msg() {
  printf "${RED}%s${NC}\n" "$1"
}

check_required_commands() {
  echo "Checking for required commands..."
  
  missing_commands=""
  missing_count=0
  
  for cmd in "talhelper" "sops" "age" "bw" "talosctl" "jq"; do
    if ! command -v "$cmd" > /dev/null 2>&1; then
      missing_commands="$missing_commands $cmd"
      missing_count=$((missing_count + 1))
    fi
  done
  
  if [ $missing_count -ne 0 ]; then
    error_msg "The following commands are not installed:"
    for cmd in $missing_commands; do
      echo "- $cmd"
    done
    error_msg "Please install these commands and try again."
    return 1
  fi
  
  success_msg "All required commands are available."
  return 0
}

# Fetch secret from Bitwarden by item name
# Parameters:
# $1 - item name to search
# Returns: 
#   0 and prints the notes content if successful
#   1 on failure (item not found or error)
fetch_bitwarden_secret() {
  local item_name="$1"
  
  if [ -z "$item_name" ]; then
    error_msg "No item name provided for Bitwarden search"
    return 1
  fi

  # Check if Bitwarden is unlocked
  local bw_status=$(bw status | jq -r '.status')
  if [ "$bw_status" != "unlocked" ]; then
    error_msg "Bitwarden must be unlocked to retrieve secrets"
    return 1
  fi
  
  # Sync Bitwarden vault
  bw sync > /dev/null 2>&1
  
  # Prepare search options
  local search_options="--search \"$item_name\""
  
  # Add organization filter if specified
  if [ -n "$bw_org_id" ]; then
    search_options="$search_options --organizationid \"$bw_org_id\""
  fi
  
  # Execute the search
  local tmp_json=$(mktemp)
  eval "bw list items $search_options" > "$tmp_json"
  
  if [ ! -s "$tmp_json" ] || [ "$(cat "$tmp_json")" = "[]" ]; then
    error_msg "No item found in Bitwarden with name \"$item_name\""
    rm -f "$tmp_json"
    return 1
  fi
  
  # Extract item content
  local item_id=$(jq -r '.[0].id' "$tmp_json")
  rm -f "$tmp_json"
  
  if [ -z "$item_id" ] || [ "$item_id" = "null" ]; then
    error_msg "Failed to extract item ID from Bitwarden response"
    return 1
  fi
  
  # Get notes content
  local notes=$(bw get item "$item_id" | jq -r '.notes')
  
  if [ -z "$notes" ] || [ "$notes" = "null" ]; then
    error_msg "Item found but notes field is empty or null"
    return 1
  fi
  
  # Return the notes content (only output the actual content)
  echo "$notes"
  return 0
}

# Create .sops.yaml file with the Age public key
create_sops_config() {
  echo "Creating .sops.yaml configuration file..."
  
  # Extract the public key from keys.txt
  if [ -f "$HOME/.config/sops/age/keys.txt" ]; then
    # Get the line containing "# public key: " and extract the key
    local public_key=$(grep "# public key: " "$HOME/.config/sops/age/keys.txt" | sed 's/# public key: //')
    
    if [ -n "$public_key" ]; then
      # Create .sops.yaml in the current directory
      cat > ./.sops.yaml << EOF
---
creation_rules:
  - age: >-
      $public_key
EOF
      success_msg ".sops.yaml file created with Age public key"
    else
      error_msg "Could not extract public key from keys.txt"
      return 1
    fi
  else
    error_msg "Age keys file not found"
    return 1
  fi
  
  return 0
}

# Create talenv.sops.yaml from Bitwarden ts-auth item
create_talenv() {
  echo "Creating talenv.sops.yaml file from Bitwarden..."
  
  # Try to fetch the ts-auth secret from Bitwarden
  local ts_auth_content
  ts_auth_content=$(fetch_bitwarden_secret "$bw_ts_auth_name")
  local fetch_status=$?
  
  if [ $fetch_status -eq 0 ]; then
    # Secret retrieved successfully
    echo "tsAuth: $ts_auth_content" > talenv.sops.yaml
    
    # Encrypt with sops
    if ! sops -e -i talenv.sops.yaml; then
      error_msg "Failed to encrypt talenv.sops.yaml with sops"
      return 1
    fi
    
    success_msg "talenv.sops.yaml created from Bitwarden ts-auth and encrypted"
    return 0
  else
    # Failed to retrieve the secret, just return error
    error_msg "Failed to retrieve ts-auth from Bitwarden, aborting talenv creation"
    return 1
  fi
}

# Encrypt Talos secrets using talhelper and sops
encrypt_talos_secret() {
  echo "Encrypting Talos secrets..."
  
  # Create temp file for machine config
  local tmp_config="/tmp/machineconfig.yaml"
  
  # Read config from Talos node
  echo "Reading configuration from Talos node at $talos_node_ip..."
  if ! talosctl -n "$talos_node_ip" read /system/state/config.yaml > "$tmp_config"; then
    error_msg "Failed to read Talos configuration from $talos_node_ip"
    return 1
  fi
  
  # Generate secrets using talhelper
  echo "Generating encrypted secrets with talhelper..."
  if ! talhelper gensecret -f "$tmp_config" > talsecret.sops.yaml; then
    error_msg "Failed to generate and encrypt secrets with talhelper"
    rm -f "$tmp_config"
    return 1
  fi
  
  # Encrypt the file with sops
  echo "Encrypting the secrets file with sops..."
  if ! sops -e -i talsecret.sops.yaml; then
    error_msg "Failed to encrypt talsecret.sops.yaml with sops"
    rm -f "$tmp_config"
    return 1
  fi
  
  # Clean up
  rm -f "$tmp_config"
  
  success_msg "Talos secrets encrypted and saved to talsecret.sops.yaml"
  return 0
}

# Check if age keys file exists and fetch from Bitwarden if needed
# Returns: 0 if keys existed or were fetched from Bitwarden, 1 if keys were newly generated
check_age_keys() {
  echo "Checking if age keys file exists..."
  
  if [ -f "$HOME/.config/sops/age/keys.txt" ]; then
    success_msg "Age keys file found at: $HOME/.config/sops/age/keys.txt"
    return 0  # Keys already exist locally
  else
    echo "Age keys file not found. Attempting to retrieve from Bitwarden..."
    
    # Try to fetch the age keys from Bitwarden
    local age_keys
    age_keys=$(fetch_bitwarden_secret "$bw_key_item_name")
    local fetch_status=$?
    
    if [ $fetch_status -eq 0 ]; then
      # Keys retrieved successfully
      # Ensure the directory exists
      mkdir -p "$HOME/.config/sops/age"
      
      # Save the key to the file
      echo "$age_keys" > "$HOME/.config/sops/age/keys.txt"
      chmod 600 "$HOME/.config/sops/age/keys.txt"
      
      success_msg "Age keys retrieved from Bitwarden and saved to: $HOME/.config/sops/age/keys.txt"
      return 0  # Keys retrieved from Bitwarden, not newly generated
    fi
    
    # If we reached here, we need to generate new keys
    echo "Generating new age keys..."
    mkdir -p "$HOME/.config/sops/age"
    age-keygen -o "$HOME/.config/sops/age/keys.txt"
    chmod 600 "$HOME/.config/sops/age/keys.txt"
    
    # Ask if the user wants to save the new keys to Bitwarden
    echo "Would you like to save these new keys to Bitwarden? (y/n)"
    read -r save_to_bw
    
    if [ "$save_to_bw" = "y" ] || [ "$save_to_bw" = "Y" ]; then
      local key_content=$(cat "$HOME/.config/sops/age/keys.txt")
      
      # Create a new item in Bitwarden
      echo "Creating a new secure note in Bitwarden..."
      
      # Create a new item using bw get template command
      echo "Creating item in Bitwarden using template..."
      if [ -n "$bw_org_id" ]; then
        bw get template item | \
          jq ".organizationId = \"$bw_org_id\"" | \
          jq ".type = 2" | \
          jq ".name = \"$bw_key_item_name\"" | \
          jq ".notes = $(echo "$key_content" | jq -Rs)" | \
          jq ".secureNote = \"\"" | \
          jq ".collectionIds = [\"$bw_collection_id\"]" | \
          bw encode | \
          bw create item > /dev/null && bw sync > /dev/null
      else
        bw get template item | \
          jq ".type = 2" | \
          jq ".name = \"$bw_key_item_name\"" | \
          jq ".notes = $(echo "$key_content" | jq -Rs)" | \
          jq ".secureNote = \"\"" | \
          jq ".collectionIds = [\"$bw_collection_id\"]" | \
          bw encode | \
          bw create item > /dev/null && bw sync > /dev/null
      fi
      
      if [ $? -eq 0 ]; then
        success_msg "Age keys saved to Bitwarden."
      else
        error_msg "Failed to save age keys to Bitwarden."
      fi
    fi
    
    success_msg "New age keys generated at: $HOME/.config/sops/age/keys.txt"
    return 1  # Keys were newly generated
  fi
}

unlock_bitwarden() {
  check_required_commands || return 1
  
  echo "Starting talhelper init with Bitwarden CLI..."
  
  local bw_status=$(bw status | jq -r '.status')
  echo "Bitwarden status: $bw_status"
  
  if [ "$bw_status" = "unauthenticated" ]; then
    echo "Login to Bitwarden required"
    export BW_SESSION=$(bw login --raw)

  elif [ "$bw_status" = "locked" ]; then
    echo "Bitwarden is locked, unlocking..."
    export BW_SESSION=$(bw unlock --raw)
  fi
  
  bw_status=$(bw status | jq -r '.status')
  if [ "$bw_status" != "unlocked" ]; then
    error_msg "Failed to unlock Bitwarden session"
    return 1
  fi
  
  success_msg "Bitwarden unlocked successfully"
}

# https://budimanjojo.github.io/talhelper/latest/guides/#configuring-sops-for-talhelper
# https://budimanjojo.github.io/talhelper/latest/getting-started/#you-already-have-a-talos-cluster-running
main() {
  echo "talhelper Environment Setup Script"
  echo "------------------------------------"
  
  unlock_bitwarden
  check_age_keys
  keys_newly_generated=$?
  
  if [ $keys_newly_generated -eq 1 ]; then
    create_sops_config
    create_talenv
    encrypt_talos_secret
  fi

  talhelper genconfig
  if [ $? -eq 0 ]; then
    success_msg "Configuration generated successfully"
  else
    error_msg "Failed to generate configuration with talhelper"
    return 1
  fi
}

main
