# Optimize Scroll Handlers

**Impact:** MEDIUM

## Rule

Keep scroll handler worklets lightweight. Avoid creating objects or doing complex calculations inside `useAnimatedScrollHandler`.

## Why

Scroll handlers fire on every frame during scrolling (up to 120fps on ProMotion displays). Heavy worklets in scroll handlers directly cause scroll jank.

## Bad

```tsx
// ❌ Heavy computation in scroll handler
const scrollHandler = useAnimatedScrollHandler({
  onScroll: (event) => {
    const offset = event.contentOffset.y;

    // Expensive: multiple interpolations per frame
    headerHeight.value = interpolate(offset, [0, 200], [300, 60], Extrapolation.CLAMP);
    headerOpacity.value = interpolate(offset, [0, 100, 200], [1, 0.5, 0], Extrapolation.CLAMP);
    titleScale.value = interpolate(offset, [0, 200], [1, 0.7], Extrapolation.CLAMP);
    backgroundBlur.value = interpolate(offset, [0, 200], [0, 20], Extrapolation.CLAMP);
    shadowOpacity.value = interpolate(offset, [0, 50], [0, 0.3], Extrapolation.CLAMP);
    tabBarTranslate.value = interpolate(offset, [0, 100], [0, -50], Extrapolation.CLAMP);
  },
});
```

## Good

```tsx
// ✅ Store scroll offset, derive everything else
const scrollY = useSharedValue(0);

const scrollHandler = useAnimatedScrollHandler({
  onScroll: (event) => {
    // Minimal work: just store the value
    scrollY.value = event.contentOffset.y;
  },
});

// Derive animated values separately
const headerHeight = useDerivedValue(() =>
  interpolate(scrollY.value, [0, 200], [300, 60], Extrapolation.CLAMP)
);

const headerOpacity = useDerivedValue(() =>
  interpolate(scrollY.value, [0, 100, 200], [1, 0.5, 0], Extrapolation.CLAMP)
);

// useAnimatedStyle reads derived values
const headerStyle = useAnimatedStyle(() => ({
  height: headerHeight.value,
  opacity: headerOpacity.value,
}));
```

## Key Principle

The scroll handler should do ONE thing: store the scroll offset. All derived calculations should happen in `useDerivedValue` hooks, which cache their results and only recalculate when the dependency changes.
