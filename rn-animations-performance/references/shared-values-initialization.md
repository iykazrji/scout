# Avoid Expensive Shared Value Initialization

**Impact:** HIGH

## Rule

Initialize shared values with simple primitives. Compute complex initial values in worklets or `useEffect`, not inline.

## Why

`useSharedValue(initialValue)` runs on the JS thread during component mount. Expensive computations here block the JS thread and delay the first frame.

## Bad

```tsx
// ❌ Expensive computation during initialization
function Chart({ data }) {
  // This runs synchronously on mount, blocking JS thread
  const points = useSharedValue(
    data.map((d, i) => ({
      x: i * (width / data.length),
      y: height - (d.value / maxValue) * height,
      color: interpolateColor(d.value / maxValue),
    }))
  );

  // ...
}
```

## Good

```tsx
// ✅ Initialize with simple value, compute in useEffect
function Chart({ data }) {
  const points = useSharedValue([]);

  useEffect(() => {
    points.value = data.map((d, i) => ({
      x: i * (width / data.length),
      y: height - (d.value / maxValue) * height,
    }));
  }, [data]);

  // ...
}
```

## Also Good

```tsx
// ✅ Simple primitive initialization
const offset = useSharedValue(0);
const scale = useSharedValue(1);
const opacity = useSharedValue(0);

// ✅ Small objects are fine
const position = useSharedValue({ x: 0, y: 0 });
```

## Rule of Thumb

If the initial value requires iteration, mapping, or calling other functions, move it to `useEffect`.
