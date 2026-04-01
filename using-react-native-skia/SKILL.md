---
name: using-react-native-skia
description: Use when writing SKSL shaders, rendering Skia Canvas content, capturing views as SkImage, handling PixelRatio/supersampling, or building shader-based visual effects with @shopify/react-native-skia. Triggers on tasks involving runtime shaders, drawAsImage, makeImageFromView, glass spheres, refraction, chromatic aberration, or crisp high-DPI rendering.
---

# React Native Skia — Patterns & Techniques

Practical patterns for `@shopify/react-native-skia` runtime shaders, image capture, supersampling, and physically-based effects.

## Fixing Pixelated / Blurry Canvas Content

**If text, images, or shapes in a Skia Canvas look pixelated or blurry, it's almost always a `PixelRatio` issue.** `drawAsImage` renders at 1x resolution by default — on a 3x Retina screen this means 9x fewer pixels than the display, causing visible pixelation on text, image edges, and fine details.

**Quick fix:** Multiply all dimensions and coordinates by `PixelRatio.get()` when building the offscreen image, including font sizes. Then display the resulting hi-res image at logical size via `ImageShader`. See Approach A below.

**If using Group transform supersampling** (Approach B), scale all distance-based shader uniforms (positions, radii, amplitudes) by `PixelRatio.get()`. Time-based uniforms (frequency, decay) stay unscaled.

## Supersampling (Crisp High-DPI Rendering)

### Approach A: Scale the source image (drawAsImage)

Render at `PixelRatio.get()` scale, then display at logical size:

```tsx
const PD = PixelRatio.get();

// Font must also be scaled
const font = matchFont({ fontFamily: "System", fontSize: 42 * PD, fontWeight: "bold" });

// Build group in pixel space (all coords multiplied by PD)
const group = <Group>
  <Rect x={0} y={0} width={w * PD} height={h * PD}>...</Rect>
  <Text x={x * PD} y={y * PD} font={font} text="Hello" />
</Group>;

// Render at pixel dimensions
const pixelSize = { width: w * PD, height: h * PD };
const image = await drawAsImage(group, pixelSize);

// Display at logical size — ImageShader maps hi-res image to logical coords
<ImageShader image={image} width={w} height={h} fit="fill" />
```

### Approach B: Group transform (runtime rendering)

Scale up inner group, scale down outer group:

```tsx
<Canvas style={{ width, height }}>
  <Group transform={[{ scale: 1 / PD }]}>
    <Group transform={[{ scale: PD }]}
      layer={<Paint><RuntimeShader source={effect} uniforms={scaledUniforms} /></Paint>}>
      <SkiaImage image={snapshot} width={width} height={height} />
    </Group>
  </Group>
</Canvas>
```

Scale all distance-based uniforms by PD (origin, amplitude, speed). Time-based uniforms (frequency, decay) stay unscaled.

### Coordinate spaces

Skia runtime shader `fragCoord` operates in the **local coordinate system** of the drawing node — matching the logical dimensions set on `<Rect>`. Uniforms should be in logical coordinates unless using Group transform supersampling.

## Image Capture

### drawAsImage — Skia elements to SkImage

For rendering Skia primitives (gradients, text, shapes) into a texture the shader can sample:

```tsx
const group = buildBackgroundGroup(layout); // Returns <Group>...</Group>
const image = await drawAsImage(group, { width, height });
```

### makeImageFromView — Native RN views to SkImage

For capturing rendered React Native views (with native components, text, images):

```tsx
const contentRef = useRef<View>(null);
const snapshot = await makeImageFromView(contentRef);
```

Delay capture ~250ms after mount to ensure layout is complete.

## Shader Compilation

Compile once at module level, never inside components:

```tsx
const effect = Skia.RuntimeEffect.Make(SHADER_SOURCE);

// In component:
if (!effect) return null;
```

## Animation — Always Use `useClock()`

**`useClock()` is the ONLY timing mechanism you should use for Skia animations.** It ticks every frame on the UI thread with zero JS bridge crossings. Never implement custom timing with `requestAnimationFrame`, `setInterval`, `Animated.timing`, or manual shared value updates.

```tsx
const clock = useClock(); // ms, ticks every frame on UI thread

// Derive all time-based values from clock
const elapsed = useDerivedValue(() => clock.value / 1000);

// Sinusoidal motion
const blobX = useDerivedValue(() => {
  const t = clock.value / 1000;
  return (0.28 + Math.sin(t * 0.31) * 0.14) * width;
});

// Shader uniforms driven by clock
const uniforms = useDerivedValue(() => ({
  u_time: clock.value / 1000,
  u_resolution: [width, height],
}));
```

**Why not other timing approaches:**
- `requestAnimationFrame` — runs on JS thread, crosses bridge to UI thread
- `withRepeat(withTiming(...))` — fine for simple loops, but `useClock` is more flexible for complex multi-value animations
- `setInterval` / `setTimeout` — JS thread, unreliable timing, bridge crossing
- Manual `useSharedValue` + frame callback — reinventing what `useClock` already does

**For particle/bubble elapsed time:** Use `Date.now()` inside `useDerivedValue` with `clock.value` as the subscription trigger. The clock read subscribes the derived value to frame updates; `Date.now()` provides the actual elapsed calculation:

```tsx
const x = useDerivedValue(() => {
  const _tick = clock.value; // subscribe to frame updates
  const elapsed = (Date.now() - spawnTime) / 1000;
  return startX + vx * elapsed;
});
```

## Skia Text Rendering

Use `matchFont` with system fonts (no font file loading needed):

```tsx
import { matchFont, Text as SkiaText } from "@shopify/react-native-skia";
const font = matchFont({ fontFamily: "System", fontSize: 42, fontWeight: "bold" });
<SkiaText x={x} y={y} text="Hello" font={font} color="#000" />
```

For custom letter spacing, render character-by-character using `font.getGlyphIDs()` and `font.getGlyphWidths()`.

## Glass Sphere Shader Techniques

### Sphere normal from 2D pixel position

```glsl
vec2 nxy = pixelDist / lensRadius;      // normalized position on disk
float nz = sqrt(max(1.0 - dot(nxy, nxy), 0.0));  // hemisphere z
vec3 normal = vec3(nxy, nz);            // surface normal
```

### Double refraction (entry + exit surface)

The key to realistic glass. Light refracts at front surface, travels through sphere, refracts again exiting back surface:

```glsl
// 1. Refract INTO sphere (air -> glass)
vec3 refractIn = refract(viewRay, frontNormal, 1.0 / ior);

// 2. Find back surface hit (ray-sphere intersection from inside)
vec2 tBack = sphIntersect(frontPos, refractIn, 1.0);
vec3 backPos = frontPos + refractIn * tBack.y;
vec3 backNormal = normalize(backPos);

// 3. Refract OUT (glass -> air) — note negated normal (hitting from inside)
vec3 refractOut = refract(refractIn, -backNormal, ior);
if (length(refractOut) < 0.001) refractOut = reflect(refractIn, -backNormal); // TIR fallback
```

### Ray-sphere intersection

Returns (tEntry, tExit) for a sphere centered at origin:

```glsl
vec2 sphIntersect(vec3 ro, vec3 rd, float ra) {
  float b = dot(ro, rd);
  float c = dot(ro, ro) - ra * ra;
  float h = b * b - c;
  if (h < 0.0) return vec2(-1.0);
  h = sqrt(h);
  return vec2(-b - h, -b + h);
}
```

### Fresnel (Schlick approximation)

Determines reflection/refraction blend — edges become mirror-like:

```glsl
float r0 = (1.0 - ior) / (1.0 + ior);
r0 = r0 * r0;
float fresnel = r0 + (1.0 - r0) * pow(1.0 - cosTheta, 5.0);
vec3 color = mix(refractionColor, reflectionColor, fresnel);
```

### Physical chromatic dispersion

Run full double-refraction path per channel with slightly different IOR:

```glsl
float iorR = ior - 0.03, iorG = ior, iorB = ior + 0.03;
// Full refract-in → back-surface → refract-out per channel
float r = image.eval(fragCoord + offsetR).r;
float g = image.eval(fragCoord + offsetG).g;
float b = image.eval(fragCoord + offsetB).b;
```

### Specular highlights (Blinn-Phong)

```glsl
vec3 halfVec = normalize(lightDir + viewDir);
float NdotH = max(dot(normal, halfVec), 0.0);
float spec = pow(NdotH, 180.0); // tight highlight
```

### Caustic bright spot

Light focuses through the sphere to the opposite side from the light source:

```glsl
float causticDot = max(dot(frontNormal, -lightDir), 0.0);
float caustic = pow(causticDot, 12.0) * 0.2;     // broad
float causticCore = pow(causticDot, 48.0) * 0.15; // tight hot spot
```

### Ray-traced sphere reflections

Reflect view direction off surface, intersect with virtual sphere:

```glsl
vec3 reflDir = reflect(-viewDir, normal);
vec3 oc = surfacePos - sphereCenter;
float b = dot(oc, reflDir);
float c = dot(oc, oc) - radius * radius;
float disc = b * b - c;
if (disc > 0.0) {
  float t = -b - sqrt(disc);
  if (t > 0.0) { /* hit — shade reflected sphere */ }
}
```

### Anisotropic specular (stretched arc highlights)

Ward-style: tight vertically, spread horizontally for arc-shaped reflections:

```glsl
vec3 tangent = normalize(vec3(-normal.z, 0.0, normal.x));
vec3 bitangent = normalize(cross(normal, tangent));
float hDot = dot(halfVec, tangent);
float vDot = dot(halfVec, bitangent);
float anisoSpec = pow(NdotH, 8.0) * exp(-vDot*vDot * 180.0) * exp(-hDot*hDot * 6.0);
```

### Internal reflection

At back surface, some light reflects internally creating secondary highlights:

```glsl
float internalFresnel = pow(1.0 - max(dot(-backNormal, refractIn), 0.0), 5.0);
vec3 internalReflDir = reflect(refractIn, -backNormal);
float highlight = pow(max(dot(internalReflDir, viewDir), 0.0), 32.0);
color += highlight * internalFresnel * 0.12;
```

## Compositing Order for Glass

1. Double-refracted background (with chromatic dispersion)
2. Mix with environment reflection via Fresnel
3. Add specular highlight (additive)
4. Add reflected objects (ray-traced, blended by Fresnel)
5. Add caustic bright spot (additive, opposite light source)
6. Add internal reflection (additive, subtle)
7. Add rainbow rim dispersion at edge
8. Soft edge transition via `smoothstep`

## Circular Avatar Textures (Pre-Rendering with drawAsImage)

When rendering circular avatar images inside animated elements (bubbles, particles), pre-render them as circular textures on mount rather than clipping per frame:

```tsx
const circularAvatars = useCircularAvatars(); // returns (SkImage | null)[]
```

**Why pre-render:** With N bubbles × 2 render passes (visible + shader), that's 2N clip path operations per frame. Pre-rendering produces simple rectangular texture blits.

**Approaches tried and why they failed:**
- **ImageShader**: `<ImageShader>` tiles as shader fill — doesn't fit to bounds, requires manual UV
- **Clip paths in worklets**: `Skia.Path.Make()` is a JS-thread factory, crashes in UI-thread worklet context
- **Per-frame clip in render tree**: Works but O(N) clip operations per frame per render pass
- **`drawAsImage` pre-render (winner)**: One-time circular clip, produces simple textures at fixed resolution

```tsx
const clipPath = Skia.Path.Make();
clipPath.addCircle(size / 2, size / 2, size / 2);

const group = (
  <Group clip={clipPath}>
    <SkiaImage image={img} x={0} y={0} width={size} height={size} fit="cover" />
  </Group>
);
const texture = await drawAsImage(group, { width: size, height: size });
```

## Dual-Render Pattern (Scene Content + Shader Sampling)

When a RuntimeShader needs to sample the scene (for refraction, displacement, etc.), the scene must be rendered twice:
1. **Visible pass** — direct rendering for the background
2. **Shader pass** — identical scene inside a Group with RuntimeShader layer paint

Extract shared scene content into reusable components to avoid JSX duplication:

```tsx
// OrbShaderLayer wraps children with supersampling + shader
<Canvas>
  {/* Visible layer */}
  <AnimatedBlobs ... />
  <AvatarBubbles ... />

  {/* Shader layer — same content, wrapped */}
  <OrbShaderLayer shaderUniforms={uniforms} width={w} height={h}>
    <AnimatedBlobs ... />
    <AvatarBubbles ... />
  </OrbShaderLayer>
</Canvas>
```

## Clock-Driven Animation with Ring Buffer

For particle/bubble systems, use a shared value ring buffer with `useClock()`:

```tsx
// JS-side: spawn into ring buffer slot
const bubblesData = useSharedValue<BubbleData[]>(Array(SLOT_COUNT).fill(emptyBubble));
const spawnBubble = () => {
  const slot = nextSlot.current % SLOT_COUNT;
  bubblesData.value = [...bubblesData.value]; // copy to trigger update
  bubblesData.value[slot] = { startX, startY, vx, vy, spawnTime: Date.now() };
};

// UI-thread: derive position from clock tick
const x = useDerivedValue(() => {
  const _tick = clock.value; // subscribe to frame updates
  const d = bubblesData.value[idx];
  const elapsed = (Date.now() - d.spawnTime) / 1000;
  return d.startX + d.vx * elapsed;
});
```

**Key pattern:** `clock.value` is read only as a subscription trigger. Actual elapsed time uses `Date.now()` inside the worklet. This keeps all per-frame computation on the UI thread with zero JS bridge crossings.

**Hook call stability:** Since React hooks must be called unconditionally, create all N slot hooks upfront even if fewer are active. Use a fixed count, not a dynamic array.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Blurry text/images from `drawAsImage` | Render at `PixelRatio.get()` scale |
| Flat-looking glass (single refraction) | Use double refraction (entry + exit surface) |
| Refraction centered on screen instead of lens | Use `lensCenter / resolution` as zoom pivot, not `vec2(0.5)` |
| White orb on white background | Add Fresnel edge darkening + glass tint |
| Shader uniforms at wrong scale with Group transform | Scale distance-based uniforms by `PixelRatio.get()` |
| Soft/blurry sphere edge | Use tight `smoothstep(1.0, 0.993, dist)` |
| `makeImageFromView` captures blank | Delay capture ~250ms after mount |
| Shader recompiles every render | Move `RuntimeEffect.Make()` to module scope |
| Circular clips per-frame in bubbles | Pre-render with `drawAsImage` once on mount |
| `Skia.Path.Make()` in worklet | JS-only factory — use pre-allocated paths or pre-rendered textures |
| Scene content duplicated as raw JSX | Extract into shared components for dual-render pattern |
| `useBubbleSlot` hook inside component body | Move to proper custom hook file; call count must be static |
| Dead SKSL functions bloating shader | Audit with grep — unused functions still compile and consume GPU |

## IOR Reference

| Material | IOR |
|----------|-----|
| Air | 1.0 |
| Water | 1.33 |
| Glass | 1.5 |
| Crystal | 1.8–2.0 |
| Diamond | 2.42 |
