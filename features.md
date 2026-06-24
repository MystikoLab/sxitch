# Sxitch — Features

A macOS app switcher built with Rust and Iced.

---

## 1. App Switching Core

- **Running App Detection** — Enumerates apps via `NSWorkspace.runningApplications()`, filters to regular GUI apps, excludes self
- **App Launching** — Opens apps via `NSWorkspace.openApplicationAtURL`
- **App Quitting** — Terminates app by bundle ID (Pro)
- **App Hiding** — Hides app by bundle ID (Pro)
- **App Mode Switching** — `Ctrl+Q` (Quit mode), `Ctrl+H`/`Ctrl+M` (Hide mode), `Ctrl+N` (Normal mode) — (Pro)
- **App List Auto-Refresh** — Listens to `NSWorkspaceDidLaunchApplicationNotification` and `NSWorkspaceDidTerminateApplicationNotification`, debounced at 300ms

## 2. Character-Based Selection & Key Resolution

- Type a character to select/directly open an app
- **4 Key Resolution Schemes** for disambiguation when multiple apps share the same first letter:
  - **Alphabets** — a, b, c, d, ...
  - **Numbers** — 1, 2, 3, 4, ...
  - **Qwerty** — q, w, e, r, t, y, ...
  - **NameIncrement** — Nth character of each app's name at current depth
- **Depth tracking** for multi-character disambiguation
- **Key Overrides** — Assign a specific key to any app (Pro)
- **System beep** (`NSBeep()`) when no matching app is found

## 3. Window Picking

- Shows individual windows of an app when selected (Pro)
- Supports Grid and List layouts
- Windows are filtered by typing characters matching their titles

## 4. UI Layout

- **Grid Layout** — Horizontal row of app icons with key badges (70×70 icons)
- **List Layout** — Vertical list with icon (28×28), name, mode icon, key text
- Selected item has highlighted background and border
- **9 Screen Positions** — Default, Top/Middle/Bottom × Center/Left/Right
- **Dynamic window sizing** based on app count and layout
- **Transparent, borderless, floating window** (`NSFloatingWindowLevel + 100`, appears on all spaces)
- **macOS native window blur** (configurable)
- **Bounce animation** on focus change / filtering (75ms ease-out)
- **Page fade animation** on settings transitions

## 5. Theming

- **Auto Theme** — Switches between light/dark based on system appearance
- **3 Theme families**: Light, Dark, Custom
- **13 Built-in Themes**:
  - Light: Default, Solarized, GitHub, Catppuccin Latte, Tokyo Night Light, One Light
  - Dark: Default, Dracula, Catppuccin Frappe/Mocha/Macchiato, Nord, Tokyo Night Storm, One Dark
- **Custom Themes** — Import from `.toml` files via file picker (fields: `name`, `background`, `text`, `primary`, `success`, `warning`, `danger`)
- **6-color palette** per theme: background (transparent-capable), text, primary, success, warning, danger

## 6. Configuration (TOML-based)

Stored at `<data_dir>/Sxitch/config.toml`:

| Option | Type | Default |
|--------|------|---------|
| `hotkey` | String | `"rcmd"` |
| `theme` | ThemeConfig | Fixed Dark |
| `tray_icon_visible` | bool | `true` |
| `scheme` | Resolver | `NameIncrement` |
| `show_keys` | bool | `true` |
| `blacklist` | Vec\<String\> | `[]` |
| `skip_prefixes` | Vec\<String\> | `["microsoft", "adobe"]` |
| `overrides` | Vec\<(String,String)\> | `[]` |
| `license_key` | String | `""` |
| `position` | Position | Default |
| `log_file` | String | `auto` |
| `open_at_login` | bool | system status |
| `blur` | bool | `false` |
| `enable_ui` | bool | `true` |
| `layout` | Layout | `Grid` |
| `window_picking` | bool | `false` (Pro) |

Config editing is done via the settings UI, saved on each change.

## 7. Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Configured hotkey (default: Right Command) | Summon app switcher |
| `Ctrl+Q` | Quit mode |
| `Ctrl+H` / `Ctrl+M` | Hide mode |
| `Ctrl+N` | Normal mode |
| `Escape` | Close window / reset selection |
| `Cmd+,` | Open Settings (General) |
| `Enter` | Open focused app |
| `Any Character` | Filter/select app by key |
| `ArrowDown` / `ArrowRight` | Move focus forward |
| `ArrowUp` / `ArrowLeft` | Move focus backward |
| `Tab` | Move focus forward |
| `Shift+Tab` | Move focus backward |

## 8. macOS Integrations

- **Global Event Tap** (`CGEventTap`) for summon hotkey
- **Local Event Monitor** when app is focused
- **Shortcut Parsing** — Supports lcmd/rcmd, lctrl/rctrl, lshift/rshift, lopt/ropt, cmd, ctrl, opt, shift, fn, capslock + any key
- **Comprehensive keycode mapping** and reverse mapping
- **Accessibility API** (`AXUIElement`) for window focusing by title
- **Permission handling** (30s timeout, 250ms polling):
  - Accessibility (`AXIsProcessTrustedWithOptions`)
  - Input Monitoring (`IOHIDCheckAccess` / `IOHIDRequestAccess`)
  - Screen Recording (`CGPreflightScreenCaptureAccess` / `CGRequestScreenCaptureAccess`)
- **Deep links** to System Preferences for permissions
- **Login Item** via `SMAppService.mainAppService()`
- **Dark/Light mode detection** via `NSApp.effectiveAppearance`
- **Multi-display** — Switcher appears on the screen containing the mouse cursor
- **Activation policy** — `.Accessory` (no dock icon, no menu bar)
- **CGWindow-Level window listing** (`CGWindowListCopyWindowInfo`) by PID
- **NSWorkspace API** — app enumeration, launching, icons, notifications

## 9. Menubar / Tray Icon

- Custom `NSStatusItem` with programmatically drawn 512×512 icon (switch/knob/slider)
- Menu items:
  - "Sxitch Pro" / "Sxitch Free" (status indicator)
  - Version display
  - "Get Pro" (free only, opens https://sxitch.app/#pricing)
  - "Show" (opens switcher)
  - "GitHub" (opens repo)
  - "Homepage" (https://sxitch.app)
  - "Community" (Discord)
  - "Sxitch Settings" (Cmd+,)
  - "Quit Sxitch" (Cmd+Q)
- Tray icon visibility toggleable from Settings

## 10. Licensing (Pro via Polar.sh)

- **License activation** — POST to Polar.sh `/v1/customer-portal/license-keys/activate`
- **License validation** — POST to Polar.sh `/v1/customer-portal/license-keys/validate`
- **Keychain storage** — Credentials stored via `keyring-core` + `apple-native-keyring-store`
- **Pro features gated** behind validation:
  - App mode switching (Quit/Hide)
  - Quit and Hide apps
  - Key overrides
  - Window position changes
  - Blacklist editing
  - Window picking
  - Show window picker
- Secure text input for license key in Settings → Activate
- "Activated" status indicator
- "Get Sxitch Pro" link

## 11. Settings UI

Six-panel settings accessible via `Cmd+,`:

- **General** — Hotkey, layout (Grid/List), position, key scheme, show keys, enable UI, app blacklist, skip prefixes, key overrides, login at startup
- **Themes** — Theme selection, blur toggle, tray icon visibility
- **About** — App info
- **Activate** — License key input and activation
- **Advanced** (debug builds only) — Color-coded JSON log viewer with monospace font

## 12. Onboarding Wizard

First-run wizard with pages:
- Welcome
- Permissions (Accessibility, Input Monitoring, Screen Recording)
- Tutorial (hotkey activation, character-based picking, mode switching)
- Finish

## 13. Custom Widgets

- **BezierContainer** — Custom Iced widget with smooth Bezier-curved rounded corners (cubic bezier approximation), anti-aliasing, shadows, borders, gradient fills, configurable curvature

## 14. Styling & Fonts

- **Satoshi** (Satoshi-Regular.ttf) — Default UI font, Expanded weight
- **Lucide** (lucide.ttf) — Icon font
- ~30 style functions (buttons, containers, navbar, text inputs, dropdowns, checkboxes, list items, window titles)
- Multi-stop linear gradient backgrounds

## 15. Logging & Debugging

- `tracing-subscriber` with `env-filter` and JSON format
- Logs written to `sxitch.log` in data directory
- `DEBUG_MODE` env var unlocks: Advanced settings tab, skips license validation

## 16. Additional

- **First-run detection** — Shows onboarding on first launch
- **URL opening** — Links to website, GitHub, Discord, permissions deep links
- **File picker** (`rfd::FileDialog`) for importing custom theme files
- **UI visibility toggle** — Renders empty widget when `enable_ui` is false
- **Restart** — Re-executes the current binary via `exec()`
- **Keychain** — Apple Keychain backend for secure license credential storage
- **Sound effects** — `NSBeep()` on no-match

---

*Generated from codebase analysis — 30 Rust source files, ~6,500 lines of code.*
