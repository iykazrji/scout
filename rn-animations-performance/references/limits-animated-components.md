# Limit Simultaneously Animated Components

**Impact:** MEDIUM

## Rule

Keep the number of simultaneously animating components under control. Batch animations or stagger them when animating many items.

## Why

Each `Animated.View` with an active `useAnimatedStyle` runs its worklet every frame. 50+ simultaneously animating components can overwhelm the UI thread, especially on lower-end devices.

## Bad

```tsx
// ❌ All 100 items animate simultaneously
function AnimatedList({ items }) {
  return items.map((item, index) => (
    <AnimatedListItem key={item.id} item={item} />
  ));
}

function AnimatedListItem({ item }) {
  const opacity = useSharedValue(0);

  useEffect(() => {
    // All 100 items spring in at once
    opacity.value = withSpring(1);
  }, []);

  const style = useAnimatedStyle(() => ({
    opacity: opacity.value,
  }));

  return <Animated.View style={style}>...</Animated.View>;
}
```

## Good

```tsx
// ✅ Stagger animations
function AnimatedListItem({ item, index }) {
  const opacity = useSharedValue(0);

  useEffect(() => {
    // Stagger by 50ms per item, max 10 animating at once
    const delay = Math.min(index, 10) * 50;
    opacity.value = withDelay(delay, withTiming(1, { duration: 300 }));
  }, []);

  const style = useAnimatedStyle(() => ({
    opacity: opacity.value,
  }));

  return <Animated.View style={style}>...</Animated.View>;
}
```

## Guidelines

| Device Tier | Max Simultaneous Animations |
|-------------|----------------------------|
| High-end | 30-50 |
| Mid-range | 15-25 |
| Low-end | 5-10 |

## Strategies

- **Stagger**: Delay each item's start time
- **Viewport only**: Only animate items visible on screen
- **Batch**: Animate groups together (fade in 5 at a time)
- **Simplify offscreen**: Use opacity-only for items far from viewport
