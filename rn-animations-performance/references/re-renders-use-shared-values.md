# Use Shared Values Instead of Component State

**Impact:** CRITICAL

## Rule

Never use `useState` for values that drive animations. Use `useSharedValue` instead.

## Why

`useState` triggers a React re-render on every update. During a gesture or continuous animation, this means re-rendering the component 60 times per second, which overwhelms the JS thread and causes frame drops.

`useSharedValue` updates happen on the UI thread without triggering React re-renders.

## Bad

```tsx
// ❌ useState triggers re-render every frame
function DraggableCard() {
  const [translateX, setTranslateX] = useState(0);
  const [translateY, setTranslateY] = useState(0);

  const gesture = Gesture.Pan().onUpdate((e) => {
    // 60 re-renders per second!
    setTranslateX(e.translationX);
    setTranslateY(e.translationY);
  });

  return (
    <GestureDetector gesture={gesture}>
      <Animated.View
        style={{
          transform: [{ translateX }, { translateY }],
        }}
      />
    </GestureDetector>
  );
}
```

## Good

```tsx
// ✅ useSharedValue - zero re-renders during animation
function DraggableCard() {
  const translateX = useSharedValue(0);
  const translateY = useSharedValue(0);

  const gesture = Gesture.Pan().onUpdate((e) => {
    // Updates on UI thread, no re-renders
    translateX.value = e.translationX;
    translateY.value = e.translationY;
  });

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [
      { translateX: translateX.value },
      { translateY: translateY.value },
    ],
  }));

  return (
    <GestureDetector gesture={gesture}>
      <Animated.View style={animatedStyle} />
    </GestureDetector>
  );
}
```

## When useState Is OK

- Values that should trigger UI updates (showing/hiding elements)
- Discrete state changes (not continuous animations)
- Values only used in non-animated parts of the component
