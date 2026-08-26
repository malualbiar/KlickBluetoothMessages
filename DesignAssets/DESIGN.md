---
name: Bit-Mechanical
colors:
  surface: '#131313'
  surface-dim: '#131313'
  surface-bright: '#393939'
  surface-container-lowest: '#0e0e0e'
  surface-container-low: '#1c1b1b'
  surface-container: '#201f1f'
  surface-container-high: '#2a2a2a'
  surface-container-highest: '#353534'
  on-surface: '#e5e2e1'
  on-surface-variant: '#d2c5ad'
  inverse-surface: '#e5e2e1'
  inverse-on-surface: '#313030'
  outline: '#9b8f7a'
  outline-variant: '#4e4634'
  surface-tint: '#f3bf32'
  primary: '#ffd05e'
  on-primary: '#3f2e00'
  primary-container: '#e6b325'
  on-primary-container: '#5e4700'
  inverse-primary: '#775a00'
  secondary: '#c8c6c5'
  on-secondary: '#313030'
  secondary-container: '#474746'
  on-secondary-container: '#b7b5b4'
  tertiary: '#b2dbff'
  on-tertiary: '#003450'
  tertiary-container: '#70c2ff'
  on-tertiary-container: '#004f76'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffdf99'
  primary-fixed-dim: '#f3bf32'
  on-primary-fixed: '#251a00'
  on-primary-fixed-variant: '#5a4300'
  secondary-fixed: '#e5e2e1'
  secondary-fixed-dim: '#c8c6c5'
  on-secondary-fixed: '#1c1b1b'
  on-secondary-fixed-variant: '#474746'
  tertiary-fixed: '#cbe6ff'
  tertiary-fixed-dim: '#8fcdff'
  on-tertiary-fixed: '#001e30'
  on-tertiary-fixed-variant: '#004b71'
  background: '#131313'
  on-background: '#e5e2e1'
  surface-variant: '#353534'
typography:
  headline-lg:
    fontFamily: Space Mono
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Space Mono
    fontSize: 18px
    fontWeight: '700'
    lineHeight: 24px
    letterSpacing: 0em
  body-lg:
    fontFamily: JetBrains Mono
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 24px
    letterSpacing: -0.01em
  body-md:
    fontFamily: JetBrains Mono
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0em
  label-caps:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '800'
    lineHeight: 16px
    letterSpacing: 0.1em
  status-pixel:
    fontFamily: JetBrains Mono
    fontSize: 10px
    fontWeight: '700'
    lineHeight: 12px
    letterSpacing: 0.05em
spacing:
  pixel-unit: 4px
  gutter: 16px
  margin-edge: 24px
  key-gap: 2px
---

## Brand & Style
The design system draws inspiration from high-end executive mobile devices of the late 2000s, blending industrial hardware aesthetics with a functional monochrome interface. The brand personality is disciplined, focused, and premium. It evokes a tactile, intentional experience where every interaction feels physical and deliberate.

The design style is a hybrid of **Tactile/Skeuomorphic hardware** and **Minimalist Bitmap software**. It rejects modern fluidities in favor of rigid grids, high-contrast monochrome displays, and clear physical boundaries. The user interface mimics a warm LCD panel embedded within precision-milled dark charcoal casing, emphasizing clarity over decoration.

## Colors
The palette is divided between the "Hardware" (the housing) and the "Display" (the active UI).

- **The Display Core (#E6B325):** A warm, golden-yellow monochrome LCD glow. All functional interface elements exist within this color space.
- **The Hardware Base (#121212, #1A1A1A):** Deep charcoal and near-black shades used for the device body and physical key textures.
- **The Ink (#0F0F0F):** A near-black used exclusively for text and icons appearing on the golden display.

Interaction states should avoid transparency. Selection is indicated by inverting the colors: a #0F0F0F background with #E6B325 text.

## Typography
Typography must maintain a technical, fixed-width character to simulate bitmap rendering. 

- **Headlines:** Use **Space Mono** for a structured, geometric feel. These should be kept short and impactful.
- **Body & Labels:** Use **JetBrains Mono** for its high legibility at small sizes and "developer-grade" precision.
- **Scaling:** On mobile/small display viewports, reduce `headline-lg` to 20px. 
- **Rendering:** Anti-aliasing should be sharp. Text should never use gradients. Use "Inversion" (light text on dark block) for primary emphasis or selection.

## Layout & Spacing
The layout follows a **Fixed Grid** model mimicking a physical screen aspect ratio (typically 4:3 or 1:1). 

- **Display Spacing:** Use a strict 4px baseline unit. Content within the "LCD" should have a 12px internal safe area.
- **Hardware Layout:** The physical QWERTY and D-pad area uses a tight 2px gap between keys to emphasize a precision-milled look.
- **Alignment:** All text should be strictly left-aligned or centered within its block. No staggered or fluid layouts. 
- **Navigation:** The layout is driven by a central D-pad. Elements should be arranged in a clear vertical list or a 3x3/4x4 grid to accommodate 4-way directional input.

## Elevation & Depth
Depth is handled differently for the hardware and the software:

- **Hardware (Physical):** Use hard, inner shadows and subtle 1px highlights on the top edges of keys to create a "milled" tactile effect. Use a 90-degree light source to create consistent "plunge" depth for buttons.
- **Software (LCD):** Zero elevation. The screen is a flat, 2D plane. Depth in the UI is represented only through **thick 2px borders** or **solid fills**. There are no ambient shadows or blurs inside the display area.
- **Selection:** Instead of a shadow, a selected state is indicated by a solid rectangular "focus block" that inverts the color of the element it contains.

## Shapes
This design system utilizes a **Sharp (0px)** roundedness philosophy. 

All UI containers, focus states, and buttons must have 90-degree corners. This reinforces the "milled metal" and "pixel-grid" aesthetic. The only exception is the outer casing of the device itself, which may have a slight industrial radius, but all interactive software components must remain strictly rectangular.

## Components

- **Physical Keys:** QWERTY buttons are #1A1A1A with a 1px #333333 top-edge highlight. Characters are etched in #E6B325.
- **D-Pad:** A central circular or square cluster with a raised "Select" center button. Visual depth is achieved through high-contrast beveling.
- **LCD List Items:** Simple horizontal rows separated by a 1px #0F0F0F line. Selection causes the entire row to fill with #0F0F0F and the text to flip to #E6B325.
- **Status Icons:** 16x16 or 12x12 pixel-art style icons. No curves; icons are built on a square grid.
- **Input Fields:** A 1px #0F0F0F outline box. The cursor is a solid blinking #0F0F0F rectangle (the width of one character).
- **Soft-key Labels:** Two labels at the bottom corners of the LCD, mapped to physical buttons immediately below the screen.
- **Modals:** A solid #E6B325 box with a thick 3px #0F0F0F border. Modals should not use overlays or dimming; they simply pop over the existing content.