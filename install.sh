#!/usr/bin/env bash
set -e

LINUX_USER="${SUDO_USER:-ubuntu}"

echo ">>> Updating system packages..."
sudo apt-get update -y
sudo apt-get upgrade -y

echo ">>> Installing basic utilities..."
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    unzip \
    vim

# 1) Install Docker Engine
echo ">>> Setting up Docker repository..."

# Remove older docker if any
sudo apt-get remove -y docker docker-engine docker.io containerd runc || true

# Add Docker’s official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
fi
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources
UBUNTU_CODENAME=$(lsb_release -cs)
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  ${UBUNTU_CODENAME} stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo ">>> Installing Docker Engine + CLI + containerd..."
sudo apt-get update -y
sudo apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

echo ">>> Enabling and starting Docker service..."
sudo systemctl enable docker
sudo systemctl start docker

echo ">>> Adding user '$LINUX_USER' to docker group (no sudo for docker)..."
sudo usermod -aG docker "$LINUX_USER" || true

# 2) Install Docker Compose (optional standalone binary)
echo ">>> Installing standalone docker-compose (optional)..."
DOCKER_COMPOSE_VERSION="v2.29.7"
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 3) Install Java (for Spring Boot microservices)
echo ">>> Installing OpenJDK 17..."
sudo apt-get install -y openjdk-17-jdk

# Set JAVA_HOME (for current shell and future logins)
JAVA_HOME_PATH=$(dirname $(dirname $(readlink -f $(which javac))))
if ! grep -q "JAVA_HOME" /etc/environment; then
  echo "JAVA_HOME=${JAVA_HOME_PATH}" | sudo tee -a /etc/environment
fi
export JAVA_HOME="${JAVA_HOME_PATH}"

# 4) Install Maven (if you build microservices on EC2)
echo ">>> Installing Maven..."
sudo apt-get install -y maven

# 5) Install Node.js + npm (for Frontend build)
echo ">>> Installing Node.js (LTS) using NodeSource..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

echo ">>> Node & npm versions:"
node -v || true
npm -v || true

# 6) Verify installations
echo ">>> Verifying installed versions..."
echo "Docker version:"
docker --version || true

echo "Docker Compose (plugin) version:"
docker compose version || true

echo "Standalone docker-compose version:"
docker-compose --version || true

echo "Java version:"
java -version || true

echo "Maven version:"
mvn -v || true

echo "Git version:"
git --version || true

echo ">>> Setup complete!"
echo "IMPORTANT: log out and log back in (or run 'newgrp docker') to use docker without sudo."
