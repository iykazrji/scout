# Batch Shared Value Updates with scheduleOnUI

**Impact:** HIGH

## Rule

When updating multiple shared values from the JS thread, batch them with `scheduleOnUI` to avoid multiple bridge crossings.

## Why

Each `.value = x` assignment from the JS thread sends a separate message across the bridge. Multiple updates in quick succession create multiple bridge crossings. `scheduleOnUI` batches them into a single worklet execution on the UI thread.

## Bad

```tsx
// ❌ Three separate bridge crossings
const resetAnimation = () => {
  translateX.value = withSpring(0);
  translateY.value = withSpring(0);
  scale.value = withSpring(1);
  rotation.value = withSpring(0);
};
```

## Good

```tsx
import { scheduleOnUI } from 'react-native-reanimated';

// ✅ Single bridge crossing, all updates batched
const resetAnimation = () => {
  scheduleOnUI(() => {
    'worklet';
    translateX.value = withSpring(0);
    translateY.value = withSpring(0);
    scale.value = withSpring(1);
    rotation.value = withSpring(0);
  })();
};
```

## When to Use

- Updating 3+ shared values simultaneously from JS thread
- Reset/initialize animations with multiple values
- Responding to events that update multiple animation properties

## When Not Needed

- Updates already inside a worklet (gesture handler, `useAnimatedReaction`)
- Single shared value update
- Updates in `useEffect` that don't need to be synchronous
