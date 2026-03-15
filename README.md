# hifz-bot

An OpenClaw skill for Quran memorization (hifz) tracking and scheduling. Sends a daily Discord message with a personalised review plan, logs sessions via natural language, and adapts over time based on your progress and weaknesses.

## What It Does

- **Morning heartbeat** — daily Discord message with pages to revise, review, and memorize, with time estimates
- **Session logging** — tell the bot what you reviewed in natural language, it updates your progress
- **Intelligent scheduling** — four-tier system (🔴 Revision, 🔵 Recent Review, 🟡 Rotation, 🟢 New) that adapts to your pace and flags weak pages
- **Arabic immersion** — greetings and encouragement in Arabic, scheduling instructions in English

---

## Repo Structure

```
hifz-bot/
  workspace/
    SOUL.md         ← agent personality and language rules
    AGENTS.md       ← emoji legend, tier rules, hard constraints
    HEARTBEAT.md    ← daily schedule trigger
  skill/
    SKILL.md        ← skill definition and routing logic
    prompts/
      heartbeat.md      ← morning schedule prompt (Claude Sonnet)
      session-log.md    ← session parsing prompt (Thaura)
      conversation.md   ← ad hoc queries prompt (Thaura)
      onboarding.md     ← initial setup prompt (Claude Sonnet)
    data/
      quran-index.json  ← Madinah mushaf surah/ayah/page mappings
  setup.sh          ← run once on a fresh VPS as root
  deploy.sh         ← copies files to correct OpenClaw locations
  .gitignore
  README.md
```

Your progress data (`hifz.json`) and bot memory (`MEMORY.md`) are
generated on the VPS and never committed to this repo. A nightly cron
job backs them up to a separate private GitHub repo so your data
survives VPS rebuilds.

---

## Prerequisites

Before setting up the VPS you need:

- A VPS running Ubuntu 24 (e.g. Hetzner, DigitalOcean, Linode)
- An SSH key pair for accessing the VPS
- An [Anthropic](https://console.anthropic.com) API key (Claude Sonnet)
- A [Thaura](https://thaura.ai) API key
- A Discord bot token — see [Discord setup](#discord-setup) below

---

## Discord Setup

Follow the [OpenClaw Discord quick setup guide](https://docs.openclaw.ai/channels/discord#quick-setup) to create your bot, configure permissions, and get your bot token.

---

## Part 1 — Local Machine Setup

### 1. Generate an SSH key

If you don't already have one:

```bash
ssh-keygen -t ed25519 -C "hifz-vps"
```

### 2. Provision a VPS

1. Create an Ubuntu 24.04 server with your VPS provider
2. Add your SSH public key during creation
3. Note the server's IP address

### 3. Verify SSH access

```bash
ssh root@YOUR_SERVER_IP
```

If you get in without typing a server password, key auth is working.
**Do not proceed until this works.**

---

## Part 2 — VPS Setup

### 4. Clone the repo and run the setup script

```bash
# SSH in as root
ssh root@YOUR_SERVER_IP

# Clone and run setup
git clone https://github.com/YOUR_USERNAME/hifz-bot.git ~/hifz-bot
cd ~/hifz-bot
chmod +x setup.sh
sudo ./setup.sh
```

The script will:

- Update the OS
- Install Node.js LTS, fail2ban, unattended-upgrades
- Create the `hifzbot` non-root user
- Copy your SSH key to the hifzbot user
- Install OpenClaw under hifzbot
- Configure UFW firewall (SSH only)
- Harden SSH (disable password auth and root login)
- Create the `.env` template

> **Alternative if you prefer not to clone as root:**
>
> ```bash
> curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/hifz-bot/master/setup.sh | sudo bash
> ```

### 5. Verify hifzbot SSH access

Before logging out of root, open a new terminal and verify:

```bash
ssh hifzbot@YOUR_SERVER_IP
```

If this works, you can safely proceed. If not:

```bash
# As root, check the key was copied
cat /home/hifzbot/.ssh/authorized_keys
```

### 6. Fill in the .env file

The setup script already creates `~/.openclaw/.env` from `.env.example`
with correct permissions. Fill in your API keys and Discord bot token:

```bash
ssh hifzbot@YOUR_SERVER_IP
vim ~/.openclaw/.env
```

Generate a gateway auth token and add it to the `.env`:

```bash
openssl rand -hex 32
```

### 7. Run OpenClaw onboarding

```bash
# As hifzbot user
openclaw onboard
```

Choose **Manual** mode during onboarding. Recommended settings:

- **Gateway bind:** Loopback (127.0.0.1)
- **Gateway auth:** Token
- **Tailscale:** Off
- **Discord:** Configure via the [Discord setup guide](https://docs.openclaw.ai/channels/discord#cli)
- **Install Gateway service:** Yes (installs a systemd service)

Disable memory search (not needed — the bot reads `MEMORY.md` and
`hifz.json` directly):

```bash
openclaw config set agents.defaults.memorySearch.enabled false
```

Verify the gateway is running:

```bash
systemctl --user status openclaw-gateway
openclaw doctor
```

---

## Part 3 — Git and Deploy

### 9. Set up a GitHub SSH key for the VPS

The VPS needs its own SSH key to push to GitHub:

```bash
# As hifzbot user
ssh-keygen -t ed25519 -C "hifz-vps-github" -f ~/.ssh/github
cat ~/.ssh/github.pub
```

Copy the output and add it to GitHub:

- GitHub → Settings → SSH and GPG Keys → New SSH Key
- Title: "Hifz VPS", paste the public key

Configure SSH to use this key for GitHub:

```bash
vim ~/.ssh/config
```

Add:

```
Host github.com
  IdentityFile ~/.ssh/github
  IdentitiesOnly yes
```

Test:

```bash
ssh -T git@github.com
```

### 10. Deploy the skill

```bash
cd ~/hifz-bot
chmod +x deploy.sh
./deploy.sh
```

This copies files to the correct OpenClaw locations:

- `workspace/*` → `~/.openclaw/workspace/`
- `skill/*` → `~/.openclaw/skills/hifz/`

Verify the skill loaded:

```bash
openclaw skills list
# Should show: hifz
```

### 11. Set up the private data repo

Create a private repo called `hifz-bot-data` on GitHub, then:

```bash
mkdir ~/hifz-bot-data
cd ~/hifz-bot-data
git init
git remote add origin git@github.com:YOUR_USERNAME/hifz-bot-data.git
```

Push an initial commit:

```bash
git commit --allow-empty -m "init"
git push -u origin master
```

OpenClaw populates `MEMORY.md` automatically during onboarding and
conversations — no need to seed it manually.

### 12. Set up the backup cron

```bash
crontab -e
```

Add:

```
0 2 * * * cd ~/hifz-bot-data && cp ~/.openclaw/skills/hifz/data/hifz.json hifz.json 2>/dev/null; cp ~/.openclaw/workspace/MEMORY.md MEMORY.md 2>/dev/null; git add . && git diff --cached --quiet || git commit -m "backup $(date +\%F)" && git push origin master
```

---

## Part 4 — First Use

### 13. Test Discord connection

Send your bot a message in Discord:

```
hello
```

If it responds, OpenClaw is running and Discord is connected.

### 14. Run hifz onboarding

```
I want to set up my hifz tracking
```

The bot guides you through mushaf edition, current progress, Juz 1
state, time budget, and scheduling preferences. At the end it
generates your `hifz.json`.

Verify it was created:

```bash
cat ~/.openclaw/skills/hifz/data/hifz.json
```

### 15. Verify the first heartbeat

To test immediately:

```bash
openclaw message send --target discord --message "run heartbeat"
```

Or wait until the next morning and check Discord for your first
automated schedule message.

---

## Deploying Updates

When you make changes locally:

```bash
# Local machine
git add .
git commit -m "describe your change"
git push origin master

# VPS (as hifzbot user)
cd ~/hifz-bot
git pull origin master
./deploy.sh
```

`deploy.sh` copies updated files and restarts OpenClaw automatically.

---

## Daily Usage

### Morning schedule

Arrives automatically via Discord at your configured heartbeat time.

### Logging a session

```
done, reviewed pages 5, 8, 12 — page 8 was weak at the transition
```

### Ad hoc questions

```
how am I doing overall?
I only have 15 minutes today, what should I prioritize?
switch to aggressive mode
skip tomorrow
```

### New memorization follow-up

```
🟢 New — following up
  Page 59: did you finish memorizing this?
```

Reply yes, no, or partially.

---

## Emoji Reference

| Emoji | Meaning                                                 |
| ----- | ------------------------------------------------------- |
| 🔴    | Revision — weak/forgotten, highest priority             |
| 🔵    | Recent Review — recently memorized, reviewed frequently |
| 🟡    | Rotation Review — established pages, cycled regularly   |
| 🟢    | New — fresh memorization                                |
| ⚠️    | Weakness flag — specific issue to watch                 |
| 🔗    | Page transition — review paired with adjacent page      |
| 👁️    | متشابه — similar ayah exists elsewhere                  |
| ✅    | Session logged                                          |
| ⏱️    | Time estimate                                           |

---

## Private Data

| File        | Location on VPS                 | Backed up        |
| ----------- | ------------------------------- | ---------------- |
| `hifz.json` | `~/.openclaw/skills/hifz/data/` | Nightly via cron |
| `MEMORY.md` | `~/.openclaw/workspace/`        | Nightly via cron |

---

## Troubleshooting

**Bot not responding on Discord**

```bash
systemctl --user status openclaw-gateway
journalctl --user -u openclaw-gateway --lines 100
openclaw doctor
```

**Heartbeat not firing**

```bash
cat ~/.openclaw/workspace/HEARTBEAT.md
systemctl --user restart openclaw-gateway
```

**Skill not found after deploy**

```bash
openclaw skills list
ls ~/.openclaw/skills/hifz/
```

**hifz.json not updating after sessions**

- Check `.env` has correct API keys
- Check logs: `journalctl --user -u openclaw-gateway --lines 100`

**Git push failing from VPS**

```bash
ssh -T git@github.com
cat ~/.ssh/config
```

**SSH key not working after VPS rebuild**

```bash
ssh-keygen -R YOUR_SERVER_IP
ssh root@YOUR_SERVER_IP
```

---

## Security Checklist

```bash
# UFW active, SSH only
sudo ufw status

# fail2ban running
sudo systemctl status fail2ban

# Password auth disabled
grep PasswordAuthentication /etc/ssh/sshd_config

# Root login disabled
grep PermitRootLogin /etc/ssh/sshd_config

# .env permissions
ls -la ~/.openclaw/.env
# Expected: -rw-------

# OpenClaw security audit
openclaw security audit
```

---

## Related

- [OpenClaw](https://openclaw.ai) — the agent framework this skill runs on
- [Thaura](https://thaura.ai) — ethical AI API used for session parsing
- [AgentSkills spec](https://agentskills.io) — skill format this follows
