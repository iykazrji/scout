# Optimize useAnimatedReaction Dependencies

**Impact:** HIGH

## Rule

Keep `useAnimatedReaction` dependency functions lightweight. Return only the specific values you need, not entire objects. Avoid unnecessary reactions.

## Why

The first argument (dependency function) runs every frame to check for changes. If it returns a new object reference each time, the reaction fires every frame regardless of whether values actually changed.

## Bad

```tsx
// ❌ Returns new object every frame - reaction fires constantly
useAnimatedReaction(
  () => ({
    x: translateX.value,
    y: translateY.value,
    scale: scale.value,
  }),
  (current, previous) => {
    // Fires every frame because object reference changes
    if (current.x !== previous?.x) {
      // handle x change
    }
  }
);
```

## Good

```tsx
// ✅ Return only the value you care about
useAnimatedReaction(
  () => translateX.value,
  (currentX, previousX) => {
    if (currentX !== previousX) {
      // handle x change
    }
  }
);
```

## Multiple Dependencies

```tsx
// ✅ Use separate reactions for independent concerns
useAnimatedReaction(
  () => translateX.value,
  (current) => {
    // React to X changes
  }
);

useAnimatedReaction(
  () => scale.value,
  (current) => {
    // React to scale changes
  }
);
```

## Consider Alternatives

Before using `useAnimatedReaction`, check if `useDerivedValue` can solve the problem:

```tsx
// ✅ Often better than useAnimatedReaction
const clampedX = useDerivedValue(() => {
  return clamp(translateX.value, 0, maxWidth);
});
```

Use `useAnimatedReaction` only when you need side effects (calling `runOnJS`, updating shared values conditionally).
