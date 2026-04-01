# Choose useAnimatedProps vs useAnimatedStyle

**Impact:** HIGH

## Rule

Use `useAnimatedStyle` for style properties (transforms, opacity, colors). Use `useAnimatedProps` for non-style props (SVG attributes, text content, component-specific props).

## Why

Using the wrong hook causes silent failures or unnecessary overhead. `useAnimatedStyle` only applies to the `style` prop. Non-style animated properties require `useAnimatedProps`.

## useAnimatedStyle

For anything in the `style` prop:

```tsx
// ✅ Style properties
const animatedStyle = useAnimatedStyle(() => ({
  opacity: opacity.value,
  transform: [{ translateX: offset.value }],
  backgroundColor: color.value,
}));

<Animated.View style={animatedStyle} />
```

## useAnimatedProps

For non-style props:

```tsx
// ✅ SVG attributes
const animatedProps = useAnimatedProps(() => ({
  cx: position.value.x,
  cy: position.value.y,
  r: radius.value,
  fill: color.value,
}));

<AnimatedCircle animatedProps={animatedProps} />
```

```tsx
// ✅ Text content
const AnimatedTextInput = Animated.createAnimatedComponent(TextInput);

const animatedProps = useAnimatedProps(() => ({
  text: `${Math.round(progress.value * 100)}%`,
  defaultValue: '', // required for Android
}));

<AnimatedTextInput animatedProps={animatedProps} editable={false} />
```

## Common Prop Types

| Property | Hook |
|----------|------|
| `transform`, `opacity`, `backgroundColor` | `useAnimatedStyle` |
| SVG `cx`, `cy`, `r`, `d`, `fill`, `stroke` | `useAnimatedProps` |
| `text`, `value` (TextInput) | `useAnimatedProps` |
| `contentOffset` (ScrollView) | `useAnimatedProps` |
| Custom native component props | `useAnimatedProps` |
