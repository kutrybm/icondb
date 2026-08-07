# icondb3

> BMAD v6 workspace for creating product documentation

**Welcome!** This workspace enables the BMAD v6 framework. Created by the Internal Developer Platform Team (IDP).

---

## Table of Contents

1. [What Was Set Up For You](#what-was-set-up-for-you)
2. [Getting Started (First 10 Minutes)](#getting-started-first-10-minutes)
3. [AI Agents - Your Virtual Team](#ai-agents---your-virtual-team)
4. [Saving Your Work](#saving-your-work)
5. [Codespaces vs Local Development](#codespaces-vs-local-development)
6. [What is BMAD?](#what-is-bmad)
7. [Connect to Jira & Confluence](#connect-to-jira--confluence-recommended-if-your-team-uses-jira)
8. [Understanding This Workspace](#understanding-this-workspace)
9. [How Files Are Organised](#how-files-are-organised)
10. [Troubleshooting](#troubleshooting)
11. [Common Questions](#common-questions)

---

## What Was Set Up For You

| What | Details |
|------|---------|
| **GitHub repository** | `https://github.com/procter-gamble/icondb3` |
| **Backstage catalog entry** | [`icondb3-bmad`](https://idp.pg.com/catalog/default/component/icondb3-bmad) - find your component in the IDP portal |
| **Codespace access** | Enabled for your team (`IDPG-eng-AINativeArtwork`) - any member can launch the workspace |
| **BMAD v6 agents** | 9 AI personas: John (PM), Mary (Analyst), Sally (UX), Winston (Architect), Amelia (Dev), Quinn (QA), Barry (Quick Dev), Bob (SM), Paige (Writer) |

**Timing:** First Codespace launch takes ~30 seconds (one-time setup). Subsequent launches take ~15 seconds.

---

## Getting Started (First 10 Minutes)

### Step 1: Open Copilot Chat

Click the 💬 chat icon in the right sidebar (or top-right corner next to the search bar).

**💡 Tip:** Expand the chat panel using the **(⇄)** button for better visibility.

### Step 2: Select the Claude Model

Click the model selection button and select the latest Claude model available.

### Step 3: Talk Naturally

BMAD v6 uses natural language — just say what you need:

| What You Want | What to Say |
|---------------|-------------|
| Create a PRD | "lets create a product requirements document" |
| Business analysis | "talk to Mary about my product idea" |
| Get guidance | "what should I do next" |
| UX planning | "talk to Sally about the user experience" |
| Architecture | "talk to Winston about the technical design" |
| Sprint planning | "talk to Bob about sprint planning" |
| QA tests | "talk to Quinn about testing" |

### Step 4: Follow the Agent's Lead

Just answer naturally! The agent will ask questions and write the PRD for you.

Your documents are saved automatically to `_bmad-output/planning-artifacts/` (for PRDs, briefs, architecture docs) or `_bmad-output/implementation-artifacts/` (for stories, sprint plans).

### Step 5: Save to Git

When you're ready to back up your work permanently, tell Copilot:

```
Save my changes and push to Git
```

Copilot will handle all the technical steps for you.

### ✅ Done!

Your PRD is automatically saved in `_bmad-output/planning-artifacts/` folder.

---

## AI Agents - Your Virtual Team

BMAD v6 provides **9 named AI agent personas**. You invoke them by speaking naturally — no special commands needed.

### 📋 John - Product Manager (Great starting point!)

**Use for:** PRDs, product strategy, user stories, epics
**How to use:** Say "talk to John" or "create a PRD"

### 📊 Mary - Business Analyst

**Use for:** Business analysis, requirements gathering, project briefs
**How to use:** Say "talk to Mary" or "do business analysis"

### 🎨 Sally - UX Designer

**Use for:** UX planning, user flows, wireframe guidance
**How to use:** Say "talk to Sally" or "plan the UX"

### 🏗️ Winston - Architect

**Use for:** Technical architecture, system design, technology decisions
**How to use:** Say "talk to Winston" or "create architecture"

### 💻 Amelia - Developer

**Use for:** Implementation, code, technical details
**How to use:** Say "talk to Amelia" or "dev this story"

### 🧪 Quinn - QA Engineer

**Use for:** Test plans, quality reviews, risk assessment
**How to use:** Say "talk to Quinn" or "create QA tests"

### ⚡ Barry - Quick Flow Developer

**Use for:** Rapid prototyping, quick development tasks
**How to use:** Say "talk to Barry" or "quick dev this"

### 📅 Bob - Scrum Master

**Use for:** Sprint planning, backlog management, ceremonies
**How to use:** Say "talk to Bob" or "run sprint planning"

### ✍️ Paige - Tech Writer

**Use for:** Documentation, guides, technical writing
**How to use:** Say "talk to Paige" or "help me document"

---

## Saving Your Work

### How Your Work is Saved

**Automatic Saving:**
- ✅ Your files **auto-save** every few seconds in your Codespace
- ✅ Changes are kept in your browser session
- ⚠️ **Important:** If you delete your Codespace, work that hasn't been backed up to Git will be lost

### Backing Up Your Work (Push to Git)

**What is Git?** Think of Git as a cloud backup system where your work is permanently stored and your team can see it.

**When you're ready to save and share:**

In Copilot Chat, type:
```
Save my changes and push to Git
```

**What happens:**
1. Copilot will ask for a description (e.g., "Created mobile checkout PRD")
2. It runs ONE command that saves everything (adds, commits, and pushes)
3. Your work is now backed up and visible to your team in the **remote repository** (GitHub)

**💡 Think of it like:**
- **Auto-save** = Saving to your local computer
- **Push to Git** = Uploading to Google Drive so others can see it and it's permanently backed up

---

## Codespaces vs Local Development

### GitHub Codespaces (recommended)

Codespaces is the recommended way to use this workspace:

- **Zero setup** - the devcontainer builds the full environment automatically (Node.js, npm, BMAD agents, extensions)
- **Nothing to install** on your local machine
- **First launch:** ~30 sec (one-time setup). **Subsequent launches:** ~15 sec

To launch: go to your repository on GitHub → click **Code** → **Codespaces** → **Create codespace on main**, or use the **"Open in Codespaces"** link from the IDP portal.

### Local Development

To work locally, here's what you need:

**Prerequisites:** Git, Node.js 22+, npm, just, VS Code with the GitHub Copilot and GitHub Copilot Chat extensions

**Setup steps:**
1. Clone the repo: `git clone https://github.com/procter-gamble/icondb3`
2. Open the folder in VS Code
3. Install the recommended VS Code extensions manually (see `.devcontainer/devcontainer.json` for the full list used in Codespaces)
4. Run the setup scripts:
   ```bash
   bash .devcontainer/setup-bmad.sh
   bash .devcontainer/setup-mcp.sh
   ```
5. Set up Jira: run `just jira` in the terminal and follow the prompts (same as Codespaces)

> When in doubt, refer to the [BMAD Onboarding Guide](https://sites.idp.pg.com/bmad-onboarding-instructions-idp/).

---

## What is BMAD?

**BMAD** (specifically **BMAD Method**) is an AI-powered agile development framework that adapts to your project's complexity. It uses specialised AI agents and guided workflows to help you plan and document products professionally.

**What makes it special:**
- **Scale-Adaptive** - Automatically adjusts from small features to enterprise projects
- **9 AI Agents** - Specialised assistants (PM, Analyst, UX, Architect, Developer, QA, Quick Dev, Scrum Master, Tech Writer) guide you
- **Skill-Based** - Copilot auto-discovers 43 skills and routes your requests naturally
- **No technical skills required** - Designed for Product Managers to create professional documentation

This workspace is configured with BMAD Method v6's full agent suite to help you create PRDs, architecture docs, stories, and more.

---

## Connect to Jira & Confluence (Recommended if your team uses Jira)

**Does your team track work in Jira or Confluence?** Connecting Jira & Confluence to this workspace lets Copilot create issues, update tickets, and sync your PRDs with Jira — all through simple conversation.

### 🎯 Why Connect Jira?

Once connected, you can ask Copilot to:
- *"Create a Jira issue for this PRD"*
- *"Show me my open Jira issues"*
- *"Create a Confluence document"*
- *"Update ticket ABC-123 with these acceptance criteria"*
- *"Create an epic in Jira from this PRD"*

**No Jira or Confluence commands to memorise** — just talk to Copilot naturally and it handles the integration for you!

### ⚡ Quick Setup (2-3 minutes)

First, you'll need to open the **Terminal** (a text-based command window) to run the setup.

**📟 What is the Terminal?**

The **Terminal** is where you type commands. It appears as a dark panel at the bottom of VS Code.

**How to open it:**
- Press `Ctrl+Shift+C` (or click the hamburger menu ☰ in top-left → **Terminal** → **New Terminal**)

**Now let's set up Jira:**

**Step 1:**

In the Terminal, type this and press Enter:
```bash
just jira
```

**What happens next:**

1. **The setup wizard will ask for your Atlassian email**
   - Type the email you use to log into Jira or Confluence
   - Press Enter

2. **A browser window will open automatically** to create an API token
   - Log into Atlassian if needed
   - Click **"Create API token"**
   - Give it a name like "BMAD Workspace"
   - Set expiration to **90 days** (recommended)
   - Copy the token (it looks like a long random string)

3. **Back in the Terminal, paste your API token**
   - Right-click in Terminal → Paste (or `Ctrl+V` / `Cmd+V`)
   - Press Enter

4. **Refresh the VS Code window to activate the connection**
   - Press `F1` or `Ctrl+Shift+P` (Windows) / `Cmd+Shift+P` (Mac)
   - Type "reload" and select **"Developer: Reload Window"**
   - Or simply close and reopen this browser tab

**✅ That's it!** After the reload, the Jira & Confluence connection is active and ready to use.

### ❓ Jira Setup Questions

**"What if I don't use Jira?"**
- Skip this entirely! Everything else works perfectly without Jira.

**"My API token expired - how do I update it?"**
- Just run `just jira` again in the Terminal
- Create a new token and paste it in

**"I made a mistake during setup"**
- No problem! Type Ctrl+C to stop the process and run `just jira` again to reconfigure

**"What is an API token?"**
- It's a secure password that lets this workspace talk to Jira
- Only you can see it, and it only works for Jira access

---

## Understanding This Workspace

### 📍 What is VS Code?
**VS Code** is a text editor — think of it like Microsoft Word, but designed for creating structured documents and code. You're using it in your **browser** through a **Codespace** (a cloud-based workspace).

### 💬 What is Copilot Chat?
**Copilot Chat** is your AI-powered assistant — think of it as an experienced team sitting next to you. Find it by clicking the 💬 icon in the **top right corner** next to the search bar.

**What it does:**
- Answers your questions in plain language
- Helps you write PRDs, user stories, and epics
- Teaches you VS Code and Git as you work
- Guides you step-by-step through any task
- Connects you to 9 specialist agent personas

---

## How Files Are Organised

```
docs/                           ← Your project knowledge folder (research, specs, reference docs)
_bmad-output/
  ├── planning-artifacts/       ← PRDs, briefs, architecture docs go here
  └── implementation-artifacts/ ← User stories, sprint plans go here
```

**The `docs/` folder** is your **project knowledge folder**. Add any reference documents here — research, competitive analysis, existing specs, design files, or anything you want the AI agents to have context on. When you talk to an agent, it can read files from `docs/` to give you better, more informed responses.

**Finding files:**
- **File Explorer** — Click the 📄 icon in left sidebar to browse folders
- **Quick Search** — Press `Ctrl+P` (Windows) or `Cmd+P` (Mac), then type the filename

### How to Share for Team Review

**Create a Pull Request (PR):**

Type in chat: *"Create a pull request"* or *"Share this for review"*

Copilot will:
1. Create a PR with your changes
2. Provide a link you can share with your team
3. Team members can comment and approve

---

## Troubleshooting

**Codespace won't start or is very slow**
- From GitHub, go to your repo → **Code** → **Codespaces**, stop the existing Codespace, and create a new one

**Agent gives unexpected results**
- Make sure you're using the latest Claude model (click the model picker)
- Try being more specific: "talk to John about creating a PRD" instead of just "help"

**Jira token expired or connection stopped working**
- Run `just jira` in the Terminal, create a new API token, and reload the window

**BMAD seems outdated**
- Run `just update-bmad` in the Terminal to check for and apply updates

**Pre-commit hook is blocking my commit**
- Read the error — it will tell you exactly what to fix (usually a large file or formatting)
- Fix the issue and commit again, or bypass once with `git commit --no-verify`

**For platform or infrastructure issues** (IDP portal errors, Codespace quota, repo access):
- [BMAD Onboarding Guide](https://sites.idp.pg.com/bmad-onboarding-instructions-idp/) — detailed walkthroughs
- **Support button** (bottom-right corner of the IDP portal) — raise a support request

---

## Common Questions

**"Where do my files go?"**
- PRDs and planning docs are saved in `_bmad-output/planning-artifacts/`
- User stories go in `_bmad-output/implementation-artifacts/`
- Check the left sidebar (📄 icon) to browse all files

**"How do I find a file?"**
- Press `Ctrl+P` (Windows) or `Cmd+P` (Mac)
- Start typing the filename
- Press Enter when you see it

**"How do I save my work?"**
- Files auto-save every few seconds
- To commit to Git: Ask Copilot *"Save my changes"*

**"I'm stuck or confused — what do I do?"**
- **Ask Copilot:** *"what should I do next"*
- **Talk to an agent:** *"talk to John"* (PM), *"talk to Mary"* (Analyst), etc.
- **Detailed walkthroughs** — [BMAD Onboarding Guide](https://sites.idp.pg.com/bmad-onboarding-instructions-idp/)
- **Platform issues** — use the **Support button** (bottom-right corner of the IDP portal)

**"Can I break anything?"**
- No! Git tracks all changes — everything can be undone
- Your work is backed up automatically

---

## What's Included

Everything installs automatically on first launch:

- ✅ **BMAD Method v6** with 9 agent personas and 43 skills
- ✅ **Node.js 22** + npm
- ✅ **GitHub Copilot** AI assistant
- ✅ **Git & GitHub CLI**
- ✅ **Jira MCP** pre-configured (just add credentials)
- ✅ **Pre-commit hooks** for automatic file cleanup
- ✅ **Auto-updates** — minor/patch updates applied on Codespace rebuild

**⚡ Fast startup: First launch ~30 sec, subsequent launches ~15 seconds!**

---

## Resources

- 📚 [BMAD Onboarding Guide](https://sites.idp.pg.com/bmad-onboarding-instructions-idp/)
- 💬 IDP Portal Support button for platform issues

---

*Created with [IDP Software Templates](https://github.com/procter-gamble/idp-software-templates) — BMAD Method v6*
