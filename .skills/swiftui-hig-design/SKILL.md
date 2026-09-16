---
name: swiftui-hig-design
description: Use this skill whenever building, reviewing, or improving SwiftUI interfaces — screens, components, navigation, or full app flows — for iOS, iPadOS, macOS, watchOS, tvOS, or visionOS. Trigger on requests like "build this screen in SwiftUI," "make this UI look better/more native/more Apple-like," "design a settings page," "review my SwiftUI view for HIG compliance," or any Swift UI code that should look polished, feel native, and follow Apple's Human Interface Guidelines while remaining genuinely usable and accessible.
---

# SwiftUI Interfaces That Follow Apple's HIG and Look Genuinely Great

## Purpose

Produce SwiftUI code that is simultaneously:
1. **Visually excellent** — feels like it shipped from Cupertino, not a generic cross-platform app.
2. **HIG-compliant** — uses system idioms, spacing, and controls correctly.
3. **Usable** — accessible, legible, and forgiving of real-world content and input.
4. **Multi-platform correct** — adapts properly to whichever of iOS, iPadOS, macOS, watchOS, tvOS, and visionOS the task targets, rather than reskinning one platform's UI onto another.

Beautiful-but-wrong (a custom control that ignores Dynamic Type) and correct-but-generic (default `List` with zero design thought) are both failures here. Aim for both at once.

## Before Writing Any Code

Determine and state:
- **Target platform(s).** If unspecified and it matters (layout, navigation pattern, input method), ask or make an explicit, stated assumption (e.g., "assuming iPhone-only, portrait").
- **Minimum OS version**, if the user has one — it gates which SwiftUI APIs are safe to use (e.g., `NavigationStack` needs iOS 16+; use `NavigationView` with a deprecation note for older targets).
- **Light/dark mode**: always design for both unless told otherwise. Never hardcode a color that only works in one.

## Core Design Principles (apply to every screen)

### 1. Use system typography, don't invent it
- Use the `Font` text styles (`.largeTitle`, `.title`, `.title2`, `.title3`, `.headline`, `.body`, `.callout`, `.subheadline`, `.footnote`, `.caption`, `.caption2`) rather than fixed point sizes. These automatically scale with Dynamic Type.
- If a custom font is required, apply it via `.font(.custom(_:size:relativeTo:))` so it still scales.
- Never disable Dynamic Type scaling to "protect" a layout — fix the layout instead (see Accessibility below).

### 2. Use system color semantics, not literal colors
- Prefer semantic colors: `.primary`, `.secondary`, `Color(.systemBackground)`, `Color(.secondarySystemBackground)`, `.accentColor`, `.tint`. These adapt to light/dark mode and increased-contrast settings automatically.
- Reserve a custom accent/brand color for one deliberate spot (tint, key CTA) — don't recolor every control, or the interface stops reading as native.
- Respect `.tint()` at the right view level rather than coloring individual buttons ad hoc.

### 3. Use native components before building custom ones
- `List`, `Form`, `NavigationStack`, `NavigationSplitView`, `TabView`, `Section`, `DisclosureGroup`, `Menu`, `ContextMenu`, `Picker` styles (`.segmented`, `.wheel`, `.menu`, `.inline`), `Toggle`, `Stepper`, `Slider`, `ShareLink`, `SearchField`/`.searchable`, `Label`, `Badge`.
- A custom-built list row, custom back button, or custom tab bar is a strong signal to stop and check whether a system component already does this — custom recreations almost always miss platform behaviors (swipe actions, keyboard shortcuts, VoiceOver rotor support, right-click menus on macOS, focus engine on tvOS).
- Only build custom controls for something genuinely bespoke to the product, and then still base their touch targets, spacing, and states on system equivalents.

### 4. Layout: let the system do the work
- Prefer `VStack`/`HStack`/`Grid`/`LazyVGrid`/`LazyVStack` with **spacing via the 8pt-derived scale** (4, 8, 12, 16, 20, 24, 32...) rather than arbitrary numbers.
- Use `.padding()` without arguments to get the system default before overriding it with a reason.
- Use `Spacer()` and alignment guides instead of manually computed offsets.
- Respect safe areas; use `.ignoresSafeArea()` deliberately and rarely (e.g., background art), never for interactive content.
- On iPad and Mac, design for resizable windows and multiple size classes — check `@Environment(\.horizontalSizeClass)` rather than assuming phone-width layouts.

### 5. Materials, depth, and motion — use, don't overuse
- `.background(.ultraThinMaterial)` / `.regularMaterial` / `.thickMaterial` for native translucency (sheets, toolbars, overlays) instead of manual opacity + blur hacks.
- Elevation comes from system materials and subtle shadow, not heavy drop-shadows or borders on every element.
- Motion: prefer implicit `.animation(_:value:)` and `withAnimation` using system-feeling curves (`.spring()`, `.easeInOut`) with short durations (~0.2–0.35s for most UI). Respect `@Environment(\.accessibilityReduceMotion)` — swap or remove large motion when it's true.
- Use `matchedGeometryEffect`/`NavigationTransition`/`.contentTransition` for continuity between states rather than hard cuts, but don't animate things that don't need it — restraint is part of looking native.

### 6. Iconography
- Use SF Symbols (`Image(systemName:)`) for anything system-adjacent — they inherit weight, scale, and color from surrounding text automatically via `.imageScale()` and font weight.
- Match symbol weight/scale to the adjacent text (`.fontWeight(.semibold)` on both, or `.symbolRenderingMode(.hierarchical/.multicolor/.palette)` deliberately, not by default).
- Don't mix SF Symbols with a different icon set in the same context — visual language should be consistent.

## Platform-Specific Rules

**iOS / iPadOS**
- Navigation: `NavigationStack` (or `NavigationSplitView` for iPad master-detail). Back button, swipe-to-go-back, and large titles are free — don't fight them.
- Tab bar: max ~5 visible tabs; use `.tabViewStyle` sensibly; consider `TabView` with `Label`s that include both icon and text.
- Sheets: `.sheet` for modal tasks, `.fullScreenCover` sparingly, `.presentationDetents` for adaptive-height sheets (iOS 16+).
- Touch targets: minimum 44×44pt hit area even if the visible control is smaller — use `.contentShape(Rectangle())` and padding.
- iPad: support multitasking/Split View widths; avoid hardcoded widths that break at narrower size classes.

**macOS**
- Use `NavigationSplitView` or a sidebar `List` with `.listStyle(.sidebar)`, standard toolbar items (`ToolbarItem`), and menu bar commands (`.commands {}`) instead of iOS-style bottom bars.
- Support hover states (`.onHover`), right-click context menus, keyboard shortcuts (`.keyboardShortcut`), and resizable windows.
- Respect macOS control sizes (`.controlSize(.large/.regular/.small)`) and standard window chrome; don't imitate iOS's edge-to-edge phone layout on a desktop window.

**watchOS**
- Extremely reduced hierarchy: one primary action per screen, large tap targets, minimal text. Use `NavigationStack` with short titles, `List` for scrollable content, Digital Crown-aware scrolling.
- Avoid dense multi-column layouts entirely.

**tvOS**
- Design for the focus engine, not touch: everything interactive must be clearly focusable, with `.focusable()` and default focus-driven scaling/highlighting — don't suppress the system focus visuals.
- Larger text and spacing than any other platform; content is viewed from a distance (~10 ft design rule).

**visionOS**
- Use depth and `.glassBackgroundEffect()`/ornaments intentionally; prefer system windows and volumes over flat 2D transplants; respect eye+pinch as the primary input model (adequate hit targets, no hover-only affordances).

Don't port one platform's idiom onto another (no bottom tab bar on macOS, no hover-dependent UI on tvOS/visionOS, no dense desktop-style forms on watchOS).

## Accessibility Is Part of "Good," Not an Add-On

- Every control needs a meaningful `.accessibilityLabel`; decorative images get `.accessibilityHidden(true)`.
- Test/design against Dynamic Type up to at least "Accessibility Large" sizes — layouts should reflow (stack vertically, truncate gracefully, or scroll) rather than clip.
- Maintain WCAG-reasonable contrast; don't rely on color alone to convey state (pair with icon/text/shape).
- Support VoiceOver navigation order logically (`.accessibilitySortPriority` when the visual order and reading order diverge).
- Honor `accessibilityReduceMotion`, `accessibilityReduceTransparency` (fall back from materials to solid colors), and `accessibilityDifferentiateWithoutColor`.
- Keyboard/focus navigation must work on macOS and tvOS, not just touch.

## Workflow When Asked to Build or Improve a Screen

1. Confirm platform(s), OS minimum, and any brand constraints (colors, fonts, existing design system).
2. Sketch the view hierarchy using system containers first (List/Form/NavigationStack/etc.) before any custom styling.
3. Apply typography and color using semantic tokens, not literals.
4. Add spacing/layout using the 8pt-derived scale and safe-area-aware containers.
5. Add motion and materials last, and only where they clarify state or hierarchy.
6. Pass the accessibility checklist above.
7. If reviewing existing code rather than writing new code: call out (a) any hardcoded colors/fonts that break dark mode or Dynamic Type, (b) any custom-built control that reimplements a system one, (c) any platform-idiom mismatch, (d) any accessibility gap — in that order of priority.

## Anti-Patterns to Flag or Avoid

- Fixed pixel/point font sizes instead of text styles.
- Hardcoded hex colors for backgrounds/text instead of semantic system colors.
- Custom back buttons, custom tab bars, or custom navigation transitions that break native gestures.
- Non-44pt touch targets on touch platforms.
- Same layout copy-pasted verbatim across iPhone/iPad/Mac without adapting to size class or input model.
- Heavy custom shadows/gradients/borders on every single element ("card soup") instead of restrained, purposeful elevation.
- Animating everything by default instead of only state changes that benefit from motion.
- Ignoring `reduceMotion`/`reduceTransparency`/Dynamic Type in the name of a "designed" look.