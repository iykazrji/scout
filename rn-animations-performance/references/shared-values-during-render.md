# Don't Read/Modify Shared Values During Render

**Impact:** CRITICAL

## Rule

Never read or write `.value` in the component render body. This violates the Rules of React (render must be pure) and causes unpredictable behavior.

## Why

React may call render functions multiple times, in any order, and may discard results. Reading/writing shared values during render creates side effects that break React's concurrent features and cause bugs.

## Bad

```tsx
// ❌ Reading shared value during render
function MyComponent({ isVisible }) {
  const opacity = useSharedValue(1);

  // This runs during render - violates Rules of React
  if (isVisible) {
    opacity.value = 1;
  } else {
    opacity.value = 0;
  }

  // Also bad: reading during render
  const currentOpacity = opacity.value;

  return <Animated.View style={{ opacity: currentOpacity }} />;
}
```

## Good

```tsx
// ✅ Modify shared values in useEffect
function MyComponent({ isVisible }) {
  const opacity = useSharedValue(1);

  useEffect(() => {
    opacity.value = withTiming(isVisible ? 1 : 0);
  }, [isVisible]);

  const animatedStyle = useAnimatedStyle(() => ({
    opacity: opacity.value,
  }));

  return <Animated.View style={animatedStyle} />;
}
```

## Also Good

```tsx
// ✅ Modify in event callbacks
const handleToggle = () => {
  opacity.value = withTiming(opacity.value === 1 ? 0 : 1);
};

// ✅ Modify in gesture handlers (worklet context)
const gesture = Gesture.Tap().onEnd(() => {
  opacity.value = withTiming(opacity.value === 1 ? 0 : 1);
});
```
