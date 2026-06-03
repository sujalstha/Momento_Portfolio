# Handoff: Momento — Accessibility-First Run Coach App

> **Target platform:** iOS / Xcode / SwiftUI
> **Audience:** runners who are blind, low-vision, or simply prefer audio-first interaction
> **Aesthetic:** Liquid Glass — translucent floating chrome over ambient gradient backdrops, in the visionOS / iOS 18+ idiom

---

## About these design files

The files in this bundle are **design references created in HTML/CSS/React** — clickable prototypes showing the intended look, layout, and interaction flow. **They are not production code to ship.**

The task is to **recreate these designs in SwiftUI** (iOS 17+, ideally 18+) using Apple-native patterns:

- `Material.ultraThinMaterial` / `.regularMaterial` for the glass surfaces
- `NavigationStack` and `TabView` (or a custom segmented control at the top — see notes)
- `AVSpeechSynthesizer` for Echo's voice, `Speech` framework for STT
- `HealthKit` for run metrics, `CoreMotion` + `CoreLocation` for live tracking
- `Sign in with Apple` (`AuthenticationServices`) and Google Sign-In SDK
- **VoiceOver-first**: every tappable element must have an `.accessibilityLabel`, `.accessibilityHint`, and a tap target ≥ 44pt (most are 56–72pt)

---

## Fidelity

**Hi-fi.** Spacing, typography, colors, and copy are deliberate. Match them. The hand-drawn variations in `Momento Wireframes (sketchy).html` are exploration archives — the canonical design is **`Momento Wireframes.html`**.

---

## Color palette

All accents are from the **Okabe-Ito colorblind-safe palette**. Don't substitute.

| Token            | Hex       | Used for                                       |
|------------------|-----------|------------------------------------------------|
| `text`           | `#0B0B0F` | Primary text on light                          |
| `text-2`         | `rgba(60,60,67,0.78)` | Secondary text                     |
| `text-3`         | `rgba(60,60,67,0.55)` | Tertiary text / captions / eyebrows |
| `text-4`         | `rgba(60,60,67,0.28)` | Quaternary / disabled              |
| `hairline`       | `rgba(60,60,67,0.12)` | List dividers                      |
| `accent` (orange)| `#E48700` | Single accent — used at most once per screen   |
| `blue`           | `#0072B2` | Reserved (links, info)                         |
| `green`          | `#009E73` | "Live" / "connected" dots                      |
| `verm` (red-orange) | `#D55E00` | Destructive (Sign out), record state         |

### Backdrops (gradient blobs behind every screen)

Backdrops are radial gradients that sit behind everything; they give the glass material something to refract. SwiftUI: use a `ZStack` with the gradient at the bottom and `Material.ultraThinMaterial` on the floating chrome.

| Backdrop name | Recipe                                                                                  |
|---------------|-----------------------------------------------------------------------------------------|
| **bd-dawn**   | warm peach: `#FFD9A8` top-left, `#FFAA66` top-right, base `#FCE8D2 → #F4D8C0`           |
| **bd-mist**   | cool lavender: `#E8E4F2`, `#D8E0EE`, base `#F0EFF5 → #E0E1EA`                            |
| **bd-mint**   | cool green-blue: `#D6EFE3`, `#C0E2D5`, base `#E8F5EE → #D3E9DD`                          |

In SwiftUI:

```swift
struct DawnBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "FCE8D2"), Color(hex: "F4D8C0")],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color(hex: "FFD9A8"), .clear],
                           center: .topLeading, startRadius: 0, endRadius: 480)
                .blur(radius: 60)
            RadialGradient(colors: [Color(hex: "FFAA66"), .clear],
                           center: .topTrailing, startRadius: 0, endRadius: 440)
                .blur(radius: 60)
        }
        .ignoresSafeArea()
    }
}
```

---

## Typography

System font (SF Pro Display + SF Pro Text). Tabular numerals via `.monospacedDigit()` on all metric numerals.

| Style       | Size   | Weight  | Letter spacing | SwiftUI                                          |
|-------------|--------|---------|----------------|--------------------------------------------------|
| Title XL    | 42–56pt| Bold    | -3.5%          | `.font(.system(size: 56, weight: .bold))` + `.tracking(-2)` |
| Title L     | 34pt   | Bold    | -2.8%          | `.font(.system(size: 34, weight: .bold))`        |
| Title M     | 26pt   | Bold    | -2.2%          | `.font(.system(size: 26, weight: .bold))`        |
| Title S     | 20pt   | Semibold| -1.5%          | `.font(.system(size: 20, weight: .semibold))`    |
| Body        | 17pt   | Regular | -0.5%          | `.font(.body)`                                   |
| Callout     | 16pt   | Regular | -0.5%          | `.font(.callout)`                                |
| Footnote    | 13pt   | Regular | —              | `.font(.footnote)`                               |
| Caption     | 12pt   | Medium  | -0.5%          | `.font(.caption)`                                |
| Eyebrow     | 11pt   | Semibold| +12% UPPERCASE | `.font(.system(size: 11, weight: .semibold)).tracking(1.3).textCase(.uppercase)` |
| Big metric  | 80pt   | Bold    | -4%            | `.font(.system(size: 80, weight: .bold)).monospacedDigit()` |

---

## Spacing & radii

- Horizontal screen padding: **20pt**
- Vertical rhythm between groups: **22pt**
- Padding inside cards: **16–22pt**
- Padding inside list rows: **14pt vertical, 18pt horizontal**
- Gap between list rows / cards: **12–14pt**
- Border radii: small **12pt**, default **18pt**, large **26pt**, hero **36pt**, capsule **999pt**
- Hairline divider: **0.5pt** at 12% opacity, inset 18pt from row left edge

---

## Glass material recipe (SwiftUI)

```swift
struct GlassCard<Content: View>: View {
    let content: () -> Content
    var body: some View {
        content()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.06), radius: 0, y: 0)
            .shadow(color: .black.opacity(0.28), radius: 38, x: 0, y: 18)
    }
}
```

A subtle top-edge specular highlight is part of the look — overlay a `LinearGradient(colors: [.white.opacity(0.18), .clear])` masked to the top 50%.

---

## App flow

```
Sign in → Onboarding (5 steps) → Tab root
                                  ├─ Run (default)
                                  ├─ History  →  Metric detail
                                  └─ Settings → Personal details
                                                Echo's voice
                                                Units
                                                Help center / Contact / Privacy
```

The three top-level tabs are presented as a **top segmented control** (not the iOS bottom tab bar). All three screens carry the same segmented control at the top.

---

## Screens

### 1 · Sign in

**Purpose:** authenticate via Apple or Google. Apple-first because of the audience.

**Layout (top → bottom):**
1. Status bar
2. Top block: eyebrow "welcome" (11pt uppercase, tracking +12%, text-3) + headline "Momento" (56pt bold, -3.5% tracking)
3. Center: 196×196 blue orb (radial gradient `#6BB6F0 → #2C72B8 → #0C2F5B`, inset highlights, drop shadow `rgba(20,50,95,0.5) 0 30 60 -10`)
4. Bottom: glass card containing
   - "Continue with Apple" — black filled capsule, white Apple glyph + label
   - "Continue with Google" — glass capsule (ultraThinMaterial), color Google G + label
   - Hairline "or" divider
   - "Use email" — plain text button (text-2)

**Backdrop:** `bd-dawn`.

**Tap targets:** all primary buttons ≥ 58pt tall.

**Behavior:**
- "Continue with Apple" → `SignInWithAppleButton`
- "Continue with Google" → GoogleSignIn SDK
- On success → navigate to Onboarding step 1 (if new user) or directly to Run tab (returning user)
- VoiceOver: announce "Momento. Sign in with Apple or Google."

---

### 2 · Onboarding — Voice prompt

**Voice activation is always-on during onboarding.** No "Tap to speak" button.

5-step flow collects: **Name → Age → Gender → Height → Weight**. Only the Name step is shown in the mockup; replicate the same template for the other four.

**Layout:**
1. Top bar (44pt): back chevron (glass icon button) · 5-segment progress (current step filled with text color) · "2 / 5" caption
2. After 28pt gap: eyebrow "echo says", title "What should I call you?", callout "Just say your name — I'm listening."
3. Center (flex-1): the orb with a pulsing dashed ring (`scale 1 → 1.5`, opacity `0.65 → 0`, 2.5s ease-out infinite). Below it: waveform of 14 vertical bars (heights `[10,18,30,50,40,68,46,28,18,32,52,40,22,12]`). Below that: "Listening" pill with a 8pt vermilion dot wrapped in a 4pt soft halo.

**Backdrop:** `bd-mist`.

**Behavior:**
- On screen appear: start `SFSpeechRecognizer`, also `AVSpeechSynthesizer.speak("What should I call you?")` after a 600ms delay
- When the recognizer finishes a final transcription, persist it, advance to step 3
- Steps for height/weight: same template, but the spoken value parses into number + unit
- VoiceOver users: rely on the natural speech I/O — but expose an alternative typed input via a "double-tap to type" gesture; trigger a `TextField` sheet

**Important:** the design intentionally has no "type instead" button. Voice is the default. Provide a hidden but discoverable gesture (long-press the orb, or 3-finger double-tap) to open a text fallback for those who can't or don't want to speak.

---

### 3 · Home (Run tab)

**Layout:**
1. Status bar
2. Top segmented control (Run / History / Settings) — Run on
3. After 22pt gap:
   - Left column: caption "TUE · MAY 23", title "Ready, Priya?" (36pt bold, -2.8%), callout "Last run was 4.2 km, easy."
   - Right column: "Watch on" green-dot pill
4. Vertical center (flex-1 in the remaining space): **single circular start CTA**, 232×232pt
   - Glass-strong fill (`Material.regularMaterial`)
   - Specular top highlight + subtle bottom inner shadow
   - Drop shadow `0 30 60 -20 rgba(15,20,35,0.3)`
   - Contents stacked: orange play triangle (24pt) · "Start run" (26pt bold) · "Live coach" caption (11pt uppercase tracking +12%, text-3)
5. Bottom: footnote "Triple-tap anywhere to start."

**Backdrop:** `bd-dawn`.

**No "Start without coach" button.** The product decision is **coached runs only.**

**Behavior:**
- Tap CTA → push `RunSessionView` (countdown 3-2-1, then begin)
- Triple-tap gesture anywhere on the screen does the same thing
- VoiceOver label on the CTA: "Start coached run. Triple-tap anywhere to start."

---

### 4 · History tab

**Layout:**
1. Status bar
2. Top segmented control — History on
3. After 22pt gap: caption "YOUR RUNS", title "History" (34pt bold)
4. After 18pt gap: vertical stack of session cards (12pt gap between)

**Session card** (172pt min height, glass material):
- Top row: orange "Coached" pill (with small headphone icon) on the left · "Yesterday · 7:14 AM" caption on the right
- Bottom row: large metric ("4.2 km" at 56pt bold tabular) on the left · callout `34:12 · 8:08 /mi` on the right with a chevron beyond it
- The whole card is tappable → push `MetricDetailView` for that session

**Show at most 2 sessions in this view.** Older runs are not surfaced here (the user explicitly wanted this trimmed; older runs sync to Apple Health silently in the background).

**Backdrop:** `bd-mist`.

---

### 5 · Metric detail

**Pushed from a history card.** Not part of the tab navigation.

**Layout (vertically scrollable):**
1. Top: "‹ History" glass pill button (back) — left aligned
2. After 14pt gap: **"Hear full summary" button** at the very top — full-width glass-strong capsule, speaker icon + label
3. After 22pt gap: eyebrow "Friday May 22 · 7:14 AM", title "Morning run" (34pt)
4. After 14pt gap: hero metric — "4.2" (80pt bold tabular) + "km" (18pt semibold, text-3)
5. Callout: `in 34:12 · 8:08 /mi avg · coached` (`34:12` bold)
6. After 18pt gap: glass card containing 7 metric rows (the rows from the spec). Each row is a `HStack` with a left label and a right-aligned big number + small unit:
   - Heart rate · `152` · BPM AVG
   - Cadence · `168` · SPM
   - Power · `241` · W
   - Stride length · `1.14` · M
   - Calories · `312` · KCAL
   - Blood oxygen · `97` · %
   - Elevation gain · `+38` · M
   - **(Add to the implementation, but not in the mockup — pull all metrics from `GemmaCoach-Metrics.md` if available.)**

**No share button.** No bottom button (the summary button is at the top).

**Backdrop:** `bd-dawn`.

**Behavior:**
- "Hear full summary" → `AVSpeechSynthesizer` reads a generated paragraph: "Your run yesterday was 4.2 kilometers in 34 minutes 12 seconds, average pace 8 minutes 8 seconds per mile. Average heart rate 152 beats per minute. …" etc.
- Each row should be a `Button` with VoiceOver label like "Heart rate, 152 beats per minute average."

---

### 6 · Settings tab

**Layout (scrollable):**
1. Status bar
2. Top segmented control — Settings on
3. After 22pt gap: title "Settings" (34pt bold)
4. After 18pt gap: **profile glass card** (P avatar 48×48pt black circle · name "Priya Shah" · email caption · chevron)
5. After 22pt gap: eyebrow "Profile" → list with 1 row:
   - Personal details
6. After 22pt gap: eyebrow "Coaching" → list with 2 rows:
   - Echo's voice  → value "Maya"
   - Units → value "Imperial"
7. After 22pt gap: eyebrow "Support" → list with 3 rows:
   - Help center
   - Contact us
   - Privacy & data
8. After 18pt gap: "Sign out" full-width glass button, text color `#D55E00` (vermilion)
9. Footnote "Momento v1.0"

**List row spec** (every row identical):
- Min height: **56pt**
- Padding: 14pt vertical, 18pt horizontal
- HStack with 14pt gap: icon (26pt, text-2 stroke) · title (17pt medium) · spacer · optional value (16pt, text-2) · chevron (16pt, text-4)
- Between rows: 0.5pt hairline at 12% opacity, inset 18pt from the row's left edge

**Backdrop:** `bd-mist`.

**Behavior:**
- Tapping the profile card opens an edit sheet for name + email
- "Echo's voice" → push a picker view (Maya, Theo, Sky, etc — implement 3-4 voices wired to `AVSpeechSynthesisVoice` candidates)
- "Units" → toggle between Imperial / Metric, persist to `@AppStorage`
- "Sign out" → destructive confirmation alert → clear keychain credentials, return to Sign in

---

## Interactions & states

- **Button press:** 0.985× scale, 80ms ease (matches the HTML)
- **Card press:** same, plus a slight shadow lift
- **VoiceOver focus:** Apple's default ring is fine; do not override
- **Loading states:** for the orb during onboarding STT, the pulsing ring already conveys it; no spinner needed
- **Error states:**
  - Sign-in failure → glass card slides up with a clear error and a "Try again" button
  - STT failure during onboarding → Echo speaks "I didn't catch that — could you say it again?"
  - No watch/sensor connection on Run start → glass alert "Your watch isn't connected. Continue with phone only?"

---

## State management

```swift
// Top-level app state
@StateObject private var auth = AuthStore()            // current user, sign-in state
@StateObject private var profile = ProfileStore()      // name, age, gender, height, weight, units
@StateObject private var coach = CoachStore()          // voice id, chattiness (omit if you keep my edit)
@StateObject private var history = HistoryStore()      // last N sessions, lightweight summaries
@StateObject private var session = RunSessionStore()   // live during a run
```

Persistence:
- Profile + settings → `@AppStorage` + `Keychain` for auth token
- Sessions → `SwiftData` model `RunSession { id, startedAt, distance, duration, heartRate*, cadence, …, isCoached }`
- Sync sessions to **HealthKit** as `HKWorkout` on completion

---

## Accessibility — non-negotiable

- Every `Button`, every `Image`, every interactive surface: `.accessibilityLabel("…")` and `.accessibilityHint("…")`
- Group metric rows with `.accessibilityElement(children: .combine)` so VoiceOver reads "Heart rate 152 beats per minute" as one focus
- Dynamic Type: support up to `AX5`. Test every screen at `accessibility5` text size — let cards wrap, never truncate metric numerals
- Reduce Motion: kill the pulsing ring and the wave bars when `accessibilityReduceMotion` is true
- Reduce Transparency: swap `.ultraThinMaterial` for a solid `Color(.secondarySystemBackground)` when `accessibilityReduceTransparency` is true
- Increase Contrast: bump `text-3` to `text-2` opacity when `colorSchemeContrast == .increased`
- All hit targets ≥ 44pt (most are 56–72pt — keep them that way)
- The Echo voice is the primary I/O channel — every screen must work eyes-closed via VoiceOver alone

---

## Design tokens — reference dump

```swift
enum DT {
    static let textPrimary   = Color(hex: "0B0B0F")
    static let textSecondary = Color(.black).opacity(0.78)
    static let textTertiary  = Color(.black).opacity(0.55)
    static let textQuat      = Color(.black).opacity(0.28)
    static let hairline      = Color(.black).opacity(0.12)
    static let accent        = Color(hex: "E48700")
    static let blue          = Color(hex: "0072B2")
    static let green         = Color(hex: "009E73")
    static let vermilion     = Color(hex: "D55E00")

    enum Spacing { static let xs=4.0, sm=8.0, md=14.0, lg=22.0, xl=28.0 }
    enum Radius  { static let sm=12.0, md=18.0, lg=26.0, xl=36.0 }
}
```

---

## Files in this bundle

| File                                | What it is                                                  |
|-------------------------------------|-------------------------------------------------------------|
| `README.md`                         | This document                                               |
| `Momento Wireframes.html`           | **Canonical** clickable prototype — the spec                |
| `glass-styles.css`                  | Complete CSS reference (radii, colors, materials)           |
| `glass-screens.jsx`                 | React/JSX source for all six screens                        |
| `design-canvas.jsx`                 | Canvas chrome (not part of the app — just the presentation) |
| `GemmaCoach-Metrics.md`             | Master metric reference: every metric the run engine emits  |
| `Momento Wireframes (sketchy).html` | Lo-fi exploration — for context only                        |
| `Momento Wireframes (apple).html`   | Earlier hi-fi exploration — for context only                |

---

## Implementation order (suggested)

1. **Foundation**: set up the project, add the color/typography tokens, build the `GlassCard`, `GlassButton`, `Backdrop*`, and `SegmentedTabs` primitives. Verify the materials against the HTML before moving on.
2. **Sign in**: simplest screen, validates the material recipe and the type ramp.
3. **Onboarding step 1** (Name): wires up `Speech` framework. Get this right and the other four steps copy-paste.
4. **Tab root** with empty Run/History/Settings stubs.
5. **Settings**: pure data display, no live sensors — fastest way to validate the list-row template.
6. **History** + **Metric detail**: read from a seeded SwiftData store first, then wire to real runs later.
7. **Run session**: the big one — `HealthKit` workout, `CoreLocation`, `AVSpeechSynthesizer` for live coaching.

Open `Momento Wireframes.html` in a browser, then zoom into a screen and use that as your visual reference while coding. The artboards are 390×800 — that's a stand-in for the iPhone 15 viewport at @1x, so 1px in the mock ≈ 1pt in Xcode.
