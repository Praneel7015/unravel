---
name: Unravel Botanical & Circadian Field Journal
colors:
  background: '#141815'
  surface: '#141815'
  surface-container-low: '#181D19'
  surface-container: '#1C221E'
  surface-container-high: '#242B26'
  on-surface: '#E8E6DF'
  on-surface-variant: '#959E97'
  outline: '#2A332D'
  outline-variant: '#1F2621'
  primary: '#84A98C'
  on-primary: '#111C15'
  primary-container: '#2D4233'
  on-primary-container: '#D8E8DC'
  secondary: '#D49A59'
  on-secondary: '#2B1B06'
  tertiary: '#C97054'
  surface-morning-canvas: '#F6F5F0'
  surface-morning-card: '#EFECE6'
  border-morning: '#DCD8CE'
  text-morning-primary: '#1C1E1B'
  text-morning-muted: '#60645D'
  accent-morning-moss: '#4A6B53'
  accent-morning-clay: '#C87D55'
  surface-sun-canvas: '#EAE8E1'
  surface-sun-card: '#E0DDD5'
  border-sun: '#CCC8BE'
  text-sun-primary: '#181A18'
  accent-sun-sage: '#3B5944'
  surface-oled-canvas: '#000000'
  surface-oled-card: '#0B0C0B'
  border-oled: '#222623'
  text-oled-primary: '#F2F0E8'
  accent-oled-fern: '#749C82'
  surface-dim: '#101411'
  surface-bright: '#363a37'
  surface-container-lowest: '#0b0f0c'
  surface-container-highest: '#323632'
  inverse-surface: '#e0e3de'
  inverse-on-surface: '#2d312e'
  surface-tint: '#aad0b1'
  inverse-primary: '#43664d'
  secondary-container: '#673d01'
  on-secondary-container: '#e5a967'
  on-tertiary: '#5a1b06'
  tertiary-container: '#e6876a'
  on-tertiary-container: '#63220c'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#c5eccc'
  primary-fixed-dim: '#aad0b1'
  on-primary-fixed: '#00210e'
  on-primary-fixed-variant: '#2c4e36'
  secondary-fixed: '#ffdcbb'
  secondary-fixed-dim: '#f9ba76'
  on-secondary-fixed: '#2b1700'
  on-secondary-fixed-variant: '#673d01'
  tertiary-fixed: '#ffdbd0'
  tertiary-fixed-dim: '#ffb59e'
  on-tertiary-fixed: '#3a0b00'
  on-tertiary-fixed-variant: '#78311a'
  on-background: '#e0e3de'
  surface-variant: '#323632'
typography:
  display-serif:
    fontFamily: Newsreader
    fontSize: 34px
    fontWeight: '400'
    lineHeight: 40px
    letterSpacing: -0.02em
  quote-serif-italic:
    fontFamily: Newsreader
    fontSize: 19px
    fontWeight: '400'
    fontStyle: italic
    lineHeight: 28px
  headline-sans:
    fontFamily: Plus Jakarta Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 26px
    letterSpacing: -0.015em
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  meta-mono:
    fontFamily: JetBrains Mono
    fontSize: 11px
    fontWeight: '400'
    lineHeight: 16px
    letterSpacing: 0.04em
  display-serif-mobile:
    fontFamily: Newsreader
    fontSize: 28px
    fontWeight: '400'
    lineHeight: 34px
    letterSpacing: -0.015em
  title-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 13px
    fontWeight: '500'
    lineHeight: 18px
rounded:
  sm: 6px
  DEFAULT: 12px
  md: 16px
  lg: 20px
  full: 9999px
  xl: 1.5rem
spacing:
  gutter: 16px
  margin: 20px
  section-gap: 28px
  card-padding: 20px
  space-xs: 4px
  space-sm: 8px
  space-md: 16px
  space-lg: 20px
  space-xl: 28px
---

## Brand & Aesthetic Direction
**Unravel** is a warm, tactile, nature-derived companion for untangling pre-event anxiety (like job interviews or difficult conversations) and building real-world confidence.
Visual reference: Readwise Reader meets Things 3 and a physical botanical field journal.
## Explicit Do's and Don'ts (CRITICAL CONSTRAINTS)
- **DO NOT** use neon/cyberpunk colors (`#10B981`, `#4EDEA3`, or electric indigo). Use only muted earth pigments: Lichen Green (`#84A98C`), Warm Amber Resin (`#D49A59`), Terracotta (`#C97054`), and Warm Parchment (`#E8E6DF`).
- **DO NOT** use cold technical/military/server jargon. Never write words like "Telemetry," "Fatalities," "Hex 0x00," "Neural Dump," "Artifacts Decrypted," or "System Config."
- **DO NOT** include "Day Streak" counters or gamified flame icons.
- **DO** use `Newsreader` (serif) for screen titles, active life event headings, and the Daily Philosophical Quote banner.
- **DO** use `1px solid` borders (`#2A332D` in Dusk Pine, `#DCD8CE` in Morning Mist) with zero blurry neon drop-shadows.
## Component Specifications
- **Quote Banner Card:** Borderless or subtle top/bottom `1px solid #2A332D` divider, displaying an italic `Newsreader` 19px quote from Stoic or nature philosophy (e.g., Seneca, Marcus Aurelius, Rilke) with a small botanical leaf icon.
- **Open Thread Card (Event Anchor):** Background `#1C221E`, border `1px solid #2A332D`, radius `16px`, padding `20px`. Features an upcoming real-life event title in `Newsreader` serif, 2 bulleted "Unraveled Worries," 1 warm highlighted "Grounding Anchor" box (`background: #242B26`), and a primary pill button (`background: #84A98C`, `color: #111C15`, `border-radius: 9999px`).
- **Perspective Curve Card:** Dual smooth spline chart comparing "What My Fear Predicted" (`#C97054` muted terracotta dashed line) vs "How Life Actually Unfolded" (`#84A98C` solid sage curve).
## Agent Prompt Guide
- **Primary Button Recipe:** `background: #84A98C`, `color: #111C15`, `font-family: Plus Jakarta Sans`, `font-weight: 600`, `padding: 14px 24px`, `border-radius: 9999px`, no glow shadow.
- **Card Container Recipe:** `background: #1C221E`, `border: 1px solid #2A332D`, `border-radius: 16px`, `padding: 20px`.