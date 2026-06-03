---
name: High-Performance Athletic System
colors:
  surface: '#faf9fe'
  surface-dim: '#dad9df'
  surface-bright: '#faf9fe'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f4f3f8'
  surface-container: '#eeedf3'
  surface-container-high: '#e9e7ed'
  surface-container-highest: '#e3e2e7'
  on-surface: '#1a1b1f'
  on-surface-variant: '#4c4546'
  inverse-surface: '#2f3034'
  inverse-on-surface: '#f1f0f5'
  outline: '#7e7576'
  outline-variant: '#cfc4c5'
  surface-tint: '#5e5e5e'
  primary: '#000000'
  on-primary: '#ffffff'
  primary-container: '#1b1b1b'
  on-primary-container: '#848484'
  inverse-primary: '#c6c6c6'
  secondary: '#745b00'
  on-secondary: '#ffffff'
  secondary-container: '#fecb00'
  on-secondary-container: '#6e5700'
  tertiary: '#000000'
  on-tertiary: '#ffffff'
  tertiary-container: '#002107'
  on-tertiary-container: '#00993b'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#e2e2e2'
  primary-fixed-dim: '#c6c6c6'
  on-primary-fixed: '#1b1b1b'
  on-primary-fixed-variant: '#474747'
  secondary-fixed: '#ffe08b'
  secondary-fixed-dim: '#f1c100'
  on-secondary-fixed: '#241a00'
  on-secondary-fixed-variant: '#584400'
  tertiary-fixed: '#72fe88'
  tertiary-fixed-dim: '#53e16f'
  on-tertiary-fixed: '#002107'
  on-tertiary-fixed-variant: '#00531c'
  background: '#faf9fe'
  on-background: '#1a1b1f'
  surface-variant: '#e3e2e7'
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
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 30px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.05em
  stats-number:
    fontFamily: Inter
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.04em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 8px
  container-margin: 24px
  gutter: 16px
  section-padding: 40px
---

## Brand & Style

This design system is rooted in the philosophy of **Functional Minimalism**. It aims to evoke a sense of clarity, discipline, and premium performance, much like high-end athletic gear. The target audience consists of dedicated athletes who require immediate access to data without visual noise.

The visual style is **Corporate Modern with a Minimalist edge**, emphasizing "content over chrome." It utilizes heavy whitespace to reduce cognitive load and focuses on a strict hierarchy to guide the user's eye toward critical metrics. The emotional response should be one of calm focus—providing the user with the "mental space" to perform.

## Colors

The palette is strictly monochromatic with functional high-visibility accents. 

- **Primary Black (#000000):** Used for primary actions, headings, and high-impact text to ensure maximum contrast (WCAG AAA).
- **Functional Amber (#FFCC00):** Reserved for "In Progress" states, highlights, and secondary calls-to-action, drawing inspiration from high-visibility athletic apparel.
- **Surface Grays:** A tiered system of light grays (`#F2F2F7` for backgrounds, `#E5E5EA` for borders) creates subtle depth without relying on heavy shadows.
- **Success Green (#34C759):** Used sparingly for completed goals and "Go" states.

## Typography

The design system uses **Inter** for its exceptional legibility and neutral, systematic feel. 

- **Hierarchy:** Use `stats-number` for primary athletic data (e.g., pace, heart rate). Headings should be bold and tight to feel authoritative.
- **Accessibility:** Minimum body text size is set to 16px to ensure readability during physical activity. 
- **Letter Spacing:** Headlines use slight negative tracking to appear more "locked-in" and premium, while small labels use increased tracking for legibility at a glance.

## Layout & Spacing

The system follows a **Fluid Grid** model with a base-8 spacing scale. 

- **Margins:** Large 24px side margins on mobile to ensure content isn't cramped near screen edges.
- **Rhythm:** Vertical spacing between cards and sections should be generous (32px or 40px) to allow the "minimalist" aesthetic to breathe. 
- **Breakpoints:** 
    - Mobile (<600px): 4 columns.
    - Tablet (600px - 1024px): 8 columns.
    - Desktop (>1024px): 12 columns with a max-width container of 1440px.

## Elevation & Depth

To maintain a clean, Apple-inspired look, depth is communicated through **Tonal Layers** rather than heavy shadows.

- **Level 0 (Background):** Base surface in `#F2F2F7`.
- **Level 1 (Cards):** Primary content containers in pure white (`#FFFFFF`).
- **Subtle Ambient Shadows:** Use only for "floating" elements like FABs or active Modals. Shadows should be ultra-diffused: `0px 10px 30px rgba(0,0,0,0.04)`.
- **Outlines:** Use 1px solid borders in `#E5E5EA` for secondary cards to define boundaries without adding visual weight.

## Shapes

The shape language is defined by **Soft Geometricism**. 

- **Cards:** Use `rounded-lg` (1rem) to feel modern yet structured.
- **Buttons:** Use `rounded-xl` (1.5rem) or full pills for high-action areas to provide a tactile, "clickable" feel.
- **Icons:** Should follow the same corner radius logic—avoid sharp corners in iconography to maintain visual harmony with the UI containers.

## Components

### Buttons
- **Primary:** Solid black background with white text. High-contrast and bold.
- **Secondary:** Light grey background (`#E5E5EA`) with black text for less critical actions.
- **Ghost:** No background, black border, or just text for tertiary navigation.

### Cards
- Always white background.
- Include a subtle internal padding of 20px - 24px.
- Group related metrics together within a single card to minimize fragmentation.

### Input Fields
- Understated design: a simple light grey bottom border that turns black on focus. 
- Labels should always be visible (no disappearing placeholders) to maintain accessibility.

### Chips & Status Indicators
- Use the functional Amber (`#FFCC00`) for active states.
- Status chips should use a light tint of the status color with high-contrast text (e.g., Light Amber background with Black text).

### Progress Bars
- Thick, 8px tracks for visibility. Use high-contrast black for the progress fill against a light grey track.