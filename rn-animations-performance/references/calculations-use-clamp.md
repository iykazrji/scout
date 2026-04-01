# Use clamp Instead of Manual Math.min/max

**Impact:** HIGH

## Rule

Use Reanimated's `clamp` utility instead of nesting `Math.min(Math.max(...))` in worklets.

## Why

`clamp` from `react-native-reanimated` is optimized for the worklet runtime. It's more readable, less error-prone (no min/max order confusion), and avoids the overhead of two separate Math calls per frame.

## Bad

```tsx
// ❌ Manual clamping - verbose and error-prone
const animatedStyle = useAnimatedStyle(() => {
  const boundedX = Math.min(Math.max(translateX.value, -200), 200);
  const boundedScale = Math.min(Math.max(scale.value, 0.5), 2);

  return {
    transform: [
      { translateX: boundedX },
      { scale: boundedScale },
    ],
  };
});
```

## Good

```tsx
import { clamp } from 'react-native-reanimated';

// ✅ Clean and optimized
const animatedStyle = useAnimatedStyle(() => ({
  transform: [
    { translateX: clamp(translateX.value, -200, 200) },
    { scale: clamp(scale.value, 0.5, 2) },
  ],
}));
```

## Also Useful in Derived Values

```tsx
const boundedProgress = useDerivedValue(() => {
  return clamp(rawProgress.value, 0, 1);
});
```
