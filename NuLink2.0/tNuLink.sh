#!/bin/bash

echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "      ___           ___           ___                         ___           ___           ___     "
echo "     /\  \         /\  \         /\__\                       /\  \         /\  \         /\  \    "
echo "     \:\  \       /::\  \       /:/  /          ___          \:\  \       /::\  \        \:\  \   "
echo "      \:\  \     /:/\:\  \     /:/  /          /\__\          \:\  \     /:/\:\__\        \:\  \  "
echo "  _____\:\  \   /:/  \:\  \   /:/  /  ___     /:/  /      ___  \:\  \   /:/ /:/  /    _____\:\  \ "
echo " /::::::::\__\ /:/__/ \:\__\ /:/__/  /\__\   /:/__/      /\  \  \:\__\ /:/_/:/__/___ /::::::::\__\""
echo " \:\~~\~~\/__/ \:\  \ /:/  / \:\  \ /:/  /  /::\  \      \:\  \ /:/  / \:\/:::::/  / \:\~~\~~\/__/"
echo "  \:\  \        \:\  /:/  /   \:\  /:/  /  /:/\:\  \      \:\  /:/  /   \::/~~/~~~~   \:\  \      "
echo "   \:\  \        \:\/:/  /     \:\/:/  /   \/__\:\  \      \:\/:/  /     \:\~~\        \:\  \     "
echo "    \:\__\        \::/  /       \::/  /         \:\__\      \::/  /       \:\__\        \:\__\    "
echo "     \/__/         \/__/         \/__/           \/__/       \/__/         \/__/         \/__/    "
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

# Function to prompt for password input with hidden input
prompt_for_password() {
    local password
    local prompt_message=$1
    while true; do
        read -s -p "$prompt_message" password
        echo
        if [ ${#password} -ge 8 ]; then
            echo "Password set."
            break
        else
            echo "Password must be at least 8 characters long. Please try again."
        fi
    done
    echo $password
}

# Prompt for NuLink keystore password and operator password
echo "Enter NuLink keystore password (min 8 characters):"
NULINK_KEYSTORE_PASSWORD=$(prompt_for_password "")

echo "Enter worker account password (min 8 characters):"
NULINK_OPERATOR_ETH_PASSWORD=$(prompt_for_password "")

# Installing and setting up Geth
sleep 2
GETH_URL="https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-1.10.23-d901d853.tar.gz"
GETH_DIR="/root/geth-linux-amd64-1.10.23-d901d853"
wget -qO- $GETH_URL | tar xvz -C /root || { echo "Failed to download and extract Geth"; exit 1; }
cd $GETH_DIR || { echo "Failed to navigate to Geth directory"; exit 1; }

# Prompting user for Geth account password manually and creating a new account
./geth account new --keystore ./keystore

# User input for public address
echo "Enter the public address of the key (with 0x prefix): "
read PUBLIC_ADDRESS

# Docker Installation and setup
sleep 2
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io

# Verifying Docker installation
docker --version || { echo "Failed to verify Docker installation"; exit 1; }

# Asking user for funding confirmation
ask_for_funding_confirmation() {
    while true; do
        read -p "Please fund your $PUBLIC_ADDRESS with testBNB, have you funded it? (Y/N): " response
        case $response in
            [Yy]* ) break;;
            [Nn]* ) echo "Waiting for funding. Please fund your account.";;
            * ) echo "Please answer Y (yes) or N (no).";;
        esac
    done
}

ask_for_funding_confirmation

# Docker run commands
sleep 2
docker run -it --rm \
-p 9151:9151 \
-v $PWD/keystore:/root/keystore \
-v $NULINK_DIR:/code \
-v $NULINK_DIR:/home/circleci/.local/share/nulink \
-e NULINK_KEYSTORE_PASSWORD=$NULINK_KEYSTORE_PASSWORD \
nulink/nulink nulink ursula init \
--signer "keystore:///root/keystore/$KEYSTORE_FILE" \
--eth-provider https://data-seed-prebsc-2-s2.binance.org:8545 \
--network horus \
--payment-provider https://data-seed-prebsc-2-s2.binance.org:8545 \
--payment-network bsc_testnet \
--operator-address $PUBLIC_ADDRESS \
--max-gas-price 10000000000 || { echo "Failed to run Docker container for initialization"; exit 1; }

docker run --restart on-failure -d \
--name ursula \
-p 9151:9151 \
-v $PWD/keystore:/root/keystore \
-v $NULINK_DIR:/code \
-v $NULINK_DIR:/home/circleci/.local/share/nulink \
-e NULINK_KEYSTORE_PASSWORD=$NULINK_KEYSTORE_PASSWORD \
-e NULINK_OPERATOR_ETH_PASSWORD=$NULINK_OPERATOR_ETH_PASSWORD \
nulink/nulink nulink ursula run --no-block-until-ready || { echo "Failed to run Docker container 'ursula'"; exit 1; }

docker logs -f ursula
