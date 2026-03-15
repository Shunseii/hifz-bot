#!/bin/bash
set -euo pipefail

echo "Deploying workspace files..."
cp workspace/* ~/.openclaw/workspace/

echo "Deploying skill files..."
mkdir -p ~/.openclaw/skills/hifz
cp skill/SKILL.md ~/.openclaw/skills/hifz/
cp -r skill/prompts ~/.openclaw/skills/hifz/
cp -r skill/data ~/.openclaw/skills/hifz/

echo "Disabling heartbeat..."
openclaw config set agents.defaults.heartbeat.every "0m"

echo "Restarting OpenClaw..."
systemctl --user restart openclaw-gateway

echo "Done."
