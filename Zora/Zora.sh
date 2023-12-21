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

read -p "Enter your Alchemy HTTPS URL: " userHttps

sleep 2

echo -e "\e[1m\e[32m1. Update System... \e[0m" && sleep 1
sudo sudo apt-get update && sudo apt-get upgrade -y

echo -e "\e[1m\e[32m2. Install Essential... \e[0m" && sleep 1
sudo apt install curl build-essential git screen jq pkg-config libssl-dev libclang-dev ca-certificates gnupg lsb-release -y
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg && 
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && sudo apt-get update


echo -e "\e[1m\e[32m3. Install Dependencies.... \e[0m" && sleep 1
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose -y

echo -e "\e[1m\e[32m4. Repository Set up.... \e[0m" && sleep 1
git clone https://github.com/conduitxyz/node.git && cd node
echo -e "\e[1m\e[32m5. Installing docker.... \e[0m" && sleep 1
./download-config.py zora-mainnet-0 && export CONDUIT_NETWORK=zora-mainnet-0 && cp .env.example .env && rm .env

echo "OP_NODE_L1_ETH_RPC=\"$userHttps\"" | sudo tee -a .env

echo -e "\e[1m\e[32m6. Build.... \e[0m" && sleep 1
screen -dmS log bash -c 'docker compose up --build'
