#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# VPS Setup Script for hifzbot (OpenClaw-based Discord Bot)
# Target: Ubuntu 24.04 LTS — run as root
# Idempotent: safe to run multiple times
# =============================================================================

# ---------- Root check ----------
if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: This script must be run as root."
  exit 1
fi

# ---------- Pre-flight checklist ----------
echo ""
echo "============================================================"
echo "  PRE-FLIGHT CHECKLIST"
echo "============================================================"
echo ""
echo "  Before running this script, confirm you have completed:"
echo ""
echo "  [ ] 1. Generated an Ed25519 SSH key pair"
echo ""
echo "  [ ] 2. Added your public key to the VPS during creation"
echo ""
echo "  [ ] 3. Verified you can SSH into this server RIGHT NOW"
echo "         using your key (run: ssh root@this-server-ip)"
echo ""
read -rp "Have you completed ALL of the above? [y/N] " confirm
if [[ "${confirm,,}" != "y" ]]; then
  echo ""
  echo "Please complete the checklist above before running this script."
  echo "Exiting."
  exit 1
fi

echo ""

# ---------- Helper ----------
section() {
  echo ""
  echo "============================================================"
  echo "  $1"
  echo "============================================================"
  echo ""
}

# ==========================================================================
# 1. System update
# ==========================================================================
section "1/13  Updating system packages"
apt-get update -y
apt-get upgrade -y

# ==========================================================================
# 2. Install required packages
# ==========================================================================
section "2/13  Installing required packages"
apt-get install -y curl git ufw fail2ban unattended-upgrades

# ==========================================================================
# 3. Install Node.js LTS (22.x)
# ==========================================================================
section "3/13  Installing Node.js 22 LTS"

if command -v node &>/dev/null; then
  NODE_MAJOR=$(node --version | sed 's/v\([0-9]*\).*/\1/')
  if [[ "$NODE_MAJOR" -ge 22 ]]; then
    echo "Node.js $(node --version) already installed — skipping."
  else
    echo "Node.js $(node --version) is too old — upgrading to 22.x..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get install -y nodejs
  fi
else
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi

echo "Node: $(node --version)  npm: $(npm --version)"

# ==========================================================================
# 4. Create non-root user: hifzbot
# ==========================================================================
section "4/13  Creating hifzbot user"

if id "hifzbot" &>/dev/null; then
  echo "User hifzbot already exists — skipping creation."
else
  adduser --disabled-password --gecos "" hifzbot
  echo "User hifzbot created."
fi

# Copy SSH authorized_keys so the same key works for hifzbot
mkdir -p /home/hifzbot/.ssh
cp /root/.ssh/authorized_keys /home/hifzbot/.ssh/authorized_keys
chown -R hifzbot:hifzbot /home/hifzbot/.ssh
chmod 700 /home/hifzbot/.ssh
chmod 600 /home/hifzbot/.ssh/authorized_keys
echo "SSH keys copied to hifzbot."

# ==========================================================================
# 5. Create swap (prevents OOM on small VPS during npm install)
# ==========================================================================
section "5/13  Checking swap"

TOTAL_RAM_MB=$(awk '/MemTotal/ {printf "%d", $2 / 1024}' /proc/meminfo)

if [[ "$TOTAL_RAM_MB" -ge 2048 ]]; then
  echo "RAM is ${TOTAL_RAM_MB}MB — swap not needed, skipping."
elif swapon --show | grep -q '/swapfile'; then
  echo "Swap already active — skipping."
else
  echo "RAM is ${TOTAL_RAM_MB}MB — creating 2GB swap to avoid OOM during npm install..."
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  if ! grep -q '/swapfile' /etc/fstab; then
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
  fi
  echo "2GB swap created and enabled."
fi

# ==========================================================================
# 6. Install OpenClaw
# ==========================================================================
section "6/13  Installing OpenClaw"

if sudo -u hifzbot bash -c 'command -v openclaw' &>/dev/null; then
  echo "OpenClaw already installed — skipping."
else
  sudo -u hifzbot bash -c 'curl -fsSL https://openclaw.ai/install.sh | bash'
fi

echo ""
echo "NOTE: Do NOT run 'openclaw onboard' now — it requires"
echo "interactive input and must be done manually after this script."

# ==========================================================================
# 6. Configure UFW firewall
# ==========================================================================
section "7/13  Configuring UFW firewall"

ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH

# Enable non-interactively (idempotent)
yes | ufw enable || true

ufw status verbose

# ==========================================================================
# 7. Configure fail2ban
# ==========================================================================
section "8/13  Configuring fail2ban"

systemctl enable fail2ban
systemctl start fail2ban
echo "fail2ban is active — SSH protection enabled by default."

# ==========================================================================
# 8. Configure automatic security updates
# ==========================================================================
section "9/13  Configuring unattended-upgrades"

cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

cat >/etc/apt/apt.conf.d/50unattended-upgrades <<'EOCONF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
EOCONF

systemctl enable unattended-upgrades
systemctl restart unattended-upgrades
echo "Automatic security updates enabled."

# ==========================================================================
# 9. Harden SSH
# ==========================================================================
section "10/13  Hardening SSH configuration"

SSHD_CONFIG="/etc/ssh/sshd_config"

# Disable password authentication
if grep -q "^PasswordAuthentication" "$SSHD_CONFIG"; then
  sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
else
  echo "PasswordAuthentication no" >>"$SSHD_CONFIG"
fi

# Disable root login
if grep -q "^PermitRootLogin" "$SSHD_CONFIG"; then
  sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
else
  echo "PermitRootLogin no" >>"$SSHD_CONFIG"
fi

# Drop-in to ensure settings aren't overridden
mkdir -p /etc/ssh/sshd_config.d
cat >/etc/ssh/sshd_config.d/99-hardening.conf <<'EOF'
PasswordAuthentication no
PermitRootLogin no
EOF

systemctl reload ssh || systemctl reload sshd
echo "SSH hardened: password auth disabled, root login disabled."

# ==========================================================================
# 10. Create skill directory structure
# ==========================================================================
section "11/13  Creating skill directory structure"

SKILL_DIR="/home/hifzbot/openclaw-skills/hifz"

mkdir -p "${SKILL_DIR}/prompts"
mkdir -p "${SKILL_DIR}/data"

# Write .env template only if it doesn't already exist
ENV_DIR="/home/hifzbot/.openclaw"
ENV_FILE="${ENV_DIR}/.env"
REPO_DIR="/home/hifzbot/hifz-bot"
mkdir -p "${ENV_DIR}"

if [[ ! -f "${ENV_FILE}" ]]; then
  cp "${REPO_DIR}/.env.example" "${ENV_FILE}"
  echo ".env template created."
else
  echo ".env already exists — not overwriting."
fi

# ==========================================================================
# 11. Set file permissions
# ==========================================================================
section "12/13  Setting file permissions"

chown -R hifzbot:hifzbot /home/hifzbot/openclaw-skills
chown -R hifzbot:hifzbot "${ENV_DIR}"
chmod 600 "${ENV_FILE}"
chmod 700 "${SKILL_DIR}/data"

echo "Permissions set."

# ==========================================================================
# 12. Final summary
# ==========================================================================
section "13/13  Setup complete!"

echo "  Next steps (do these manually in order):"
echo ""
echo "  1. Open a new terminal and verify hifzbot SSH works:"
echo "       ssh hifzbot@your-server-ip"
echo ""
echo "  2. Fill in your API keys:"
echo "       vim /home/hifzbot/.openclaw/.env"
echo ""
echo "  3. Switch to hifzbot and run OpenClaw onboarding:"
echo "       su - hifzbot"
echo "       openclaw onboard --install-daemon"
echo "       (connect Discord as a channel during this step)"
echo ""
echo "  4. Generate a GitHub SSH key for the VPS:"
echo "       ssh-keygen -t ed25519 -C hifz-vps-github -f ~/.ssh/github"
echo "       cat ~/.ssh/github.pub"
echo "       (add the output to GitHub → Settings → SSH Keys)"
echo ""
echo "  5. Clone the repo and deploy skill files:"
echo "       git clone git@github.com:YOUR_USERNAME/hifz-bot.git ~/hifz-bot"
echo "       cd ~/hifz-bot && chmod +x deploy.sh && ./deploy.sh"
echo ""
echo "  6. Start OpenClaw with pm2:"
echo "       pm2 start openclaw --name hifzbot"
echo "       pm2 save"
echo "       pm2 startup"
echo "       (run the command pm2 startup prints as root)"
echo ""
echo "  7. Set up the private data repo:"
echo "       mkdir ~/hifz-bot-data && cd ~/hifz-bot-data"
echo "       git init"
echo "       git remote add origin git@github.com:YOUR_USERNAME/hifz-bot-data.git"
echo ""
echo "  8. Set up the backup cron:"
echo "       crontab -e"
echo "       (add the nightly backup line from the README)"
echo ""
echo "  9. Test in Discord — send your bot: hello"
echo ""
echo " 10. Run hifz onboarding in Discord:"
echo "       I want to set up my hifz tracking"
echo ""
echo "============================================================"
echo "  All done. Your server is hardened and ready."
echo "============================================================"
echo ""
