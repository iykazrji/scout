# Component Library Template

Use this template for each component entry in `docs/design-system/components.md`.

---

```markdown
## {Component Name}

### Description

[What this component does and when to use it. One clear sentence.]

**Category:** [Actions / Forms / Containers / Navigation / Feedback / Data Display / Layout]

### API

| Prop/Param | Type | Default | Required | Description |
|------------|------|---------|----------|-------------|
| [name] | [type] | [default] | [yes/no] | [what it does] |

### Variants

| Variant | When to Use | Visual Description |
|---------|-------------|-------------------|
| [Primary] | [Main CTAs, prominent actions] | [Filled, brand color, bold] |
| [Secondary] | [Supporting actions] | [Outlined, subtle] |
| [Ghost] | [Tertiary actions, in-context] | [Text only, no background] |

### Sizes (if applicable)

| Size | Height | Font Size | Padding | When to Use |
|------|--------|-----------|---------|-------------|
| sm | [px] | [px] | [px] | [Compact contexts, inline] |
| md | [px] | [px] | [px] | [Default] |
| lg | [px] | [px] | [px] | [Primary CTAs, touch targets] |

### States

| State | Visual Change | Trigger |
|-------|--------------|---------|
| Default | [Description] | — |
| Hover | [Description] | Mouse over (web) |
| Pressed | [Description] | Touch/click active |
| Focused | [Description] | Keyboard focus |
| Disabled | [Description] | disabled prop |
| Loading | [Description] | loading prop |

### Usage Examples

**Web (React / Next.js):**
```jsx
<Button variant="primary" size="md" onClick={handleClick}>
  Save Changes
</Button>
```

**React Native / Expo:**
```tsx
<Button variant="primary" size="md" onPress={handlePress}>
  Save Changes
</Button>
```

**Flutter:**
```dart
AppButton(
  variant: ButtonVariant.primary,
  size: ButtonSize.md,
  onPressed: handlePress,
  child: Text('Save Changes'),
)
```

### Composition

[How this component combines with others.]
- **With [Component]:** [Pattern description]
- **Inside [Component]:** [Pattern description]
- **Contains [Component]:** [Pattern description]

### Platform Notes

| Platform | Consideration |
|----------|--------------|
| Web | [Keyboard accessibility, hover states, focus ring] |
| iOS | [Touch target 44pt min, haptic feedback, SF Symbols] |
| Android | [Touch target 48dp min, ripple effect, Material icons] |
| Flutter | [Widget tree, theme integration, platform-adaptive] |

### Design Tokens Used

| Token | Value | Usage |
|-------|-------|-------|
| [color.primary.500] | [#...] | [Background fill] |
| [radius.md] | [8px] | [Border radius] |
| [spacing.4] | [16px] | [Internal padding] |
```
