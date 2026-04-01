# Memoize Animation Objects

**Impact:** HIGH

## Rule

Define animation configurations as constants outside the component, or memoize them with `useMemo`. Never create animation objects inline in `useEffect` or event handlers.

## Why

`withSpring({ damping: 15, stiffness: 100 })` creates a new config object every render. While the object itself is cheap, repeatedly creating animation configs during rapid re-renders adds unnecessary GC pressure and can cause subtle timing issues.

## Bad

```tsx
// ❌ New spring config created every render
function BouncyBox({ isActive }) {
  const scale = useSharedValue(1);

  useEffect(() => {
    scale.value = withSpring(isActive ? 1.2 : 1, {
      damping: 15,
      stiffness: 150,
      mass: 0.5,
    });
  }, [isActive]);

  // ...
}
```

## Good

```tsx
// ✅ Config defined as constant outside component
const BOUNCE_CONFIG = {
  damping: 15,
  stiffness: 150,
  mass: 0.5,
};

function BouncyBox({ isActive }) {
  const scale = useSharedValue(1);

  useEffect(() => {
    scale.value = withSpring(isActive ? 1.2 : 1, BOUNCE_CONFIG);
  }, [isActive]);

  // ...
}
```

## Also Good

```tsx
// ✅ useMemo for dynamic configs based on props
function BouncyBox({ isActive, dampingFactor }) {
  const scale = useSharedValue(1);

  const springConfig = useMemo(
    () => ({
      damping: dampingFactor,
      stiffness: 150,
      mass: 0.5,
    }),
    [dampingFactor]
  );

  useEffect(() => {
    scale.value = withSpring(isActive ? 1.2 : 1, springConfig);
  }, [isActive, springConfig]);

  // ...
}
```
