# AI Context & Living Specification — OnePanel_Skills

> **Living Document**: This file serves as the primary context, architectural specification, and state-handoff document for AI-assisted development across sessions. Update this file on every development cycle ("spin").

---

## 🎯 Overview & Scope

- **Addon Name**: OnePanel_Skills
- **Current Version**: 0.0.1
- **Suite**: Part of the **OneSuite** family (OnePanel Plugin)
- **GitHub Repository**:
  - Exists: TRUE
  - URL: https://github.com/Nuros-WoW-Forever-Addons/OnePanel_Skills
- **Branching Policy**: All new features must be developed on a branch != `main` (e.g. `dev`, `feature/<name>`)
- **Live Sync Path**: `/Applications/World of Warcraft/_classic_beta_/Interface/AddOns/OnePanel_Skills/`
- **Rollback Target**: Last working `main` branch commit
- **Release Package**: `.github/workflows/package.yml` generates `OnePanel_Skills-latest.zip` on push to `main`
- **Dependencies**: `OnePanel`, `OnePanelUtils`
- **Target WoW Runtimes**: WoW Forever Beta (v1.60.1 / Interface 16001)
- **Primary Goal**: Deliver a rich, interactive Skills management interface docked into OnePanel, providing clean categorization (Professions, Secondary, Weapon, Armor, Language), high-contrast progress bars, real-time search, and an expandable detail drawer with profession actions.

---

## 🏗️ Architecture & Component Map

### File Structure
- `OnePanel_Skills.toc`: Manifest, declares dependencies on `OnePanel` and `OnePanelUtils`.
- `Core.lua`: Complete plugin implementation:
  - Skill lines aggregator (`GetNumSkillLines`, `GetSkillLineInfo`).
  - Search filter input and category collapsing.
  - ScrollFrame list generator with recycled row widgets.
  - Interactive skill details drawer (Skill description, milestone rank progress, unlearn safety dialog).
  - Plugin registration with OnePanel (`OnePanel:RegisterPlugin`).

### Registration Payload with OnePanel
```lua
OnePanel:RegisterPlugin({
    id = "Skills",
    title = "Skills",
    order = 30, -- Tab 3, positioned after Character (10) and Reputation (20)
    icon = "Interface\\Icons\\Trade_BlackSmithing",
    CreateView = CreateSkillsView,
    OnShow = function(container) ... end,
    OnHide = function(container) ... end,
})
```

---

## 🔄 AI Development Cycle & Handoff Protocol

When picking up development on this addon:

1. **Orientation**: Read `CONTEXT.md` (this file) to verify current state, known issues, and active backlog items.
2. **Implementation**: Execute changes. For code refactoring or boilerplate, delegate to `qwen2.5-coder:32b` via the local `gx10_ollama` MCP server as mandated by user rules.
3. **Verification**: Verify in-game syntax and test by pressing `K` or running `/op`.
4. **Handoff Update**:
   - Move completed tasks from **Upcoming Backlog** to **Recent Completed Work**.
   - If user-facing features or commands changed, update `README.md` and append a new section in `CHANGELOG.md`.
   - Document newly discovered backlog items or edge cases in **Upcoming Backlog**.

---

## ✅ Recent Completed Work (Latest Spins)

### Spin 0.0.1 (2026-10-13)
- Initial scaffold and repository setup.
- Core skills view implementation with categorized scroll list and progress bars.
- Live search filter and drawer synchronization with `ONEPANEL_EXPAND_STATE_CHANGED`.
- Upgraded engine integration to WoW Forever Beta (1.60.1 / Interface 16001) using `C_SkillInfo` API with legacy Classic Era fallback.
- Added Camelot combat rating breakdown (Hit/Dodge/Parry & Crit offset vs same level and vs boss +3) for weapon proficiency skills.
- Refactored category headers from `-` / `+` title bars to grey button banners (`UIPanelButtonTemplate` with centered text and `:Disable()`) matching the visual style of the Character Stats subpanel while maintaining interactive expand/collapse.

---

## 📋 Living Roadmap & Upcoming Backlog (Next Spins)

### Priority 1: High Priority (Immediate Next Spin)
- [ ] **1-Click Recipe/Crafting Window Launcher**: Quick action button in detail drawer to directly cast/open the crafting trade window for primary and secondary professions.
- [ ] **Profession Cap Warning**: Visual notification when a skill rank hits the current training tier cap (e.g. 75/75, 150/150) alerting the player to visit a trainer.

---

## 🧪 Testing & Verification Guide

- **Open Panel**: Press `K` or click Skills tab in OnePanel — confirm Skills tab is selected and skills list populates.
- **Category Collapse**: Click `[-]` / `[+]` on Professions or Weapon Skills — confirm sub-items collapse smoothly.
- **Search Filtering**: Type a query into the search box — confirm matching skills filter dynamically.
- **Drawer Selection**: Click any skill row — confirm detail view on the right displays the skill name, rank, and description.

---

## ⚠️ Technical Constraints & Engine Gotchas

- **Header Expansion State**: In Classic WoW, `GetSkillLineInfo` only iterates through visible lines if headers are collapsed. We must track or safely expand headers to inspect all skills if necessary, or preserve user collapse states.
- **Profession Unlearning**: `AbandonSkill(skillIndex)` is irreversible. Any unlearn UI button must enforce a two-step confirmation popup.
