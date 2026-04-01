# Screen Spec Template

Use this template when creating `docs/design-specs/{screen-name}.md` for each screen.

---

```markdown
# {Screen Name}

## Overview

[Brief description of the screen's purpose, where it fits in the user flow, and what the user accomplishes here.]

**Flow position:** [Previous screen] → **{This screen}** → [Next screen]
**Priority:** [Primary / Secondary / Tertiary]

## Layout

[Spatial composition description. How the screen is structured.]

### Structure
- **Header region:** [What's in the top area — nav, title, actions]
- **Main content:** [Primary content area — layout approach (stack, grid, scroll)]
- **Footer / Bottom bar:** [Bottom navigation, actions, or none]

### Grid / Layout System
[Flexbox/Grid structure, column count, gutter sizes, margins. Reference spacing tokens from design system.]

### Visual Hierarchy
[What draws the eye first? Second? How does information flow down the page?]

## Components Used

| Component | Variant | Props/Config | Design System Ref |
|-----------|---------|--------------|-------------------|
| [Name] | [Variant] | [Key props] | components.md#name |

## States

### Empty State
[What the user sees when there's no data yet.]
- **Visual:** [Description — illustration, icon, message]
- **CTA:** [What action the user can take]
- **Mockup:** `screenshots/{screen-name}-empty-mockup.png`

### Loading State
[How loading is communicated.]
- **Pattern:** [Skeleton screen / Spinner / Shimmer / Progressive]
- **Duration handling:** [What happens if loading takes > 3s?]
- **Mockup:** `screenshots/{screen-name}-loading-mockup.png`

### Populated State
[Normal view with data.]
- **Mockup:** `screenshots/{screen-name}-mockup.png`

### Error State
[What happens when something goes wrong.]
- **Type:** [Inline error / Toast / Full-page / Modal]
- **Recovery:** [Retry button / Back navigation / Manual fix]
- **Mockup:** `screenshots/{screen-name}-error-mockup.png`

### Edge Cases
[Unusual but possible states.]
- **Single item:** [How does it look with just one item?]
- **Overflow:** [What happens with extremely long text or many items?]
- **Offline:** [If applicable — cached view, offline indicator]

## Interactions

### Gestures (mobile)
| Gesture | Target | Action |
|---------|--------|--------|
| [Tap] | [Element] | [What happens] |
| [Swipe] | [Element] | [What happens] |
| [Long press] | [Element] | [What happens] |

### Transitions
| Trigger | Animation | Duration | Easing |
|---------|-----------|----------|--------|
| [Enter screen] | [Slide/Fade/etc] | [ms] | [easing token] |
| [Exit screen] | [Slide/Fade/etc] | [ms] | [easing token] |

### Micro-interactions
[Button press feedback, success animations, progress indicators, hover states (web)]

## Responsive Behavior

*Skip this section for native mobile apps.*

| Breakpoint | Layout Change |
|------------|---------------|
| Desktop (>1024px) | [Description] |
| Tablet (768-1024px) | [Description] |
| Mobile (<768px) | [Description] |

## Accessibility

- **Focus order:** [Tab order through interactive elements]
- **Screen reader labels:** [Key aria-labels or accessibilityLabels]
- **Contrast:** [Any specific contrast considerations beyond global rules]
- **Keyboard navigation:** [Web — key bindings, focus traps for modals]
- **Reduced motion:** [Alternative for users with motion sensitivity]

## Screenshots

- **Mockup:** `screenshots/{screen-name}-mockup.png`
- **Build:** `screenshots/{screen-name}-build.png` *(added post-implementation by Inspector)*
```
