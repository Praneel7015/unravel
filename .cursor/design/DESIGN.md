---

name: Unravel Botanical & Circadian Field Journal

colors:

  # Primary Default Canvas: Dusk Pine (Evening Nature Dark)

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

  # Circadian Theme 1: Morning Mist (Warm Birch Paper Light)

  surface-morning-canvas: '#F6F5F0'

  surface-morning-card: '#EFECE6'

  border-morning: '#DCD8CE'

  text-morning-primary: '#1C1E1B'

  text-morning-muted: '#60645D'

  accent-morning-moss: '#4A6B53'

  accent-morning-clay: '#C87D55'

  # Circadian Theme 2: High Sun (Raw Limestone Neutral Grey)

  surface-sun-canvas: '#EAE8E1'

  surface-sun-card: '#E0DDD5'

  border-sun: '#CCC8BE'

  text-sun-primary: '#181A18'

  accent-sun-sage: '#3B5944'

  # Circadian Theme 4: Midnight Starlight (True Pitch Black OLED)

  surface-oled-canvas: '#000000'

  surface-oled-card: '#0B0C0B'

  border-oled: '#222623'

  text-oled-primary: '#F2F0E8'

  accent-oled-fern: '#749C82'

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

rounded:

  sm: 6px

  DEFAULT: 12px

  md: 16px

  lg: 20px

  full: 9999px

spacing:

  gutter: 16px

  margin: 20px

  section-gap: 28px

  card-padding: 20px

---

## Brand & Aesthetic Direction

**Unravel** is a warm, tactile, nature-derived companion for untangling pre-event anxiety (like job interviews or difficult conversations) and building real-world confidence.

Visual reference: Readwise Reader meets Things 3 and a physical botanical field journal.

## Explicit Do's and Don'ts (CRITICAL CONSTRAINTS)

- **DO NOT** use neon/cyberpunk colors `#10B981`, `#4EDEA3`, or electric indigo). Use only muted earth pigments: Lichen Green `#84A98C`), Warm Amber Resin `#D49A59`), Terracotta `#C97054`), and Warm Parchment `#E8E6DF`).

- **DO NOT** use cold technical/military/server jargon. Never write words like "Telemetry," "Fatalities," "Hex 0x00," "Neural Dump," "Artifacts Decrypted," or "System Config."

- **DO NOT** include "Day Streak" counters or gamified flame icons.

- **DO** use `Newsreader` (serif) for screen titles, active life event headings, and the Daily Philosophical Quote banner.

- **DO** use `1px solid` borders `#2A332D` in Dusk Pine, `#DCD8CE` in Morning Mist) with zero blurry neon drop-shadows.

## Component Specifications

- **Quote Banner Card:** Borderless or subtle top/bottom `1px solid #2A332D` divider, displaying an italic `Newsreader` 19px quote from Stoic or nature philosophy (e.g., Seneca, Marcus Aurelius, Rilke) with a small botanical leaf icon.

- **Open Thread Card (Event Anchor):** Background `#1C221E`, border `1px solid #2A332D`, radius `16px`, padding `20px`. Features an upcoming real-life event title in `Newsreader` serif, 2 bulleted "Unraveled Worries," 1 warm highlighted "Grounding Anchor" box `background: #242B26`), and a primary pill button `background: #84A98C`, `color: #111C15`, `border-radius: 9999px`).

- **Perspective Curve Card:** Dual smooth spline chart comparing "What My Fear Predicted" `#C97054` muted terracotta dashed line) vs "How Life Actually Unfolded" `#84A98C` solid sage curve).

## Agent Prompt Guide

- **Primary Button Recipe:** `background: #84A98C`, `color: #111C15`, `font-family: Plus Jakarta Sans`, `font-weight: 600`, `padding: 14px 24px`, `border-radius: 9999px`, no glow shadow.

- **Card Container Recipe:** `background: #1C221E`, `border: 1px solid #2A332D`, `border-radius: 16px`, `padding: 20px`.