# Agent instructions

- Target World of Warcraft 7.3.5 only.
- Lua version and APIs must remain compatible with Interface 70300.
- Never assume Retail WoW APIs are available.
- Preserve `s2k_EnhancementsDB` compatibility.
- Avoid per-frame polling where events are available.
- Do not modify protected frames during combat.
- Run Lua syntax validation on every Lua file.
- Package releases with `s2k_Enhancements` as the top-level directory.
- Update `CHANGELOG.md` and the TOC version for every release.