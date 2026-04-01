# Minimize Conditional Logic in Worklets

**Impact:** HIGH

## Rule

Avoid `if/else` branching in worklets. Use `interpolate`, `useDerivedValue`, or mathematical expressions instead.

## Why

Conditional logic in worklets (especially inside `useAnimatedStyle`) adds branching overhead that runs every frame. Mathematical approaches are more predictable and often result in smoother animations since they produce continuous values.

## Bad

```tsx
// ❌ Branching logic in animated style
const animatedStyle = useAnimatedStyle(() => {
  let backgroundColor;
  let scale;
  let opacity;

  if (progress.value < 0.3) {
    backgroundColor = 'red';
    scale = 1;
    opacity = 1;
  } else if (progress.value < 0.7) {
    backgroundColor = 'yellow';
    scale = 1.2;
    opacity = 0.8;
  } else {
    backgroundColor = 'green';
    scale = 1;
    opacity = 0.6;
  }

  return { backgroundColor, transform: [{ scale }], opacity };
});
```

## Good

```tsx
// ✅ Use interpolate for continuous values
const animatedStyle = useAnimatedStyle(() => ({
  transform: [
    {
      scale: interpolate(
        progress.value,
        [0, 0.3, 0.7, 1],
        [1, 1, 1.2, 1]
      ),
    },
  ],
  opacity: interpolate(
    progress.value,
    [0, 0.3, 0.7, 1],
    [1, 1, 0.8, 0.6]
  ),
}));

// ✅ Use interpolateColor for color transitions
const backgroundColor = useDerivedValue(() =>
  interpolateColor(
    progress.value,
    [0, 0.3, 0.7, 1],
    ['red', 'red', 'yellow', 'green']
  )
);
```

## When Conditionals Are OK

- Discrete state changes (not continuous animations)
- Guard clauses at the top of a worklet
- Simple boolean checks that don't change every frame
