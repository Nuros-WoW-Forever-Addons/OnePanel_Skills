# Changelog — OnePanel_Skills

All notable changes to **OnePanel_Skills** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.0.1] - 2026-10-13
### Added
- **Categorized Collapsible Skill Matrix**: Groups character skills into Professions, Secondary Skills, Weapon Skills, Armor Proficiencies, and Languages.
- **High-Contrast Progress Bars**: Crisp progress displays with exact numeric values (e.g. `91 / 150`), percentage gauges, and visual rank tracking.
- **Interactive Detail Drawer**: Expandable right-hand panel displaying detailed skill descriptions, trainer hints, and crafting launch capabilities.
- **Live Search Filtering**: Search bar for real-time skill name lookup and instant list narrowing.
- **OnePanel Docking**: Direct integration with OnePanel as Tab 3 (Order: 30, Icon: `Interface\Icons\Trade_BlackSmithing`).
- **WoW Forever Camelot Compatibility**: Full integration with `C_SkillInfo` API and category filtering for WoW Forever Beta (v1.60.1 / Interface 16001).
- **Weapon Combat Ratings**: Live combat rating breakdown (Hit/Dodge/Parry & Crit offset vs same level and vs boss +3) in the skill detail drawer.
- **Character Stats Styled Category Headers**: Clean grey button banners (`UIPanelButtonTemplate` with centered titles) matching the Character Stats subpanel design.
- **Modern Gradient Progression Bars**: Authentic Camelot/Dragonflight gradient fill textures (`ui-castingbar-filling-applyingcrafting` for professions, `ui-castingbar-filling-channel` for secondary skills, `ui-castingbar-filling-standard` for weapon proficiencies, and `ui-castingbar-full-*` for maxed skills) rendered with full vibrant color without darkening multipliers, encased in authentic `ui-castingbar-frame` borders, `ui-castingbar-background` tracks, and dynamic `ui-castingbar-pip` spark indicators.
- **Enhanced Typography & Readability**: Scaled up font sizes across all elements: 14pt skill names with drop shadows and gold active selection, 13pt bold centered category headers, 13pt bold progress bar numbers with `OUTLINE`, 13pt search box and hint, 17pt gold detail headline, and 13pt high-contrast description text.
