#!/bin/bash

# Paths
CNODE_SCRIPT="cnode.sh"
ENV_FILE="examples/.env"
DOCKER_COMPOSE_FILE="docker-compose.yml"

# Default folder paths
DEFAULT_BASE_FOLDER="$HOME/cnode"
DEFAULT_CNODE_DATA_FOLDER="$DEFAULT_BASE_FOLDER/data"
DEFAULT_CNODE_CONFIG_FOLDER="$DEFAULT_BASE_FOLDER/config/mainnet"
DEFAULT_CNODE_IPC_FOLDER="$DEFAULT_BASE_FOLDER/ipc"
DEFAULT_CNODE_SCRIPT_FOLDER="$DEFAULT_BASE_FOLDER/scripts"

# Sanity checks for dependencies
echo "Performing initial sanity checks..."

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

# Ask user for the base folder path
read -p "Enter the base path for the Cardano setup (default: $DEFAULT_BASE_FOLDER): " BASE_FOLDER < /dev/tty
BASE_FOLDER=${BASE_FOLDER:-$DEFAULT_BASE_FOLDER}

# Define paths based on the base folder
DATA_FOLDER="$BASE_FOLDER/data"
CONFIG_FOLDER="$BASE_FOLDER/config/mainnet"
IPC_FOLDER="$BASE_FOLDER/ipc"
CNODE_SCRIPT_FOLDER="$BASE_FOLDER/scripts"

# Create the necessary directories if they don't exist
mkdir -p "$DATA_FOLDER"
mkdir -p "$CONFIG_FOLDER"
mkdir -p "$IPC_FOLDER"
mkdir -p "$CNODE_SCRIPT_FOLDER"

# Copy the current docker-compose.yml file to the base folder
echo "Copying docker-compose.yml to $BASE_FOLDER..."
cp $DOCKER_COMPOSE_FILE "$BASE_FOLDER/"

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
read -p "Enter the container name (default: cardano-node-relay): " CONTAINER_NAME < /dev/tty
CONTAINER_NAME=${CONTAINER_NAME:-cardano-node-relay}

# Copy and update the cnode.sh script with the correct paths and container name
echo "Copying and updating the cnode.sh script to $CNODE_SCRIPT_FOLDER..."
cp $CNODE_SCRIPT $CNODE_SCRIPT_FOLDER/

sed -i "s|COMPOSE_FILE_PATH=.*|COMPOSE_FILE_PATH=$(pwd)|" $CNODE_SCRIPT_FOLDER/$CNODE_SCRIPT
sed -i "s|CONTAINER_NAME=.*|CONTAINER_NAME=$CONTAINER_NAME|" $CNODE_SCRIPT_FOLDER/$CNODE_SCRIPT

# Copy and update the .env file
echo "Copying and updating the .env file..."
cp $ENV_FILE "$BASE_FOLDER/.env"
sed -i "s|DATA_FOLDER=.*|DATA_FOLDER=$DATA_FOLDER|" "$BASE_FOLDER/.env"
sed -i "s|CONFIG_FOLDER=.*|CONFIG_FOLDER=$CONFIG_FOLDER|" "$BASE_FOLDER/.env"
sed -i "s|IPC_FOLDER=.*|IPC_FOLDER=$IPC_FOLDER|" "$BASE_FOLDER/.env"

echo "Setup completed successfully. You can now use the cnode.sh script to manage your Cardano relay node."

# Final sanity check
echo "Performing final sanity check..."
if [ -d "$DATA_FOLDER" ] && [ -d "$CONFIG_FOLDER" ] && [ -f "$CONFIG_FOLDER/config.json" ]; then
    echo "All required folders and files are in place."
else
    echo "Error: Please check your folder paths and downloaded files."
    exit 1
fi

# Suggest adding the cnode.sh script to PATH via .bashrc
echo "To make the 'cnode.sh' script available globally, you can add the following line to your .bashrc:"
echo "export PATH=\$PATH:$CNODE_SCRIPT_FOLDER"
echo "You can add this line manually to your ~/.bashrc or ~/.zshrc to make it permanent."
echo "To apply the changes immediately, you can run: source ~/.bashrc"
