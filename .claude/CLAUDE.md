# LunaUITweaks — Objective Tracker

Custom objective tracker addon with quest/WQ/achievement tracking, super-track restore, and more.
Runs standalone; when the main LunaUITweaks addon is present, registers its config panel as a tab in the main config window via `LunaUITweaksAPI.RegisterConfigPanel`. Settings are always stored in `LunaObjectiveTrackerDB` (no shared DB with the main addon).

## Target Environment

- **Interface version:** 120000, 120001 (The War Within, 12.0)
- **Language:** Lua 5.1 (WoW's embedded interpreter)
- **No build step** — pure Lua loaded directly by the WoW client on `/reload`

## Lua 5.1 Constraints

- No `\xNN` hex escape sequences — use decimal escapes `\ddd` instead (e.g. `\226\153\165` for ♥)
- No bitwise operators (`&`, `|`, `~`, `>>`, `<<`) — use `bit.band()` etc.
- No integer division `//` — use `math.floor(a/b)`
- No `goto`, no `<const>`, no `<close>`

## WoW Font Constraints

- WoW only loads fonts from within the WoW installation directory — absolute system paths (e.g. `C:\Windows\Fonts`) are silently ignored
- Bundled addon fonts must be referenced by their addon-relative path: `Interface\\AddOns\\AddonName\\fonts\\font.ttf`

## Taint Rules

WoW's secure execution model taints addon code that touches Blizzard's protected functions or frames. Taint causes `ADDON_ACTION_BLOCKED` errors and can silently corrupt UI behaviour.

### General Rules
- **Never write fields onto Blizzard frames** (`frame.myField = x`) — taints the entire frame table
- **Never call `GetText()` on Blizzard FontStrings** — returned string is tainted by the addon
- **Never read Blizzard frame table fields** set by Blizzard's secure code — they are secret and taint addon context when read
- **Never call positioning methods on Blizzard frames**: `SetPoint`, `SetSize`, `ClearAllPoints`, `SetAllPoints` — these taint frame layout context
- **SetAlpha/SetHeight/EnableMouse on Blizzard frames IS safe** — visual-only calls do not cause taint
- **RegisterStateDriver requires SecureHandlerStateTemplate** — plain frames do NOT have `SetAttribute` and will error
- **Safe reads from Blizzard frames**: `GetWidth()`, `GetHeight()`, `GetLeft()`, `GetBottom()`, `IsShown()` — numbers/booleans are not tainted
- **Safe hooks**: `hooksecurefunc("GlobalFunctionName", cb)` — global function form only, no taint
- **Unsafe hooks**: `hooksecurefunc(frame, "Method", cb)` — frame-object form taints the frame
- **Unsafe hooks**: `frame:HookScript("OnEvent", cb)` — taints frame context
- Track addon state about Blizzard frames using side-tables keyed by frame ref, never write to the frame itself

### Secret Values
`issecretvalue(v)` returns `true` for values returned by Blizzard's secure code paths during combat.

- **FAILS:** using as table key (`table[secret] = v` → "table index is secret"); comparison operators `>`, `<`, `>=`, `<=`
- **WORKS:** `type(secret)`, arithmetic (`+`, `-`, `*`, `/`), `string.format`, `SetText`, `SetStatusBarColor`, `SetValue`, `SetMinMaxValues`
- **FAILS after table copy:** `myTable.x = secretVal` makes arithmetic on `myTable.x` fail — keep secret values as direct locals

## Combat Lockdown Rules

Always check `InCombatLockdown()` before calling any of the following on **Blizzard-owned** frames:
`SetPoint`, `ClearAllPoints`, `SetParent`, `SetSize`, `Show`, `Hide`, `RegisterStateDriver`, `UnregisterStateDriver`

Addon-created frames (not inheriting from secure templates) are safe to position anytime.

For combat-safe show/hide use `RegisterStateDriver(frame, "visibility", "hide")` / `UnregisterStateDriver` — but these calls themselves must happen outside combat.

### `COMBAT_LOG_EVENT_UNFILTERED` is restricted
This event is reserved for Blizzard UI only. Using it in a third-party addon produces a blocking Lua error. Do not use it.

## Showing/Hiding Frames in Combat

Use `RegisterStateDriver` / `UnregisterStateDriver` — not `Show()` / `Hide()` directly. The registration call must happen outside combat.

```lua
-- Show:  RegisterStateDriver(frame, "visibility", "show")
-- Hide:  RegisterStateDriver(frame, "visibility", "hide")
-- Reset: UnregisterStateDriver(frame, "visibility"); frame:Show()
```
