---
name: Pro-Active Athletic System
colors:
  surface: '#fcf8fb'
  surface-dim: '#dcd9dc'
  surface-bright: '#fcf8fb'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f6f3f5'
  surface-container: '#f0edef'
  surface-container-high: '#eae7ea'
  surface-container-highest: '#e4e2e4'
  on-surface: '#1b1b1d'
  on-surface-variant: '#5c4038'
  inverse-surface: '#303032'
  inverse-on-surface: '#f3f0f2'
  outline: '#916f66'
  outline-variant: '#e6beb2'
  surface-tint: '#af3100'
  primary: '#aa2f00'
  on-primary: '#ffffff'
  primary-container: '#d53d00'
  on-primary-container: '#fffbff'
  inverse-primary: '#ffb59f'
  secondary: '#406900'
  on-secondary: '#ffffff'
  secondary-container: '#9df800'
  on-secondary-container: '#436e00'
  tertiary: '#0058bc'
  on-tertiary: '#ffffff'
  tertiary-container: '#0070eb'
  on-tertiary-container: '#fefcff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdbd1'
  primary-fixed-dim: '#ffb59f'
  on-primary-fixed: '#3a0a00'
  on-primary-fixed-variant: '#862300'
  secondary-fixed: '#9ffb00'
  secondary-fixed-dim: '#8bdc00'
  on-secondary-fixed: '#102000'
  on-secondary-fixed-variant: '#2f4f00'
  tertiary-fixed: '#d8e2ff'
  tertiary-fixed-dim: '#adc6ff'
  on-tertiary-fixed: '#001a41'
  on-tertiary-fixed-variant: '#004493'
  background: '#fcf8fb'
  on-background: '#1b1b1d'
  surface-variant: '#e4e2e4'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 30px
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 17px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 20px
  label-caps:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
  status-indicator:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '700'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  gutter: 16px
  margin-mobile: 20px
  margin-desktop: 40px
  stack-sm: 8px
  stack-md: 16px
  stack-lg: 32px
---

## Brand & Style

The design system is defined by a "Pro-Athletic" aesthetic: a fusion of Apple’s uncompromising minimalism and Strava’s high-energy utility. It targets a sophisticated audience that values precision, safety, and performance. 

The visual language utilizes a **Modern-Corporate** foundation with **Glassmorphism** accents. It moves away from heavy, saturated dark themes in favor of a "Light Pro" look—utilizing pure whites, subtle gray scales, and expansive negative space to create a sense of air and focus. The emotional response is one of calm confidence, reliability, and high-fidelity precision.

Key attributes:
- **Cleanliness:** Massive whitespace to reduce cognitive load during activity.
- **Precision:** Razor-sharp typography and thin, purposeful borders.
- **Urgency through Contrast:** High-visibility accents are used sparingly but decisively for critical status updates like collision detection.

## Colors

The palette is anchored in a high-contrast "Pro Light" scheme. 

- **Primary (Electric Orange):** Derived from performance heritage, used for primary actions and brand presence.
- **Secondary (High-Vis Lime):** Reserved specifically for the "Collision Detection" and safety-critical states. This color provides maximum luminous contrast against both light and dark backgrounds.
- **Neutral (The Gray Scale):** Uses a range of cool grays. Backgrounds stay pure white (#FFFFFF), while secondary surfaces use a soft "System Gray" (#F2F2F7).
- **Text:** Uses an almost-black (#1C1C1E) for maximum legibility and AA/AAA accessibility compliance.

## Typography

The typography system relies on **Inter** for its systematic, utilitarian clarity, emulating the San Francisco aesthetic. It features tight letter spacing in headlines for a "tight" professional feel.

- **Headlines:** Bold and impactful, using negative letter-spacing to feel cohesive.
- **Body:** Sized at 17px for primary reading to match iOS standards, ensuring high legibility during movement.
- **Monospace Accents:** **JetBrains Mono** is used for data points (GPS coordinates, time, distance) to give the UI a technical, precise "instrument" feel.
- **Safety Labels:** Use the `status-indicator` style, prioritizing immediate recognition over stylistic flair.

## Layout & Spacing

The system follows a **Fluid Grid** model heavily influenced by Strava’s generous vertical rhythm. 

- **The 4px Base:** All spacing must be a multiple of 4px.
- **Safe Zones:** Mobile layouts utilize a 20px side margin to ensure content is never cramped against the bezel.
- **Content Grouping:** Use "Stack Spacing" to create clear hierarchy. Elements within a card use `stack-sm` (8px), while distinct cards in a feed use `stack-lg` (32px) to provide significant white space breathing room.
- **The "Dynamic Island" Philosophy:** Status-level information (like Collision Detection) should be anchored to the top of the viewport or within a floating container, separated from the scrollable feed.

## Elevation & Depth

This design system uses **Tonal Layers** and **Ambient Shadows** to define hierarchy without visual clutter.

- **Level 0 (Base):** #FFFFFF.
- **Level 1 (Cards):** Soft neutral background (#F2F2F7) or white with a very thin (0.5px) inside stroke in Gray 200.
- **Floating Elements:** Use a "Pro Shadow"—an extra-diffused, 10-15% opacity black shadow with a 20px blur and 4px vertical offset. 
- **Glassmorphism:** Tab bars and top navigation headers use a `backdrop-filter: blur(20px)` with a 80% translucent white background to maintain context of the content underneath.

## Shapes

The shape language is **Rounded**, following the Apple squircle aesthetic. 

- **Primary Containers:** 1rem (16px) corner radius.
- **Buttons:** 1rem (16px) or fully pill-shaped for secondary actions.
- **Interactive Chips:** Fully pill-shaped to distinguish them from structural cards.
- **Collision Detection Indicator:** Uses a slightly more aggressive 12px radius or a distinct "squircle" to feel integrated into the hardware-software boundary.

## Components

### Buttons
- **Primary:** Solid #FF4B00 with white text. No gradient, just pure color. High-gloss "press" state.
- **Secondary:** Ghost style with a 1px border of Gray 300 or a soft gray fill.

### Collision Detection "Pro" Status
This is a flagship component. It should not look like a standard label. 
- **Style:** A floating pill at the top of the screen.
- **Treatment:** Uses a "breathing" subtle glow of Secondary (Lime). It features a small, pulsing dot icon next to the JetBrains Mono "ACTIVE" text.
- **Interaction:** Tapping expands the pill into a full-screen safety dashboard using a layout transition.

### Cards
- **Feed Cards:** White background with a 0.5px border. No heavy shadows. Typography does the heavy lifting for separation.
- **Map Cards:** Edge-to-edge imagery within the card, with data overlays using the Glassmorphism blur effect.

### Input Fields
- Understated. A simple light gray bottom border that turns Primary Orange when focused. No boxes unless required for high-glare environments.

### Lists
- Clean rows with 1px hairline dividers that do not reach the full width of the screen (inset dividers).