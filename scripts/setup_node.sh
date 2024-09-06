#!/bin/bash

# Set repository URL
REPO_URL="https://github.com/bkvpool/relay.git"
CNODE_SCRIPT="scripts/cnode.sh"
ENV_FILE="examples/.env"

# Default folder paths
DEFAULT_DATA_FOLDER="$HOME/cnode/data"
DEFAULT_CONFIG_FOLDER="$HOME/cnode/config"
DEFAULT_IPC_FOLDER="$HOME/cnode/ipc"

# Sanity checks for dependencies
echo "Performing initial sanity checks..."

if ! command -v git &> /dev/null; then
    echo "Error: git is not installed. Please install git and try again."
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "Error: curl is not installed. Please install curl and try again."
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please install Docker and try again."
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "Error: Docker is installed but not accessible. Please make sure your user has access to Docker."
    exit 1
fi

# Clone the repository
echo "Cloning the repository..."
git clone $REPO_URL
cd relay || { echo "Failed to enter the relay directory"; exit 1; }

# Ask user for default folders with provided defaults
read -p "Enter the path for data folder (default: $DEFAULT_DATA_FOLDER): " DATA_FOLDER
DATA_FOLDER=${DATA_FOLDER:-$DEFAULT_DATA_FOLDER}

read -p "Enter the path for config folder (default: $DEFAULT_CONFIG_FOLDER): " CONFIG_FOLDER
CONFIG_FOLDER=${CONFIG_FOLDER:-$DEFAULT_CONFIG_FOLDER}/mainnet

read -p "Enter the path for IPC folder (default: $DEFAULT_IPC_FOLDER): " IPC_FOLDER
IPC_FOLDER=${IPC_FOLDER:-$DEFAULT_IPC_FOLDER}

# Create the necessary directories if they don't exist
mkdir -p "$DATA_FOLDER"
mkdir -p "$CONFIG_FOLDER"
mkdir -p "$IPC_FOLDER"

# Create .env file and set up environment variables
echo "Creating .env file..."
cat > .env <<EOL
DATA_FOLDER=$DATA_FOLDER
CONFIG_FOLDER=$CONFIG_FOLDER
IPC_FOLDER=$IPC_FOLDER
EOL

# Download necessary files for mainnet into the mainnet subfolder of the config directory
download_file_if_not_exists() {
    local url=$1
    local filepath=$2

    if [ ! -f "$filepath" ]; then
        echo "Downloading $filepath..."
        curl -o "$filepath" "$url"
    else
        echo "$filepath already exists, skipping download."
    fi
}

echo "Checking and downloading configuration files for mainnet if they are not present..."

download_file_if_not_exists https://book.world.dev.cardano.org/environments/mainnet/config.json "$CONFIG_FOLDER/config.json"
download_file_if_not_exists https://book.world.dev.cardano.org/environments/mainnet/byron-genesis.json "$CONFIG_FOLDER/byron-genesis.json"
download_file_if_not_exists https://book.world.dev.cardano.org/environments/mainnet/shelley-genesis.json "$CONFIG_FOLDER/shelley-genesis.json"
download_file_if_not_exists https://book.world.dev.cardano.org/environments/mainnet/alonzo-genesis.json "$CONFIG_FOLDER/alonzo-genesis.json"
download_file_if_not_exists https://book.world.dev.cardano.org/environments/mainnet/conway-genesis.json "$CONFIG_FOLDER/conway-genesis.json"
download_file_if_not_exists https://book.world.dev.cardano.org/environments/mainnet/topology.json "$CONFIG_FOLDER/topology.json"

# Ask user for container name
read -p "Enter the container name (default: cardano-node-relay): " CONTAINER_NAME
CONTAINER_NAME=${CONTAINER_NAME:-cardano-node-relay}

# Update the cnode.sh script with the correct paths and container name
echo "Updating $CNODE_SCRIPT..."
sed -i "s|COMPOSE_FILE_PATH=.*|COMPOSE_FILE_PATH=$(pwd)|" $CNODE_SCRIPT
sed -i "s|CONTAINER_NAME=.*|CONTAINER_NAME=$CONTAINER_NAME|" $CNODE_SCRIPT

echo "Setup completed successfully. You can now use the cnode.sh script to manage your Cardano relay node."

# Final sanity check
echo "Performing final sanity check..."
if [ -d "$DATA_FOLDER" ] && [ -d "$CONFIG_FOLDER" ] && [ -f "$CONFIG_FOLDER/config.json" ]; then
    echo "All required folders and files are in place."
else
    echo "Error: Please check your folder paths and downloaded files."
    exit 1
fi

# Instructions for adding the scripts folder to PATH
echo "To make the 'cnode.sh' script available globally, consider adding the scripts folder to your PATH:"
echo "export PATH=\$PATH:$(pwd)/scripts"
echo "You can add the above line to your shell profile file (e.g., ~/.bash_profile or ~/.zsh_profile) to make it permanent."
