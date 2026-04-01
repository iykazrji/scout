# Memoize Frame Callbacks

**Impact:** HIGH

## Rule

Wrap `useFrameCallback` callbacks with `useCallback` to prevent re-registration on every render.

## Why

`useFrameCallback` registers a callback that runs every frame. If the callback reference changes on re-render, the old callback is unregistered and a new one is registered, causing a frame skip.

## Bad

```tsx
// ❌ New callback reference every render
function ParticleSystem({ particleCount }) {
  const particles = useSharedValue([]);

  useFrameCallback((frameInfo) => {
    // This callback is re-registered every render
    const dt = frameInfo.timeSincePreviousFrame ?? 0;
    particles.value = particles.value.map((p) => ({
      ...p,
      y: p.y + p.velocity * dt,
    }));
  });

  // ...
}
```

## Good

```tsx
// ✅ Stable callback reference
function ParticleSystem({ particleCount }) {
  const particles = useSharedValue([]);

  const updateParticles = useCallback((frameInfo) => {
    'worklet';
    const dt = frameInfo.timeSincePreviousFrame ?? 0;
    particles.value = particles.value.map((p) => ({
      ...p,
      y: p.y + p.velocity * dt,
    }));
  }, []);

  useFrameCallback(updateParticles);

  // ...
}
```

## Note

This also applies to `useAnimatedScrollHandler` and other hooks that accept callback functions - always ensure stable references.
