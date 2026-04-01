# Use useDerivedValue for Expensive Calculations

**Impact:** HIGH

## Rule

Extract expensive calculations from `useAnimatedStyle` into `useDerivedValue`. Keep `useAnimatedStyle` as a simple property mapper.

## Why

`useAnimatedStyle` runs every frame during animation. Complex calculations inside it waste UI thread time. `useDerivedValue` caches the result and only recalculates when dependencies change, reducing per-frame work.

## Bad

```tsx
// ❌ Expensive calculation inside useAnimatedStyle
const animatedStyle = useAnimatedStyle(() => {
  // All this runs every frame
  const progress = scrollOffset.value / totalHeight;
  const clamped = Math.max(0, Math.min(1, progress));
  const headerHeight = interpolate(clamped, [0, 1], [200, 60]);
  const opacity = interpolate(clamped, [0, 0.5, 1], [1, 0.8, 0]);
  const scale = interpolate(clamped, [0, 1], [1, 0.8]);
  const borderRadius = interpolate(clamped, [0, 1], [0, 20]);

  return {
    height: headerHeight,
    opacity,
    transform: [{ scale }],
    borderRadius,
  };
});
```

## Good

```tsx
// ✅ Calculations in useDerivedValue, style just maps
const progress = useDerivedValue(() => {
  return clamp(scrollOffset.value / totalHeight, 0, 1);
});

const headerHeight = useDerivedValue(() => {
  return interpolate(progress.value, [0, 1], [200, 60]);
});

const headerOpacity = useDerivedValue(() => {
  return interpolate(progress.value, [0, 0.5, 1], [1, 0.8, 0]);
});

const animatedStyle = useAnimatedStyle(() => ({
  height: headerHeight.value,
  opacity: headerOpacity.value,
  transform: [{ scale: interpolate(progress.value, [0, 1], [1, 0.8]) }],
  borderRadius: interpolate(progress.value, [0, 1], [0, 20]),
}));
```

## When to Extract

- More than 2-3 lines of calculation before the return
- Same calculation used in multiple `useAnimatedStyle` hooks
- Interpolations that can be cached
