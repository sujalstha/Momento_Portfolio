---
name: High-Contrast Kinetic System
colors:
  surface: '#f9f9f9'
  surface-dim: '#dadada'
  surface-bright: '#f9f9f9'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f3f4'
  surface-container: '#eeeeee'
  surface-container-high: '#e8e8e8'
  surface-container-highest: '#e2e2e2'
  on-surface: '#1a1c1c'
  on-surface-variant: '#5c4038'
  inverse-surface: '#2f3131'
  inverse-on-surface: '#f0f1f1'
  outline: '#916f66'
  outline-variant: '#e6beb2'
  surface-tint: '#af3100'
  primary: '#aa2f00'
  on-primary: '#ffffff'
  primary-container: '#d53d00'
  on-primary-container: '#fffbff'
  inverse-primary: '#ffb59f'
  secondary: '#5e5e5e'
  on-secondary: '#ffffff'
  secondary-container: '#e2e2e2'
  on-secondary-container: '#646464'
  tertiary: '#005da8'
  on-tertiary: '#ffffff'
  tertiary-container: '#0076d2'
  on-tertiary-container: '#fdfcff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdbd1'
  primary-fixed-dim: '#ffb59f'
  on-primary-fixed: '#3a0a00'
  on-primary-fixed-variant: '#862300'
  secondary-fixed: '#e2e2e2'
  secondary-fixed-dim: '#c6c6c6'
  on-secondary-fixed: '#1b1b1b'
  on-secondary-fixed-variant: '#474747'
  tertiary-fixed: '#d4e3ff'
  tertiary-fixed-dim: '#a4c9ff'
  on-tertiary-fixed: '#001c39'
  on-tertiary-fixed-variant: '#004883'
  background: '#f9f9f9'
  on-background: '#1a1c1c'
  surface-variant: '#e2e2e2'
typography:
  display-lg:
    fontFamily: Lexend
    fontSize: 48px
    fontWeight: '700'
    lineHeight: '1.1'
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Lexend
    fontSize: 32px
    fontWeight: '700'
    lineHeight: '1.2'
  headline-lg-mobile:
    fontFamily: Lexend
    fontSize: 28px
    fontWeight: '700'
    lineHeight: '1.2'
  headline-md:
    fontFamily: Lexend
    fontSize: 24px
    fontWeight: '600'
    lineHeight: '1.3'
  body-lg:
    fontFamily: Atkinson Hyperlegible Next
    fontSize: 20px
    fontWeight: '400'
    lineHeight: '1.6'
  body-md:
    fontFamily: Atkinson Hyperlegible Next
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.6'
  label-lg:
    fontFamily: Atkinson Hyperlegible Next
    fontSize: 16px
    fontWeight: '700'
    lineHeight: '1.2'
    letterSpacing: 0.05em
  interactive-text:
    fontFamily: Atkinson Hyperlegible Next
    fontSize: 18px
    fontWeight: '600'
    lineHeight: '1.0'
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  unit: 8px
  touch-target-min: 56px
  gutter: 24px
  margin-mobile: 20px
  margin-desktop: 40px
  stack-gap: 16px
  section-gap: 48px
---

## Brand & Style
The design system is a high-performance athletic framework engineered for maximum accessibility without compromising aesthetic sophistication. It targets athletes and active users who require ultra-high legibility and "glanceable" information during physical exertion or for those with visual impairments.

The style is **Accessible Minimalism**. It draws from the functional clarity of the Apple ecosystem but pushes contrast and structural definition much further. It avoids subtle grays and decorative blurs in favor of "hard" boundaries, generous whitespace, and a high-energy palette. The emotional response should be one of extreme confidence, clarity, and precision—eliminating any cognitive load or visual ambiguity.

## Colors
The palette is built on a "True Contrast" philosophy to meet WCAG AAA standards. 

- **Primary (#FF4B00):** A vibrant, high-energy orange reserved for primary actions and critical status indicators. When used as a background, it must only be paired with white or black text depending on the specific contrast ratio of the component size.
- **Secondary (#000000):** Pure black is used for primary text and structural borders to ensure the sharpest possible edge against the white background.
- **Neutral/Background (#FFFFFF):** A clean, pure white base provides the maximum "luminance gap" against black text.
- **Borders:** Unlike standard minimal systems that use soft grays, this design system uses 2px black borders for structural separation, ensuring users can clearly identify the boundaries of interactive zones.

## Typography
Typography is the primary tool for accessibility in this system. We pair **Lexend** (designed for reading proficiency) for headlines with **Atkinson Hyperlegible Next** for body and labels to ensure maximum character differentiation.

- **Legibility:** Leading (line height) is intentionally generous (1.6x for body) to prevent lines from blurring together.
- **Weight:** Avoid light or thin weights. Stick to Regular (400), SemiBold (600), and Bold (700) to maintain stroke thickness.
- **Sizing:** The minimum body size is 18px to ensure readability for users with low vision.

## Layout & Spacing
The layout follows a **Rigid Fluidity** model. While the grid adapts to screen size, the spacing between elements never collapses below a certain threshold to maintain "tap-accuracy."

- **Touch Targets:** Every interactive element (buttons, inputs, toggles) must have a minimum height of **56px**.
- **The 8px Rule:** All spacing is a multiple of 8px to ensure a predictable vertical rhythm.
- **Grouping:** Use large 48px gaps between distinct sections. Within sections, use 16px to 24px gaps to keep related information logically grouped but visually distinct.
- **Safe Areas:** Generous margins (20px min) ensure content does not hug the edge of the glass, preventing accidental triggers on mobile devices.

## Elevation & Depth
In this design system, depth is communicated through **High-Contrast Outlines** and **Tonal Stacking** rather than soft shadows. Shadows are often invisible to users with certain visual impairments, so we rely on structural lines.

- **Level 0 (Base):** Pure white background.
- **Level 1 (Card/Container):** White background with a 2px #000000 border. This creates a "hard" container that is unmistakable.
- **Interactive State:** When an element is focused or active, it uses a 4px #FF4B00 border or a solid #000000 fill.
- **No Blurs:** Avoid backdrop filters or blurs which can cause "visual noise." All surfaces must be opaque.

## Shapes
The shape language is "Soft-Industrial." We use subtle rounding (0.25rem to 0.75rem) to maintain a modern athletic feel, but we avoid large pill shapes for containers to maximize the internal "real estate" for large typography.

- **Components:** 4px (0.25rem) radius for buttons and inputs.
- **Cards:** 12px (0.75rem) radius for larger containers to create a distinct silhouette against the sharp-edged screen.
- **Icons:** Use thick, 2px stroke weights for all iconography to match the border language of the UI.

## Components

### Buttons
- **Primary:** Solid #FF4B00 background with #FFFFFF or #000000 text (whichever hits AAA for the specific size). 56px minimum height. 
- **Secondary:** #FFFFFF background with a 2px #000000 border.
- **States:** Hover/Active states should invert the colors or increase border thickness to 4px.

### Input Fields
- **Style:** White background, 2px #000000 border. 
- **Labels:** Must be outside the field (Top-aligned) in Bold black text. Placeholder text must be #767676 or darker to ensure legibility.
- **Focus:** 4px #FF4B00 border.

### Cards & Lists
- **Cards:** White surface, 2px black border, no shadow. 
- **Lists:** Each list item should be separated by a 2px black divider or placed in individual bordered containers with a 12px gap.

### Selection Controls (Checkboxes/Radio)
- **Size:** Minimum 32px x 32px hit area for the graphic itself, within a 56px touch target container.
- **Check State:** Use a thick (3px) checkmark or a solid fill to ensure the "selected" state is high-contrast and obvious.

### Athletic Metrics (Custom Component)
- Large-scale display of data (e.g., Heart Rate, Pace). 
- Use **Lexend Bold** for numbers at 48px+. 
- Pair with a 2px black border box to "frame" the data as the most important element on the screen.