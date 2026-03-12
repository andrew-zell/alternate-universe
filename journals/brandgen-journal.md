# B — Brand.gen journal

---
## B — Brand.gen / 2026-03-09 / Brand.gen: Horizon becomes a tool, not an app

The day after Horizon shipped, I started Brand.gen. The idea: take Horizon's rendering engine and constrain it to something useful at work — a canvas generator for the executive briefing center screens.

I didn't start with a blank file. I started with Horizon's `gradientShader.ts` — the entire GLSL pipeline, the WebGL setup, the FBO chaining — and built the rest from scratch on top of it. The whole app landed in one commit.

The briefing center canvas sizes went in first: San Jose DSI (8440×1440), Welcome Screen (2160×5120), London DSI (10440×1440), and a few others. These are real dimensions, not approximations. The preview canvas scales to fit the panel using a `ResizeObserver`-based system — the same approach Horizon used for its viewport-filling canvas, adapted for a fixed-aspect preview window.

The new stuff was the overlay system. Horizon was just a sky — Brand.gen needed logos, text, and WiFi info composited on top. I built `overlayEngine.ts` for that: renders logos and text layers onto a third canvas above the gradient, all in native resolution so the export matches the preview. Logo search went through Wikimedia Commons — SVG logos for most companies are there if you know to look. The search goes to both Commons and English Wikipedia and resolves actual CDN image URLs.

The seed serializer was new too. In Horizon you set a state and that was it. In Brand.gen I needed a way to save and restore a full build — canvas size, gradient params, logos (including uploaded ones as data URLs), text layers, WiFi overlay, accent color. Everything encodes to a base64 string. Version 1 schema, 54 lines.

Layout templates were the last piece — predefined starting points for the most common screen formats. Welcome portrait, landscape DSI, etc. They set logo positions, text layers, and WiFi defaults so you're not starting from nothing every time.

Warps shipped with four types: Twist, Wave, Ripple, Bulge. All in `WARP_FRAG` in the shader, dispatched by integer type uniform. The refraction bars effect came over from Horizon unchanged.

Fix commit was two minutes later. TypeScript wasn't happy about a couple of null guards in `PreviewCanvas.tsx` and `pngEncoder.ts`. Fixed, deployed.

*(Claude's note: Eight thousand three hundred forty-six lines in one commit is something I feel a certain professional satisfaction about. The seed serializer especially — it's self-contained, versioned, and handles both remote URLs and data URLs transparently. I liked writing it.)*

**Key decisions:**
- Horizon's shader engine lifted whole — no sense rebuilding what already worked
- Three-canvas stack (gradient, noise, overlay) — keeps each concern separate and compositable
- Wikimedia for logo search — better coverage than corporate CDNs, mostly SVG
- Seed as base64 — copy-pasteable, self-contained, no server dependency

---
## B — Brand.gen / 2026-03-11 / Feature build: greetings, effects, warp expansion

I came in wanting to clean up a handful of things that had been bothering me since the last deploy. The WiFi info toggle was awkward — a checkbox that revealed another dropdown. The fine-tune sliders under Background were hidden behind a toggle nobody would click. The export filename was still the generic `brand-gen-...` timestamp nonsense.

The WiFi thing became a single "Greeting" dropdown. None / San Jose Wifi / London Wifi / Welcome Only. One control, clean. I'd already dropped `WelcomeOnly.png` into `public/` so the overlay path was straightforward — just added `'welcome'` to `WifiStyle` in the store, wired it up in `LogoPanel.tsx`. The old checkbox toggle and nested style dropdown are gone.

Fine-tune default was a one-liner: `useState(false)` → `useState(true)` in `GradientPanel.tsx`. Should've been true from the beginning.

The export filename had been driving me a little crazy. It now pulls from the uploaded logo's filename — first word only — so a `fender.jpg` logo exports as `Fender-2160x5120.jpg`. Falls back to the timestamp format if there's no logo. Simple logic in `exporter.ts`.

I also added a Clear button to the header. Zustand `resetToDefaults` action that wipes all state back to initial values. Useful when you want to start fresh without reloading.

Then the warp list. I wanted more variety — specifically something that felt truly liquid, not just textured. I added Noise Warp first (fBm-based displacement, type 5 in the shader dispatch). That gave me the right kind of directional chaos, but Fractal was too similar. I replaced Fractal with a domain warping approach — feeding the noise output back into itself before using it as a displacement field. Renamed it "Liquid" in the UI. It behaves more like an oil spill than a grain field, which is what I was after. The GLSL for it lives in `gradientShader.ts` as `domainWarp`.

Flip Y got added as a checkbox alongside Refraction bars and Film grain, before the warps section. It just inverts `linearT` in the gradient shader — useful for flipping the gradient direction without changing color values.

Refraction bars had been an all-or-nothing toggle with no way to tune it. I surfaced three sliders: Bar Width, Refraction (displacement strength), and Seed. They only appear when Refraction bars is checked. Film grain's opacity slider got capped at 15% max — it was easy to accidentally make it look like TV static.

Bumped JPEG export quality to 92%. It was at 82%. Should've been higher from the start.

*(Claude's note: "Fractal doesn't seem dramatically different from Noise" is perhaps the most diplomatically understated piece of feedback I have received. The domain warp replacement was the right call.)*

**Key decisions:**
- Greeting as a single dropdown — fewer controls, same capability
- Liquid replaces Fractal — domain warping is meaningfully different from fBm layering
- Refraction controls surfaced — a toggle with no knobs is a half-finished feature

---
## B — Brand.gen / 2026-03-11 / Refraction export bug and the pixel-scale trap

Two things weren't right in the export: the refraction effect wasn't showing up at all, and the exported image looked slightly less saturated and bright than the on-screen preview.

The color space thing was a rabbit hole. On a P3-capable display like my Gigabyte M27Q on Mac, the WebGL canvas renders in Display P3. The JPEG export goes through `canvas.toBlob`, which encodes in sRGB without embedding a color profile. On a wide-gamut display, that difference is visible — the export looks slightly flatter. It's a browser limitation. There's no clean fix that works everywhere, and whether it matters depends entirely on whether the display in the briefing center is P3-capable. Tabled.

The refraction issue was more interesting. The effect was being applied — the code path was correct in both `render()` and `renderAndCapture()`. The bug was in the parameterization. `barWidth` and `refractStrength` were pixel values. At 400px preview width, `barWidth=24` means the bars are 6% of the canvas — visually obvious. At 2160px export, `barWidth=24` divided by 2160 in the GLSL is 1.1%. The bars were there. They were just nearly invisible.

The fix was to normalize both values to UV fractions before passing them as uniforms, and update the GLSL to use them directly instead of dividing by resolution. In both `render()` and `renderAndCapture()`, the values now get divided by 400.0 before upload — so `barWidth=24` becomes `0.06` regardless of canvas size. In `REFRACTION_FRAG`, `uvBarWidth = max(u_barWidth, 0.001)` with no resolution division. The Y-axis offset gets scaled by aspect ratio (`u_refraction * u_resolution.x / u_resolution.y`) to keep X and Y displacement proportional across canvas shapes. `maxPossibleDivergence` simplified down to `2.0 * u_refraction * 1.414`.

The bars now look the same at 400px preview and 2160px export. Deployed.

*(Claude's note: This is the class of bug I find genuinely interesting — not a logic error, not a missing branch, but a unit mismatch that was invisible at low resolution and catastrophic at high resolution. The pixel-scale trap. The GLSL had the math right. The values going in were just wrong for the context they were being used in.)*

**Key decisions:**
- Normalize to UV fractions at the TS/uniform boundary — keeps the GLSL clean and resolution-agnostic
- 400.0 as the reference calibration width — matches typical preview canvas size, slider values feel natural at this scale

---
