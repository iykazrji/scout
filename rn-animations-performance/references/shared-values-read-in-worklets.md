# Read Shared Values Only in Worklets

**Impact:** CRITICAL

## Rule

Never read `.value` on the JS thread. Always read shared values inside worklets (`useAnimatedStyle`, `useDerivedValue`, `useAnimatedReaction`, gesture callbacks).

## Why

Reading `.value` on the JS thread requires a synchronous bridge call to the UI thread, blocking the JS thread until the value is retrieved. This causes frame drops and animation stuttering.

## Bad

```tsx
// ❌ Reading shared value on JS thread
function AnimatedBox() {
  const offset = useSharedValue(0);

  // This blocks the JS thread every render
  const currentOffset = offset.value;

  return (
    <Animated.View style={{ transform: [{ translateX: currentOffset }] }} />
  );
}
```

## Good

```tsx
// ✅ Reading shared value in a worklet
function AnimatedBox() {
  const offset = useSharedValue(0);

  const animatedStyle = useAnimatedStyle(() => {
    // Runs on UI thread - no bridge call
    return {
      transform: [{ translateX: offset.value }],
    };
  });

  return <Animated.View style={animatedStyle} />;
}
```

## Also Good

```tsx
// ✅ Reading in useDerivedValue worklet
const derived = useDerivedValue(() => {
  return offset.value * 2;
});

// ✅ Reading in gesture callback worklet
const gesture = Gesture.Pan().onUpdate((e) => {
  offset.value = e.translationX;
});

// ✅ Reading in useAnimatedReaction
useAnimatedReaction(
  () => offset.value,
  (current, previous) => {
    if (current !== previous) {
      // react to change on UI thread
    }
  }
);
```

## Exception

Reading `.value` is acceptable in event handlers (onPress, etc.) that don't run during animation frames:

```tsx
// ✅ OK in discrete event handler
const handlePress = () => {
  console.log('Current value:', offset.value);
};
```
