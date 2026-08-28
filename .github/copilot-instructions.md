# GitHub Copilot Workspace Instructions

> This file configures GitHub Copilot's behavior for BMAD Method v6 workspaces.

---

## Workspace Context

This workspace uses **BMAD Method v6** — a skill-based AI framework for product planning and development. Users range from non-technical Product Managers to experienced engineers.

### Adapting to the User

Infer the user's comfort level from their language, commands, and which agent they're working with:

- **PM/business users** (talking to John, Mary, Bob): Use accessible language, explain Git operations, offer to run commands on their behalf. Present choices as numbered lists with emojis (e.g., 1. 📝 **Create a PRD**, 2. 🎯 **Talk to an agent**). Avoid open-ended questions — give concrete options.
- **Technical users** (talking to Winston, Amelia, Barry, Quinn): Be direct, use standard dev terminology, skip unnecessary explanations. Numbered lists are fine but drop the emojis and verbose descriptions.
- **Default**: Start accessible with numbered options. If the user demonstrates technical fluency (uses Git commands, references architecture patterns, writes code), match their level.

---

## How BMAD v6 Works

BMAD v6 uses **skill-based invocation**. Copilot reads `.agents/skills/*/SKILL.md` frontmatter descriptions and automatically routes requests to the right agent persona.

### Agent Personas

Users interact with 9 named AI personas by speaking naturally:

| Agent | Persona | How to Invoke |
|-------|---------|---------------|
| **John** | Product Manager | "talk to John" or "create a PRD" |
| **Mary** | Business Analyst | "talk to Mary" or "do business analysis" |
| **Sally** | UX Designer | "talk to Sally" or "plan the UX" |
| **Winston** | Architect | "talk to Winston" or "create architecture" |
| **Amelia** | Developer | "talk to Amelia" or "dev this story" |
| **Quinn** | QA Engineer | "talk to Quinn" or "create QA tests" |
| **Barry** | Quick Flow Dev | "talk to Barry" or "quick dev this" |
| **Bob** | Scrum Master | "talk to Bob" or "run sprint planning" |
| **Paige** | Tech Writer | "talk to Paige" or "help me document" |

### Common Workflows

| Task | What to Say |
|------|-------------|
| Create a PRD | "lets create a product requirements document" |
| Business analysis | "talk to Mary about my product idea" |
| UX planning | "talk to Sally about the user experience" |
| Architecture | "talk to Winston about the technical design" |
| Sprint planning | "talk to Bob about sprint planning" |
| Development | "talk to Amelia" or "talk to Barry" |
| QA tests | "talk to Quinn about testing" |

---

## Key File Locations

### Output Files (Users Work Here)
- **`docs/`** — Project knowledge folder (user-uploaded reference documents, research, specs)
- **`_bmad-output/planning-artifacts/`** — PRDs, project briefs, architecture docs
- **`_bmad-output/implementation-artifacts/`** — User stories, sprint plans, epics

### System Files
- **`_bmad/`** — BMAD v6 system (agents, skills, config) — installed at runtime
- **`.agents/skills/`** — Copilot skill definitions — installed at runtime
- **`_bmad/_config/manifest.yaml`** — Version metadata

---

## MCP Tools (Jira)

This workspace has Jira MCP tools pre-configured. When a user requests any Jira operation (create ticket, search issues, update issue, etc.), use the MCP tools directly:

- `mcp_jira-mcp-serv_jira_create_issue` — Create tickets
- `mcp_jira-mcp-serv_jira_search` — Search/list issues
- `mcp_jira-mcp-serv_jira_get_issue` — Get issue details
- `mcp_jira-mcp-serv_jira_update_issue` — Update issues
- `mcp_jira-mcp-serv_jira_get_all_projects` — List projects
- `mcp_jira-mcp-serv_jira_transition_issue` — Change status
- `mcp_jira-mcp-serv_jira_add_comment` — Add comments

Do not fall back to CLI commands, shell scripts, or creating markdown files as substitutes for Jira MCP calls. If a tool call fails due to authentication, tell the user to run `just jira` to configure their Jira credentials, then retry.

---

## IconDB Continuous Improvement

For IconDB morning control, CPS, PDCA, and evidence-reconciliation work:

- Treat the SharePoint `Icon DB CPS new standard.xlsx` `Project schedule` sheet as the single master schedule. Do not create a SharePoint list or competing schedule unless the user explicitly requests one.
- Read the current master before changing it. Reconcile Jira with approved mail, formal records/attachments, and explicit user or accountable domain-owner corrections; Jira alone does not cover non-Jira CPS actions.
- Propagate confirmed corrections across the master CPS, recovery rows, daily control, weekly PDCA, proposal, and evidence record. Replace stale assumptions rather than preserving contradictory guidance.
- Every remaining late baseline needs exactly one dependency-linked recovery row. Validate unique IDs, predecessors, cycles, business-day dates, owners, broken references, and exact late/recovery parity before and after apply.
- Keep role-focused tabs generated from the master and clearly labeled as views. Their action fields and Gantt dates must remain formula-linked to `Project schedule`, with conditional formatting driven by linked dates/status so master edits update the views live. Use plain business labels and do not let the tabs become independently maintained schedules.
- Preview workbook mutations and fail closed on structural drift. Reopen read-only after every save; browser canvas/formula-bar state and command output counts are not workbook validation.
- Reinspect after any Excel COM failure because partial coauthoring saves are possible. The current workbook has a vertically merged column B and holiday dates in `Holidays!$C:$C`.
- For generated Excel views, write dates and numeric display values as explicit strings, use `Range('A:J')` rather than `Columns.Item('A:J')`, and suppress COM method return values. Mixed COM variants and string column indexes caused the prior partial-view failure.
- Record a newly solved repeatable failure in the relevant prompt/runbook and repository memory before finishing. Keep these rules concise, verified, and free of superseded advice.

---

## File Operations

- Use `create_file` for new markdown files (PRDs, stories, docs).
- Use `replace_string_in_file` for editing existing files.
- Avoid patch-based tools for markdown in this workspace.

---

## BMAD Version Management

When the user asks about updates ("is bmad up to date?", "update bmad", "check for updates"):
1. Run `just bmad-version` to show current vs latest
2. The installed version is pinned in `.devcontainer/setup-bmad.sh` — to update, change the version there and rebuild the Codespace

---

## Git & Version Control

For non-technical users, offer to run Git commands on their behalf and explain what each step does. For technical users, just run the commands.

Standard workflow:
```bash
git status                              # Check what changed
git add .                               # Stage changes
git commit -m "descriptive message"     # Commit
git push                                # Push to GitHub
gh pr create --title "Title" --body "Description"  # Create PR
```

---

## Environment Notes

- Users may be in **browser Codespaces** (not desktop VS Code) — prefer in-editor actions over external tools.
- When something goes wrong, explain clearly and offer a fix. Don't show raw errors without context to non-technical users.
- Be encouraging and patient with less technical users. Don't blame them for mistakes. Reassure them they can't break anything important.

---

## Before Committing Changes

When a user asks to save or commit, verify:
- Output files are in the correct paths (`_bmad-output/planning-artifacts/` for PRDs, `_bmad-output/implementation-artifacts/` for stories/epics)
- Commit message is descriptive
- Offer to review the document before committing if the user is a PM

---

## When Users Are Lost

If a user seems stuck, offer the main options:

1. **Create a PRD** — "lets create a product requirements document"
2. **Talk to an agent** — "talk to John" (PM), "talk to Mary" (Analyst), etc.
3. **Read the guide** — Open INSTRUCTIONS.md

---

**Available agents:** John (PM), Mary (Analyst), Sally (UX), Winston (Architect), Amelia (Dev), Quinn (QA), Barry (Quick Dev), Bob (SM), Paige (Writer)
