# Cancel Running Animations Before Starting New Ones

**Impact:** MEDIUM

## Rule

Use `cancelAnimation` before starting a new animation on the same shared value, especially when responding to rapid user input.

## Why

Starting a new animation while one is running causes the old animation to be interrupted abruptly. With spring animations, this can cause visual glitches. With timing animations, the starting position may be unexpected. Explicit cancellation ensures clean transitions.

## Bad

```tsx
// ❌ Rapid taps create animation conflicts
const handlePress = () => {
  // If spring is still settling, new spring starts from current
  // interpolated position with potentially wrong velocity
  scale.value = withSpring(1.2, {}, () => {
    scale.value = withSpring(1);
  });
};
```

## Good

```tsx
import { cancelAnimation } from 'react-native-reanimated';

// ✅ Cancel before starting new animation
const handlePress = () => {
  cancelAnimation(scale);
  scale.value = withSpring(1.2, {}, () => {
    scale.value = withSpring(1);
  });
};
```

## Cleanup on Unmount

```tsx
useEffect(() => {
  return () => {
    // Cancel all animations on unmount
    cancelAnimation(translateX);
    cancelAnimation(translateY);
    cancelAnimation(scale);
  };
}, []);
```

## When Cancellation Matters Most

- Gesture-driven animations (user can interrupt at any point)
- Rapid sequential triggers (button mashing, scroll events)
- Looping animations that need to stop cleanly
- Component unmount during active animation
