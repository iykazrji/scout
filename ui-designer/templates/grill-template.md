# UI Designer — Grill Question Template

This template provides the Griller agent with UI-specific question categories for interrogating design requirements. The Griller uses `/grill-me`'s Decision Tree Method with these categories instead of the default technical categories.

## Preamble

Before starting, adapt the question categories to the detected platform:

| Platform | Skip | Add |
|----------|------|-----|
| React Native / Expo | Responsive breakpoints | Gesture navigation, safe areas, platform-specific UI (iOS vs Android) |
| Flutter | Responsive breakpoints (unless targeting web) | Material 3 / Cupertino adaptation, platform channels |
| Web (React/Next.js) | Native gestures | Responsive breakpoints, keyboard navigation, SEO considerations |
| Web (vanilla) | Native gestures | Progressive enhancement, browser compatibility |

**Pacing:** Ask 1-3 focused questions per turn. Use `AskUserQuestion` for structured choices, plain text for open-ended exploration. Track resolved vs open branches.

**Early scope signal:** Once you have answers for categories 1-3 (User Personas, Brand & Tone, Screen Inventory), write a scope file to `/tmp/ui-designer-grill-scope.json` so Reconn can start researching in parallel:

```json
{
  "platform": "<detected>",
  "screens": ["<list of screens>"],
  "userTypes": ["<list of user types>"],
  "tone": "<visual tone keyword>"
}
```

Continue grilling through remaining categories while Reconn works.

---

## Category 1: User Personas

Establish who uses this interface and how.

**Example questions:**
- Who is the primary user of this interface? What's their tech comfort level?
- What devices will they primarily use? (Phone, tablet, desktop, mix?)
- What's the typical usage context? (On-the-go, focused work session, casual browsing?)
- Are there distinct user types with different needs? (Admin vs end-user, free vs paid?)
- What's the user's emotional state when they arrive? (Stressed, excited, bored, goal-oriented?)

**Decision points to resolve:**
- Primary device/viewport
- User sophistication level (affects information density, onboarding)
- Usage context (affects interaction patterns, content priority)

---

## Category 2: Brand & Tone

Establish the visual identity direction.

**Example questions:**
- Are there existing brand guidelines, colors, or fonts that must be used?
- What visual tone fits this product? (Minimal/refined, bold/maximalist, playful/toy-like, corporate/professional, editorial/magazine, brutalist/raw?)
- Can you point to 2-3 existing products or websites whose visual style you admire?
- Should this feel premium/luxury, accessible/friendly, or utilitarian/functional?
- Is there an existing design system or component library to extend?

**Decision points to resolve:**
- Aesthetic direction (critical — informs all downstream design)
- Brand constraints vs creative freedom
- Whether extending existing design system or creating new

---

## Category 3: Screen Inventory

Map out what needs to be designed.

**Example questions:**
- What are the core screens/views that need design? List them all.
- What's the primary user flow? (e.g., Landing → Sign up → Dashboard → Detail)
- What navigation model works best? (Tab bar, sidebar, hamburger, breadcrumbs?)
- Are there any screens that are more critical than others? Which ones need the most design attention?
- Is there a "hero" screen — the one that defines the product's visual identity?

**Decision points to resolve:**
- Complete screen list
- Navigation model
- Priority screens (designed first, set the aesthetic)

---

## Category 4: States Matrix

Ensure every screen's states are considered.

**Example questions:**
- For each screen: what does it look like when there's no data yet? (Empty state)
- How should loading feel? (Skeleton screens, spinners, shimmer, progressive loading?)
- What happens when something goes wrong? (Error states — inline, toast, full-page, retry?)
- Are there edge cases? (Extremely long content, single item, thousands of items, offline?)
- Should skeleton screens match the final layout, or use a generic loading pattern?

**Decision points to resolve:**
- Empty state strategy (illustration + CTA, minimal text, onboarding prompt)
- Loading pattern (skeleton, spinner, progressive)
- Error handling pattern (inline, toast, modal, full-page)
- Edge case handling per screen

---

## Category 5: Interaction Patterns

Define how users interact with the interface.

**Example questions:**
- What gestures are expected? (Swipe to delete, pull to refresh, pinch to zoom, long press?)
- How should screen transitions feel? (Slide, fade, shared element, instant?)
- What micro-interactions would enhance the experience? (Button press feedback, success animations, progress indicators?)
- Are there drag-and-drop interactions, reorderable lists, or other complex touch patterns?
- How should hover states behave? (Web only — subtle highlight, card lift, color shift?)

**Decision points to resolve:**
- Gesture vocabulary
- Transition style and speed
- Micro-interaction priority (which moments get animation investment?)

**Platform notes:**
- Native mobile: focus on gesture and haptic feedback
- Web: focus on hover states, keyboard interactions, scroll behavior

---

## Category 6: Accessibility

Establish accessibility requirements.

**Example questions:**
- What WCAG level are you targeting? (A, AA, AAA?)
- Does this need to work with screen readers? (VoiceOver, TalkBack, NVDA?)
- Are there specific color contrast requirements beyond WCAG minimums?
- Do you need to support reduced motion preferences?
- Are there motor accessibility considerations? (Large touch targets, alternative input methods?)

**Decision points to resolve:**
- WCAG target level
- Screen reader support scope
- Reduced motion strategy
- Minimum touch target sizes

---

## Category 7: Responsive Behavior

*Skip for native mobile apps unless targeting tablets or web.*

**Example questions:**
- What are the key breakpoints? (Mobile-first? Desktop-first? What widths?)
- Should the layout be responsive (same layout adapts) or adaptive (different layouts per breakpoint)?
- How should dense desktop layouts simplify for mobile? (Stack, hide, collapse, tab?)
- Is landscape orientation important? (Tablets, specific use cases?)
- Are there components that should be completely different at mobile vs desktop? (e.g., modal → full-screen sheet)

**Decision points to resolve:**
- Breakpoint strategy
- Responsive vs adaptive approach
- Layout transformation rules per breakpoint

---

## Category 8: Content Density

Determine information density and data display patterns.

**Example questions:**
- Is this data-heavy (dashboards, tables, feeds) or content-light (landing pages, forms)?
- How should lists be displayed? (Cards, rows, grid, compact list?)
- What pagination strategy? (Infinite scroll, load more button, numbered pages?)
- How much information should be visible at once vs hidden behind expand/detail views?
- Are there data visualization needs? (Charts, graphs, maps, timelines?)

**Decision points to resolve:**
- Information density level
- List/grid display format
- Pagination/loading strategy
- Data visualization requirements

---

## Category 9: Existing Design Context

Understand what already exists in the project.

**Example questions:**
- Is there an existing design system, theme, or component library in the codebase?
- Are there specific colors, fonts, or spacing values already in use that should be respected?
- Are there existing screens or components that the new design should feel consistent with?
- Is there a style guide, Figma file, or design documentation to reference?
- Are there third-party UI libraries in use? (Material UI, Tailwind, NativeBase, etc.)

**Decision points to resolve:**
- Whether to extend or create new design system
- Existing constraints to respect
- Third-party library compatibility

---

## Completion

When all relevant categories are resolved, produce a **Design Decision Summary**:

1. **Resolved Decisions** — every decision with its rationale
2. **Platform** — detected platform and implications
3. **Screen List** — all screens to design, in priority order
4. **Aesthetic Direction** — the committed visual tone and differentiation
5. **Design Constraints** — brand, accessibility, existing system requirements
6. **Open Items** — anything that still needs answers or research
7. **Risks** — concerns surfaced during grilling

Save to `/tmp/ui-designer-grill-summary.md`.
