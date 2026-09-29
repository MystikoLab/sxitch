# Extending Sxitch

A practical guide to adding new modes, layouts, settings, and picking behavior.

---

## Adding a new mode (e.g., "Force Quit")

Modes control two things: **visual styling** (colors) and **actions** (what happens when you select an app/window). Everything is driven by `AppMode` + `ModeTheme`.

### Step 1: Add the case

**File: `Core/AppMode.swift`**

```swift
enum AppMode {
    case hide
    case quit
    case normal
    case forceQuit    // ← add your new case
}
```

### Step 2: Define its theme

**File: `Theme/ModeTheme.swift`**

Add a new static theme and wire it into `theme(for:)`:

```swift
extension ModeTheme {
    static let forceQuit = ModeTheme(
        overlayColor: .purple.opacity(0.7),
        foregroundStyle: Color.purple.opacity(0.8),
        appAction: { app in
            // What happens when you pick an app in this mode
            app.quitApp()
        },
        windowAction: { window in
            // What happens when you pick a window in this mode
            var pid: pid_t = 0
            AXUIElementGetPid(window.axElement, &pid)
            if let app = NSRunningApplication(processIdentifier: pid) {
                app.forceTerminate()  // or app.terminate()
            }
        }
    )
}

// Then add to the switch:
static func theme(for mode: AppMode) -> ModeTheme {
    switch mode {
    case .normal:   return .normal
    case .hide:     return .hide
    case .quit:     return .quit
    case .forceQuit: return .forceQuit
    }
}
```

That's it. All views (`RunningAppCell`, `RunningAppListCell`, `WindowPickerView`) read `@Environment(\.modeTheme)` and automatically pick up the new colors and actions.

### Step 3 (optional): Add a keyboard shortcut

**File: `Core/AppDelegate.swift`** in `handleEvent()`:

```swift
// Inside the `flags.contains(.maskControl), proState.isPro` block:
if keyCode == someKeyCode {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
            self.appState.mode = self.appState.mode == .forceQuit ? .normal : .forceQuit
        }
    }
    return nil
}
```

### Step 4 (optional): Show in settings/onboarding

Add a toggle or description in `Settings/GeneralSettingsView.swift` or `OnboardingView.swift` if needed.

---

## Adding a new layout (e.g., "Cover Flow")

Layouts control how running apps are visually arranged in the switcher overlay.

### Step 1: Create the layout view

**File: `Views/Layouts/CoverFlowLayout.swift`**

```swift
import SwiftUI

struct CoverFlowLayout: View {
    let apps: [RunningApp]
    let typed: String
    let onTap: (RunningApp) -> Void

    @Environment(\.modeTheme) var modeTheme

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: -20) {
                ForEach(
                    apps.filter { $0.appName.lowercased().starts(with: typed.lowercased()) },
                    id: \.id
                ) { app in
                    RunningAppCell(app: app, depth: typed.count, onTap: onTap)
                        .scaleEffect(x: 0.8, y: 0.8)
                        .rotation3DEffect(.degrees(-15), axis: (x: 0, y: 1, z: 0))
                }
            }
            .padding(.horizontal, 40)
        }
        .frame(height: 160)
    }
}
```

Requirements:
- Must take `apps: [RunningApp]`, `typed: String`, and `onTap: (RunningApp) -> Void`
- Must apply `@Environment(\.modeTheme)` if you need mode-aware styling
- Use `RunningAppCell` for grid-style items or `RunningAppListCell` for list-style items

### Step 2: Register it

**File: `Views/Layouts/AppLayout.swift`**

```swift
var body: some View {
    switch layoutStyle {
    case "list":       ListAppLayout(...)
    case "circle":     CircleAppLayout(...)
    case "coverflow":  CoverFlowLayout(...)
    default:           GridAppLayout(...)
    }
}
```

### Step 3: Add it to the settings picker

**File: `Settings/ThemeSettingsView.swift`**

```swift
Picker("View Style", selection: $layoutStyle) {
    Label("Grid",     systemImage: "square.grid.2x2").tag("grid")
    Label("List",     systemImage: "list.bullet").tag("list")
    Label("Circle",   systemImage: "circle").tag("circle")
    Label("CoverFlow", systemImage: "rectangle.3.group").tag("coverflow")  // ← add
}
```

---

## Adding a new settings tab

Tabs are registered in a central list — no need to edit the `SettingsView` itself.

### Step 1: Create the tab view

**File: `Settings/MyNewTabView.swift`**

```swift
import SwiftUI

struct MyNewTabView: View, SettingsTab {
    static let tabID = "myfeature"
    static let tabTitle = "My Feature"
    static let tabIcon = "star"

    var body: some View {
        Form {
            Section("My Section") {
                Toggle("Enable feature", isOn: .constant(true))
                Text("More options here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .formStyle(.grouped)
    }
}
```

Protocol requirements:
- `static let tabID: String` — unique identifier
- `static let tabTitle: String` — displayed in tab label
- `static let tabIcon: String` — SF Symbol name

### Step 2: Register it

**File: `Settings/SettingsTab.swift`**

```swift
struct RegisteredTabs {
    static var all: [AnySettingsTab] = [
        AnySettingsTab(id: "general",   ...),
        AnySettingsTab(id: "theme",     ...),
        AnySettingsTab(id: "advanced",  ...),
        AnySettingsTab(id: "activate",  ...),
        AnySettingsTab(id: "myfeature", icon: "star",   content: AnyView(MyNewTabView())),  // ← add
    ]
}
```

---

## Adding a section to an existing settings tab

No special pattern needed — just add a `Section {}` in the relevant tab's `body`.

**File: `Settings/GeneralSettingsView.swift`**

```swift
Section("Experimental") {
    Toggle("New feature X", isOn: $enableFeatureX)
    Text("Description of what this does.")
        .font(.caption)
        .foregroundStyle(.secondary)
}
```

The `body` is a `Form` with `.formStyle(.grouped)`, so sections stack naturally.

---

## Extending window picking behavior

The window picker is decoupled from `AppMode` via `ModeTheme`. To change what happens when a window is selected in a given mode, edit the `windowAction` closure in the corresponding `ModeTheme` static property.

**File: `Theme/ModeTheme.swift`**

```swift
static let normal = ModeTheme(
    ...
    windowAction: { window in
        AXUIElementPerformAction(window.axElement, kAXRaiseAction as CFString)
        window.ownerApp.activate(options: [])
    }
)
```

To add behavior that triggers **before** the window picker appears (e.g., analytics, logging, confirmation dialog):

**File: `Views/ContentView.swift`** — `handleAppTap()`:
```swift
func handleAppTap(_ app: RunningApp) {
    // Your pre-picker logic here
    let windows = fetchWindowsForApp(app.app)
    let windowPickerEnabled = UserDefaults.standard.bool(forKey: "windowPickerEnabled")
    ...
}
```

---

## Extending app picking flow

The auto-select logic (when typing reduces matches to one) lives in:

**File: `Core/AppDelegate.swift`** — `setupAutoSelect()`:

```swift
func setupAutoSelect() {
    appState.$typed
        .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
        .sink { [weak self] typed in
            // Your custom logic here
            // Currently:
            //   1. If drilling down into windows → match windows
            //   2. Otherwise → match apps, then decide: drill down or act
        }
        .store(in: &cancellables)
}
```

---

## Adding a new switcher animation

Open/close animation styles live in **`Core/SwitcherAnimation.swift`** as the `SwitcherAnimation` enum (`fade`, `slide`, `drop`, `scale`). "Default" is the label users see for `fade` — the free plan's animation. All entrance/exit motion is driven at the NSWindow level (`AppDelegate.prepareOpenAnimation` / `playOpenAnimation` / `closeWindowAnimated`) — not via SwiftUI transitions, which race with the panel's first composited frame. To add a style:

1. **Add the case** — the enum drives display names, Pro gating (`isPro`), and all timings (`openDuration`, `closeDuration`). Close automatically plays `openDuration / 1.5`.
2. **Prime the entrance** — in `prepareOpenAnimation`, set the pre-show state (e.g. fade sets `alphaValue = 0`; slide also offsets the frame 24pt down and snapshots the final frame into `pendingOpenFrame`).
3. **Play the entrance** — in `playOpenAnimation`, branch on the style and animate from primed state to final with `NSAnimationContext`. Every summon path already calls it right after `orderFrontRegardless`, and it also snaps to the final state when animations are disabled or Reduce Motion is on.
4. **Wire the exit** — `closeWindowAnimated()` animates with AppKit; branch on the style there.
5. **Gate it** — mark the case `isPro = true` only if it belongs in the paid tier. `SwitcherAnimation.current` downgrades Pro styles to `fade` when no valid licence exists, and the Animation settings tab snaps its picker back the same way. Never "test" a Pro style by forcing it — use an unlimited licence key.

Settings keys (all user-configurable in Settings → Animation):

| Key | Values | Purpose |
|---|---|---|
| `openCloseAnimationsEnabled` | Bool | Master on/off for entrance + exit animation |
| `switcherAnimationStyle` | raw value of `SwitcherAnimation` | Which open/close animation |
| `animationSpeedMultiplier` | Double, 0.5–2.0 | Speed applied to every animation |

---

## File map

```
Core/                    → AppMode, AppState, AppDelegate, models, SwitcherAnimation
Theme/                   → ModeTheme (central mode styling)
Views/                   → ContentView, RunningApp cells, WindowPicker
Views/Layouts/           → Grid, List, Circle (add yours here)
Settings/                → SettingsView + one file per tab
```

To add something new, ask yourself: "Which directory does this belong to?" If it doesn't fit, create a new subdirectory — the project uses `PBXFileSystemSynchronizedRootGroup`, so Xcode picks up new `.swift` files automatically.
