# Design System Base Template

This template defines the structure for project-level design system artifacts. The Stylist agent uses this to generate `docs/design-system/` for a project.

**Important:** Before generating, check if `docs/design-system/` already exists. If it does, read and extend rather than overwrite.

---

## Artifact 1: tokens.json

Machine-readable design tokens. Format adapts to platform.

### Structure

```json
{
  "colors": {
    "primary": {
      "50": "#...", "100": "#...", "200": "#...", "300": "#...",
      "400": "#...", "500": "#...", "600": "#...", "700": "#...",
      "800": "#...", "900": "#...", "950": "#..."
    },
    "secondary": { "...same scale..." },
    "accent": { "...same scale..." },
    "neutral": { "...same scale..." },
    "semantic": {
      "success": { "light": "#...", "default": "#...", "dark": "#..." },
      "warning": { "light": "#...", "default": "#...", "dark": "#..." },
      "error": { "light": "#...", "default": "#...", "dark": "#..." },
      "info": { "light": "#...", "default": "#...", "dark": "#..." }
    },
    "background": { "primary": "#...", "secondary": "#...", "tertiary": "#..." },
    "text": { "primary": "#...", "secondary": "#...", "tertiary": "#...", "inverse": "#..." },
    "border": { "default": "#...", "strong": "#...", "subtle": "#..." }
  },
  "typography": {
    "fontFamilies": {
      "display": "Font Name",
      "body": "Font Name",
      "mono": "Font Name"
    },
    "fontSizes": {
      "xs": 12, "sm": 14, "base": 16, "lg": 18,
      "xl": 20, "2xl": 24, "3xl": 30, "4xl": 36,
      "5xl": 48, "6xl": 60
    },
    "fontWeights": {
      "light": 300, "regular": 400, "medium": 500,
      "semibold": 600, "bold": 700
    },
    "lineHeights": {
      "tight": 1.2, "normal": 1.5, "relaxed": 1.75
    }
  },
  "spacing": {
    "scale": [0, 2, 4, 8, 12, 16, 20, 24, 32, 40, 48, 64, 80, 96, 128]
  },
  "radii": {
    "none": 0, "sm": 4, "md": 8, "lg": 12, "xl": 16, "2xl": 24, "full": 9999
  },
  "shadows": {
    "sm": "...", "md": "...", "lg": "...", "xl": "..."
  },
  "motion": {
    "durations": {
      "instant": 100, "fast": 200, "normal": 300, "slow": 500, "glacial": 1000
    },
    "easings": {
      "default": "cubic-bezier(0.4, 0, 0.2, 1)",
      "in": "cubic-bezier(0.4, 0, 1, 1)",
      "out": "cubic-bezier(0, 0, 0.2, 1)",
      "bounce": "cubic-bezier(0.34, 1.56, 0.64, 1)"
    }
  }
}
```

### Platform Adaptation

**Web (CSS custom properties):**
```css
:root {
  --color-primary-500: #...;
  --font-family-display: 'Font Name', serif;
  --spacing-4: 16px;
  --radius-md: 8px;
  --shadow-md: 0 4px 6px -1px rgb(0 0 0 / 0.1);
  --duration-normal: 300ms;
  --easing-default: cubic-bezier(0.4, 0, 0.2, 1);
}
```

**React Native / Expo (JS/TS theme object):**
```typescript
export const theme = {
  colors: {
    primary: { 500: '#...' },
    // ...
  },
  typography: {
    fontFamilies: { display: 'FontName-Bold', body: 'FontName-Regular' },
    fontSizes: { base: 16 },
  },
  spacing: (n: number) => n * 4,
  radii: { md: 8 },
} as const;
```

**Flutter (Dart ThemeData):**
```dart
final appTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Color(0xFF...),
    primary: Color(0xFF...),
    secondary: Color(0xFF...),
  ),
  textTheme: TextTheme(
    displayLarge: TextStyle(fontFamily: 'FontName', fontSize: 60),
    bodyLarge: TextStyle(fontFamily: 'FontName', fontSize: 16),
  ),
);
```

---

## Artifact 2: color-palette.md

Human-readable color documentation with rationale.

### Structure

```markdown
# Color Palette

## Overview
[1-2 sentences about the palette's personality and how it supports the brand/product]

## Primary Palette
| Role | Swatch | Hex | Usage |
|------|--------|-----|-------|
| Primary | [visual] | #... | CTAs, active states, brand moments |
| Secondary | [visual] | #... | Supporting elements, secondary actions |
| Accent | [visual] | #... | Highlights, badges, attention-grabbing |
| Neutral | [visual] | #... | Backgrounds, borders, disabled states |

## Rationale
[Why these specific colors? What emotion/association? How do they differentiate?]

## Contrast Ratios
| Combination | Ratio | WCAG AA | WCAG AAA |
|-------------|-------|---------|----------|
| Primary on White | X:1 | Pass/Fail | Pass/Fail |
| Text on Background | X:1 | Pass/Fail | Pass/Fail |
| ... | ... | ... | ... |

## Semantic Colors
| Meaning | Color | Hex | Usage |
|---------|-------|-----|-------|
| Success | [visual] | #... | Confirmations, completed states |
| Warning | [visual] | #... | Caution states, pending actions |
| Error | [visual] | #... | Errors, destructive actions |
| Info | [visual] | #... | Informational messages, tips |

## Dark Mode (if applicable)
[How the palette adapts for dark mode — not just inverted, but re-balanced for dark backgrounds]
```

---

## Artifact 3: typography.md

Font choices, type scale, and loading strategy.

### Structure

```markdown
# Typography

## Font Choices

### Display Font: [Font Name]
[Why this font? What character does it bring? Where is it used?]

### Body Font: [Font Name]
[Why this font? How does it pair with the display font? Readability considerations.]

### Monospace Font: [Font Name] (if applicable)
[For code, data, tabular content.]

## Pairing Rationale
[Why these fonts work together — contrast, shared characteristics, visual harmony]

## Type Scale
| Level | Size | Weight | Line Height | Usage |
|-------|------|--------|-------------|-------|
| Display | 60px | Bold | 1.1 | Hero headings, splash |
| H1 | 48px | Bold | 1.2 | Page titles |
| H2 | 36px | Semibold | 1.2 | Section headings |
| H3 | 30px | Semibold | 1.3 | Subsection headings |
| H4 | 24px | Medium | 1.3 | Card titles |
| H5 | 20px | Medium | 1.4 | List group titles |
| H6 | 18px | Medium | 1.4 | Minor headings |
| Body Large | 18px | Regular | 1.6 | Primary content |
| Body | 16px | Regular | 1.5 | Default text |
| Body Small | 14px | Regular | 1.5 | Secondary text |
| Caption | 12px | Regular | 1.4 | Labels, timestamps |
| Overline | 12px | Semibold | 1.2 | Category labels (uppercase) |

## Font Loading Strategy

### Web
[Google Fonts CDN / self-hosted / font-display strategy / fallback chain]

### React Native / Expo
[Bundled fonts via expo-font / asset linking / platform-specific font names]

### Flutter
[pubspec.yaml font declaration / Google Fonts package / asset bundling]
```

---

## Artifact 4: components.md

Component library documentation. Use the component-library-template.md for each component entry.

### Structure

```markdown
# Component Library

## Overview
[Brief description of the component library's scope and design philosophy]

## Component Index
| Component | Category | Variants |
|-----------|----------|----------|
| Button | Actions | Primary, Secondary, Ghost, Destructive |
| Input | Forms | Text, Password, Search, Textarea |
| Card | Containers | Default, Elevated, Outlined |
| ... | ... | ... |

## Components
[One section per component following component-library-template.md]

## Composition Patterns
[How components combine — form layouts, card grids, navigation + content, etc.]

## Platform Notes
[Global platform-specific considerations that apply across components]
```

---

## Anti-Slop Checklist

Before finalizing any design system artifact, verify:

- [ ] Fonts are distinctive and characterful (NOT Inter, Roboto, Arial, system defaults)
- [ ] Color palette has a strong point of view (NOT generic purple-on-white)
- [ ] Spacing scale creates intentional rhythm (NOT default Tailwind/Material)
- [ ] Component designs reflect the aesthetic direction (NOT cookie-cutter)
- [ ] The overall system feels cohesive and memorable
- [ ] This design system could NOT be confused with any other project's
