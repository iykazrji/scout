# Track Animation State with useRef

**Impact:** HIGH

## Rule

When you need to know whether an animation is "open" or "closed" (toggle state), track it with `useRef` instead of reading the shared value.

## Why

Reading a shared value to determine state (e.g., `if (offset.value === 0)`) requires a synchronous bridge call to the UI thread. Using `useRef` keeps the state on the JS thread where it's needed, avoiding the bridge overhead.

## Bad

```tsx
// ❌ Reading shared value to determine toggle state
function Drawer() {
  const translateX = useSharedValue(0);

  const toggleDrawer = () => {
    // Synchronous bridge call to read current value
    if (translateX.value === 0) {
      translateX.value = withSpring(-250);
    } else {
      translateX.value = withSpring(0);
    }
  };

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: translateX.value }],
  }));

  return (
    <>
      <Button onPress={toggleDrawer} title="Toggle" />
      <Animated.View style={animatedStyle} />
    </>
  );
}
```

## Good

```tsx
// ✅ Track state with useRef, no bridge call needed
function Drawer() {
  const translateX = useSharedValue(0);
  const isOpen = useRef(false);

  const toggleDrawer = () => {
    // No bridge call - reads local JS ref
    if (isOpen.current) {
      translateX.value = withSpring(0);
      isOpen.current = false;
    } else {
      translateX.value = withSpring(-250);
      isOpen.current = true;
    }
  };

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: translateX.value }],
  }));

  return (
    <>
      <Button onPress={toggleDrawer} title="Toggle" />
      <Animated.View style={animatedStyle} />
    </>
  );
}
```

## When This Applies

- Toggle animations (open/close, show/hide)
- Sequential animations (tracking which step you're on)
- Any time you need discrete state derived from animation progress
