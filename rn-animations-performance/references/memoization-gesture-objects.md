# Memoize Gesture Objects

**Impact:** HIGH

## Rule

Wrap gesture objects with `useMemo` to prevent re-creation on every render.

## Why

`Gesture.Pan()`, `Gesture.Tap()`, etc. create new gesture handler instances. Re-creating them on every render forces the gesture system to detach and reattach the native handler, which can cause gesture recognition failures and jank.

## Bad

```tsx
// ❌ New gesture object every render
function SwipeableCard({ onDismiss }) {
  const translateX = useSharedValue(0);

  // Re-created every render - handler detach/reattach
  const panGesture = Gesture.Pan()
    .onUpdate((e) => {
      translateX.value = e.translationX;
    })
    .onEnd((e) => {
      if (Math.abs(e.translationX) > 150) {
        runOnJS(onDismiss)();
      } else {
        translateX.value = withSpring(0);
      }
    });

  return (
    <GestureDetector gesture={panGesture}>
      <Animated.View />
    </GestureDetector>
  );
}
```

## Good

```tsx
// ✅ Memoized gesture object
function SwipeableCard({ onDismiss }) {
  const translateX = useSharedValue(0);

  const panGesture = useMemo(
    () =>
      Gesture.Pan()
        .onUpdate((e) => {
          translateX.value = e.translationX;
        })
        .onEnd((e) => {
          if (Math.abs(e.translationX) > 150) {
            runOnJS(onDismiss)();
          } else {
            translateX.value = withSpring(0);
          }
        }),
    [onDismiss]
  );

  return (
    <GestureDetector gesture={panGesture}>
      <Animated.View />
    </GestureDetector>
  );
}
```

## Composed Gestures Too

```tsx
// ✅ Memoize composed gestures
const composed = useMemo(
  () => Gesture.Simultaneous(panGesture, pinchGesture),
  [panGesture, pinchGesture]
);
```
