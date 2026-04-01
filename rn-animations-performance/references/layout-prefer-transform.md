# Prefer Transform Over Layout Properties

**Impact:** HIGH

## Rule

Animate `transform` properties (translateX/Y, scale, rotate) instead of layout properties (width, height, top, left, margin, padding).

## Why

Transform animations run on the GPU and don't trigger layout recalculation. Layout property changes force the native layout engine (Yoga) to recalculate the entire subtree, which is expensive and causes frame drops.

## Bad

```tsx
// ❌ Animating layout properties - triggers Yoga recalculation
const animatedStyle = useAnimatedStyle(() => ({
  width: interpolate(progress.value, [0, 1], [100, 300]),
  height: interpolate(progress.value, [0, 1], [100, 300]),
  marginLeft: interpolate(progress.value, [0, 1], [0, 50]),
}));
```

## Good

```tsx
// ✅ Transform properties - GPU accelerated, no layout recalc
const animatedStyle = useAnimatedStyle(() => ({
  transform: [
    { scale: interpolate(progress.value, [0, 1], [1, 3]) },
    { translateX: interpolate(progress.value, [0, 1], [0, 50]) },
  ],
}));
```

## Layout Properties to Avoid Animating

- `width`, `height`
- `top`, `left`, `right`, `bottom`
- `margin*`, `padding*`
- `flex`, `flexBasis`

## Transform Properties (GPU Accelerated)

- `translateX`, `translateY`
- `scale`, `scaleX`, `scaleY`
- `rotate`, `rotateX`, `rotateY`, `rotateZ`
- `skewX`, `skewY`

## Exception

If you must animate layout properties (e.g., collapsible sections), minimize the animated subtree and consider using `LayoutAnimation` for discrete transitions instead of continuous animation.
