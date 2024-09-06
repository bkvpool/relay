#!/bin/bash

# Define the Docker Compose file path (adjust if your file is in a different directory)
COMPOSE_FILE_PATH="$HOME/relay/docker-compose.yml"
# Define the container name
CONTAINER_NAME="cardano-node"

start_container() {
    # Check if the Docker Compose file exists
    if [ -f "$COMPOSE_FILE_PATH" ]; then
        echo "Starting the Cardano node container using Docker Compose..."
        # Start the container
        docker compose -f $COMPOSE_FILE_PATH up -d
        echo "Cardano node container started."
    else
        echo "Docker Compose file not found at $COMPOSE_FILE_PATH"
    fi
}

stop_container() {
    # Check if the Docker Compose file exists
    if [ -f "$COMPOSE_FILE_PATH" ]; then
        echo "Stopping the Cardano node container using Docker Compose..."
        # Stop the container
        docker compose -f $COMPOSE_FILE_PATH down
        echo "Cardano node container stopped."
    else
        echo "Docker Compose file not found at $COMPOSE_FILE_PATH"
    fi
}

check_status() {
    # Check if the container is running
    if [ "$(docker ps -q -f name=${CONTAINER_NAME})" ]; then
        echo "Container ${CONTAINER_NAME} is running."
        docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}" -f name=${CONTAINER_NAME}
    else
        echo "Container ${CONTAINER_NAME} is not running."
    fi
}

fetch_logs() {
    # Check if the container is running
    if [ "$(docker ps -q -f name=${CONTAINER_NAME})" ]; then
        echo "Fetching logs for container: ${CONTAINER_NAME}"
        # Display the logs
        docker logs -f --tail 100 ${CONTAINER_NAME}
    else
        echo "Container ${CONTAINER_NAME} is not running."
    fi
}

check_size() {
    # Check if the container exists
    if [ "$(docker ps -a -q -f name=${CONTAINER_NAME})" ]; then
        # Display the container name and size
        docker ps -s --format "table {{.Names}}\t{{.Size}}" -f name=${CONTAINER_NAME}

        # Get the size of all files in the /opt/cardano/data directory in the container
        data_size=$(docker exec ${CONTAINER_NAME} du -sh /opt/cardano/data | awk '{print $1}')

        # Display the node data size
        echo "Node size: ${data_size}"

        # Get the free space on the host machine
        free_space=$(df -h / | awk 'NR==2 {print $4}')

        # Display the free space on the host machine
        echo "Free space: ${free_space}"
    else
        echo "Container ${CONTAINER_NAME} does not exist."
    fi
}

login_container() {
    # Check if the container is running
    if [ "$(docker ps -q -f name=${CONTAINER_NAME})" ]; then
        echo "Logging into the Cardano node container..."
        # Execute a shell inside the container
        docker exec -it ${CONTAINER_NAME} /bin/bash
    else
        echo "Container ${CONTAINER_NAME} is not running."
    fi
}

syncstatus() {
    # Check if the container is running
    if [ "$(docker ps -q -f name=${CONTAINER_NAME})" ]; then
        # Execute the cardano-cli command inside the container and capture the output
        output=$(docker exec ${CONTAINER_NAME} cardano-cli query tip --mainnet --socket-path /opt/cardano/ipc/socket)

        # Parse the JSON output
        block=$(echo $output | jq -r '.block')
        epoch=$(echo $output | jq -r '.epoch')
        syncProgress=$(echo $output | jq -r '.syncProgress')

        # Output in a pretty format with colors
        echo -e "Sync Status:"
        echo -e "Block: \e[94m$block\e[0m"
        echo -e "Epoch: \e[32m$epoch\e[0m"
        echo -e "Sync Progress: \e[33m$syncProgress%\e[0m"
    else
        echo "Container ${CONTAINER_NAME} is not running."
    fi
}

view() {
    # Check if the container is running
    if [ "$(docker ps -q -f name=${CONTAINER_NAME})" ]; then
        # Check if gLiveView.sh script exists
        if docker exec ${CONTAINER_NAME} [ -f /root/gLiveView.sh ]; then
            echo "gLiveView.sh script exists. Running the script..."
            docker exec -it ${CONTAINER_NAME} /bin/bash -c "cd /root && ./gLiveView.sh"
        else
            echo "gLiveView.sh script does not exist. Downloading and setting up..."
            docker exec -it ${CONTAINER_NAME} /bin/bash -c "cd /root && mkdir -p logs && curl -s -o gLiveView.sh https://raw.githubusercontent.com/cardano-community/guild-operators/master/scripts/cnode-helper-scripts/gLiveView.sh && curl -s -o env https://raw.githubusercontent.com/cardano-community/guild-operators/master/scripts/cnode-helper-scripts/env && chmod 755 gLiveView.sh && sed -i '1a CNODE_PORT=3001\nCONFIG=\"/opt/cardano/config/mainnet/config.json\"\nSOCKET=\"/opt/cardano/ipc/socket\"\nLOG_DIR=\"/root/logs\"' env && ./gLiveView.sh"
        fi
    else
        echo "Container ${CONTAINER_NAME} is not running."
    fi
}

version() {
    # Check if the container is running
    if [ "$(docker ps -q -f name=${CONTAINER_NAME})" ]; then
        # Get the version of cardano-node and cardano-cli
        docker exec ${CONTAINER_NAME} cardano-node version
        docker exec ${CONTAINER_NAME} cardano-cli version
    else
        echo "Container ${CONTAINER_NAME} is not running."
    fi
}

upgrade_container() {
    # Check if the Docker Compose file exists
    if [ -f "$COMPOSE_FILE_PATH" ]; then
        # Check if the container is running
        if [ "$(docker ps -q -f name=${CONTAINER_NAME})" ]; then
            echo "The Cardano node container is currently running. Please stop it manually before upgrading."
            exit 1
        fi

        echo "Removing old Docker containers for the Cardano node..."
        # Remove the old Docker containers associated with the current Docker Compose configuration
        docker compose -f $COMPOSE_FILE_PATH rm -f

        echo "Removing old Docker images for the Cardano node..."
        # Remove the old Docker images associated with the current Docker Compose configuration
        images=$(docker images --filter=reference="ghcr.io/blinklabs-io/cardano-node" -q)
        if [ -n "$images" ]; then
            docker rmi -f $images
        fi

        echo "Pulling the latest Docker images..."
        # Pull the latest Docker images
        docker compose -f $COMPOSE_FILE_PATH pull

        echo "Docker images upgraded. You can now start the container manually."
    else
        echo "Docker Compose file not found at $COMPOSE_FILE_PATH"
    fi
}

# Check for command line arguments
case "$1" in
    start)
        start_container
        ;;
    stop)
        stop_container
        ;;
    status)
        check_status
        ;;
    logs)
        fetch_logs
        ;;
    size)
        check_size
        ;;
    cli)
        login_container
        ;;
    syncstatus)
        syncstatus
        ;;
    view)
        view
        ;;
    version)
        version
        ;;
    upgrade)
        upgrade_container
        ;;
    *)
        echo "Usage: $0 {start|stop|status|logs|size|cli|syncstatus|view|version|upgrade}"
        ;;
esac
