#!/bin/bash
set -euo pipefail

echo "Deploying workspace files..."
cp workspace/* ~/.openclaw/workspace/

echo "Deploying skill files..."
mkdir -p ~/.openclaw/skills/hifz
cp skill/SKILL.md ~/.openclaw/skills/hifz/
cp -r skill/prompts ~/.openclaw/skills/hifz/
cp -r skill/data ~/.openclaw/skills/hifz/

echo "Restarting OpenClaw..."
pm2 restart hifzbot

echo "Done."
