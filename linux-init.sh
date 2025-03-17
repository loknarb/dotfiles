#!/bin/bash

# WSL Setup Script
# This script handles the installation of essential tools and configuration for WSL Ubuntu

# Exit on error
set -e

# Function to display status messages
display_status() {
    echo -e "\e[1;34m>>> $1\e[0m"
}

# Function to handle errors
handle_error() {
    echo -e "\e[1;31mError: $1\e[0m"
    exit 1
}

# Prompt for username
read -p "Enter username for your Ubuntu environment: " USERNAME

# Create the user if it doesn't exist
if ! id -u "$USERNAME" &>/dev/null; then
    display_status "Creating user $USERNAME"
    sudo useradd -m -s /bin/bash -G sudo "$USERNAME"
    sudo passwd "$USERNAME"
    
    # Make the new user the default user for this WSL distribution
    echo -e '[user]\ndefault='$USERNAME | sudo tee -a /etc/wsl.conf
else
    display_status "User $USERNAME already exists"
fi

# Switch to the user's home directory
USER_HOME="/home/$USERNAME"
cd "$USER_HOME" || handle_error "Failed to change to user's home directory"

# Clone dotfiles repo if it doesn't exist
if [ ! -d "$USER_HOME/dotfiles" ]; then
    display_status "Cloning dotfiles repository"
    git clone https://github.com/loknarb/dotfiles "$USER_HOME/dotfiles"
    chown -R "$USERNAME:$USERNAME" "$USER_HOME/dotfiles"
fi

# Install essential packages
display_status "Installing essential packages"
sudo apt update
sudo apt install -y git curl zsh

# Install Oh My Zsh
if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
    display_status "Installing Oh My Zsh"
    sudo -u "$USERNAME" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Install Powerlevel10k theme
if [ ! -d "$USER_HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
    display_status "Installing Powerlevel10k theme"
    sudo -u "$USERNAME" git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$USER_HOME/.oh-my-zsh/custom/themes/powerlevel10k"
fi

# Install Zsh plugins
display_status "Installing Zsh plugins"
if [ ! -d "$USER_HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
    sudo -u "$USERNAME" git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$USER_HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
fi

if [ ! -d "$USER_HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
    sudo -u "$USERNAME" git clone https://github.com/zsh-users/zsh-autosuggestions "$USER_HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
fi

# Install LazyGit
display_status "Installing LazyGit"
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -o -E 'tag_name": "v(.*)",' | sed 's/tag_name": "v//;s/",//')
curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf /tmp/lazygit.tar.gz -C /tmp
sudo install /tmp/lazygit -D -t /usr/local/bin
rm /tmp/lazygit.tar.gz

# Install other helpful tools
display_status "Installing additional tools"
sudo apt install -y lf ripgrep bat
sudo ln -sf /usr/bin/batcat /usr/local/bin/bat
sudo chmod +x /usr/local/bin/bat

# Install nvm
display_status "Installing nvm"
if [ ! -d "$USER_HOME/.nvm" ]; then
    sudo -u "$USERNAME" curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi

# Create symlinks for configuration files
display_status "Creating symlinks for configuration files"
sudo -u "$USERNAME" bash -c "
    ln -sf ~/dotfiles/.gitconfig ~/.gitconfig
    ln -sf ~/dotfiles/.gitconfig-work ~/.gitconfig-work
    ln -sf ~/dotfiles/.gitconfig-personal ~/.gitconfig-personal
    ln -sf ~/dotfiles/.zshrc ~/.zshrc
    mkdir -p ~/.config/lf
    ln -sf ~/dotfiles/lfrc ~/.config/lf/lfrc
    ln -sf ~/dotfiles/.tmux.conf ~/.tmux.conf
"

# Install fzf
display_status "Installing fzf"
if [ ! -d "$USER_HOME/.fzf" ]; then
    sudo -u "$USERNAME" git clone --depth 1 https://github.com/junegunn/fzf.git "$USER_HOME/.fzf"
    sudo -u "$USERNAME" bash -c "$USER_HOME/.fzf/install --all"
fi

# Create work and personal directories
display_status "Creating work and personal directories"
sudo -u "$USERNAME" mkdir -p "$USER_HOME/work" "$USER_HOME/personal"

display_status "WSL setup completed successfully!"
echo "You can now run 'wsl -d Ubuntu-24.04 -u $USERNAME' to log in as your new user."