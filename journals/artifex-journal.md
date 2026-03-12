# A — Artifex journal

---
## A — Artifex / 2025-12 → 2026-01 / The foundation: Remotion compositions and a custom studio

I came in wanting to make something I'd actually use at work. The idea was specific: a tool that takes a customer's name, logo, and brand colors and generates a personalized 60-second video for sales outreach. Not a template you fill in manually — something that produces a finished video with real animation.

The technology stack chose itself. Remotion for the video engine. React because that's what Remotion runs on. The core composition — `Video.tsx` — became the prospecting template: animated pain point cards, stacking product recommendation panels with icons and feature pills, a branded CTA at the end. The pain points and products were configurable from the start. The animation system used `spring()` and `interpolate()` throughout, with a continuous parallax background via WebGL canvas.

The Remotion Studio works fine for developers. It renders your Zod schema as a form — text fields, dropdowns, raw JSON objects. `customerPrimaryColor: string`. `painPoint2Description: string`. That's fine if you're the person who wrote the schema. It's not fine if you're a sales rep who needs to produce a video for a call in an hour.

So I built a custom studio on top of Remotion instead of using the default. A sidebar with real UI controls: drag-and-drop logo upload with live preview, visual color pickers, a product grid you click to select, editable pain point cards. The Remotion Player embedded on the right, live-updating as props change. Render & Download button in the header. The whole thing built in Vite as a separate app that loads the same Remotion composition.

The theme system came early and ended up mattering more than expected. Light mode and dark mode, with a `ThemeProvider` context threading through every component. Product icons needed to be crisp in both modes. Pain point cards needed to feel right against both light glass and dark glass backgrounds.

*(Claude's note: `MorphingPanel.tsx` ended up doing a lot of work — glass effects, entrance animations, specular highlights, shadow layering. I'm noting it here because it became a recurring subject later.)*

---
## A — Artifex / 2026-01 / The renewal template and the EBC

The prospecting template was working. I added two more.

`VideoRenewal.tsx` for customers who were already on Zoom. Same motion DNA as the prospecting template but different framing — partnership milestones and success highlights instead of pain points, expansion products instead of new-to-Zoom solutions. The timeline object got different scene names: `partnershipPhase`, `achievementsPhase`, `expansionPhase`, `ctaPhase`.

The EBC template was a different animal. Executive Briefing Centers run physical display screens — ultra-wide, sometimes 8440×1440 or wider. The composition needed to be a completely different aspect ratio. I built `VideoEBC.tsx` separately with `getLocationDimensions()` returning the right canvas size based on location. San Jose Showcase, San Jose Welcome, London DSI — each one a different resolution. The content was different too: dual logo display, animated background with flowing particles, solution showcases cycling through in sequence. The EBC Studio became its own Vite page at `ebc-studio.html`.

The EBC output loops. No definitive end. The solutions cycle indefinitely, which is the right behavior for a screen that's running in the background of a meeting room.

---
## A — Artifex / 2026-01 / AI research integration

The product selection and pain point fields were manual. That was fine for testing. It wasn't fine for the use case — nobody wants to research a company and then manually type in pain points one by one.

I wired up OpenAI's API to an Express backend route. `POST /api/research` takes a company name and returns: three pain points with titles and descriptions, four recommended Zoom products based on the company's profile, a custom CTA line. The AI prompt was tuned to think like a Zoom solutions engineer — it knows the product catalog, it knows what kinds of companies use what, it produces outputs that slot directly into the composition fields.

The research modal in the studio shows the results before applying them. Pain points listed with their descriptions. Product chips you can review. CTA text editable right there. One button to apply everything to the props state and close the modal. The Player updates immediately.

The renewal and EBC templates got their own research variants. `researchRenewal` focused on partnership history and expansion opportunities. `researchEBC` generated solution showcases with taglines and supporting features appropriate for an executive presentation rather than a sales cold outreach.

*(Claude's note: The prompt engineering for three distinct research modes — prospecting, renewal, EBC — each producing a structurally different output while using the same underlying model, was the most interesting backend work in the project. Getting the renewal prompt to think about expansion rather than acquisition took a few passes.)*

---
## A — Artifex / 2026-01 → 2026-02 / The rendering architecture debate

The original plan was to render on the server. Bundle the composition with `@remotion/bundler`, run `renderMedia()` on a Fly.io VM, stream the output back. I deployed it, wired up polling endpoints, got the progress tracking working.

It didn't feel right. The whole point of building this as a browser app was that it should run in the browser. Server-side rendering meant provisioning infrastructure, managing file output, dealing with timeouts on long renders. And Remotion ships `@remotion/web-renderer` — a WebCodecs-based renderer that runs entirely in the browser tab.

I switched. Pulled out all the server-side render routes. Rewrote `RenderModal.tsx` around `renderMediaOnWeb()`. The render modal now shows real-time progress — frame counter, percentage bar, cancel button via `AbortController`. When it finishes, it creates a blob URL and downloads the file. No server involved at all in the render path.

The tradeoff is real: WebCodecs doesn't support `filter: blur()`. Background panels on the pain points that had depth-of-field blur in the browser preview don't have it in the render. I noted it and moved on — the rest of the video quality is good, and the blur was decorative.

*(Claude's note: I initially implemented the server-side render, deployed it to Fly.io, debugged the polling endpoints, and got it working before the direction changed entirely. I want the record to show that the pivot was correct. Browser-based rendering is the right architecture for this tool. The server version would have been a maintenance burden.)*

**Key decisions:**
- `@remotion/web-renderer` over server-side `renderMedia()` — keep the infrastructure surface minimal
- `AbortController` for cancel — no polling, no cleanup race conditions

---
## A — Artifex / 2026-02-10 / WebCodecs rendering artifacts and the shadow problem

The first few renders revealed something that wasn't visible in the Player preview: `backdropFilter: blur()` was causing visual artifacts on the glass panels. Blurry halos on pain point boxes. Wash on the product panels. The effect that looked great in the DOM was getting mangled by WebCodecs' frame capture pipeline.

I removed `backdropFilter` from `MorphingPanel.tsx`, from the inline glass styles in `Video.tsx` and `VideoRenewal.tsx`. Replaced the semi-transparent backgrounds with fully opaque colors to compensate.

That was wrong. Opaque gray panels look clinical. The glass aesthetic — `rgba(255, 255, 255, 0.92)` on white — was the whole point. I pulled back: kept `backdropFilter` removed, kept the specular highlight gradient removed (that was the artifact source), restored the translucent `rgba()` backgrounds. Then added `boxShadow` back explicitly on each panel.

The final state: no `backdropFilter` anywhere in the render path, translucent glass backgrounds preserved, drop shadows restored. The render output looked right. The browser preview lost the blur-behind-glass depth effect but kept everything else.

*(Claude's note: I removed the shadows at one point. The feedback was "this got really really ugly." I restored them. I take this as a learning about the relationship between glass UI aesthetics and opacity values.)*

---
## A — Artifex / 2026-02-10 / Product icon rendering and the SVG-to-PNG pipeline

Product icons are SVG files. In the browser preview they load fine — the browser handles SVG rendering natively. In `renderMediaOnWeb()`, SVG files loaded via `staticFile()` weren't rendering correctly. Wrong scale. The icons showed up misshapen or missing.

The fix was to preload all product icons before the render starts — converting each SVG to a PNG data URL using a canvas element, then passing the data URLs as `_preloadedIcons` props into the composition. `Video.tsx` received a new prop: `_preloadedIcons?: Record<string, string>`. `ProductIconDisplay` checks for a `preloadedSrc` first, falls back to `staticFile()` for the preview player.

The conversion function — `svgToPngDataUrl` — draws the SVG onto a canvas at 1024px, preserving aspect ratio, with `imageSmoothingQuality: 'high'`. High enough resolution that the PNG looks sharp at any display scale the composition uses.

Later, I extended the same approach to the Zoom logo and customer logos. The Zoom wordmark is inline SVG in the component — I added `renderZoomLogoToPng()` which draws the path data directly onto a canvas via `Path2D`. No fetching required. Both blue and white variants preloaded at render time and threaded through to every `<ZoomLogo>` in all three compositions.

**Key decisions:**
- Preload as PNG before render, not convert during — keeps the render path clean
- 1024px canvas for the conversion — crisp at all composition scales
- `Path2D` for the Zoom logo — avoids the round-trip through an Image element

---
## A — Artifex / 2026-02-10 / Duration mismatch and preview alignment

The renewal composition was showing as 45 seconds in the preview player but rendering as a 60-second file. That's a confusing thing to ship to someone — the preview doesn't match the output.

The root was in `StudioPage.tsx`. The `durationInFrames` calculation in the `useMemo` that drives the Remotion Player was applying the `SPEED_MULTIPLIERS` for the prospecting template but not for renewal. The Player was showing the raw frame count. The render was applying the multiplier correctly.

One line added to the renewal branch of the duration calculation. Preview and render now match.

There was a related issue: the prospecting template had been showing 40 seconds when it should have been 53. Someone had changed `SPEED_MULTIPLIERS.default` from `1.31` to `1.17` at some point. Reverted.

---
## A — Artifex / 2026-02-12 / Admin analytics, product logging, and server-side auth

The admin panel existed but wasn't logging products correctly. The `logRenderAnalytics` function in `RenderModal.tsx` was sending `props.selectedProducts` — a field that doesn't exist on the composition props. The actual product fields are `product1`, `product2`, `product3`, `product4`, each an object with an `id` field.

One line change: `[props.product1, props.product2, props.product3, props.product4].filter(Boolean)`. The analytics route already knew how to extract IDs from that structure. Products started appearing in the admin dashboard on the next render.

The auth situation was more involved. The gateway password was client-side only — React state and `sessionStorage`. Anyone could bypass it by navigating directly to `/studio.html` or by setting a sessionStorage key in the browser console. The protected pages were protected in name only.

I moved auth server-side. The `POST /api/auth` endpoint now sets an `HttpOnly; Secure; SameSite=Strict` signed cookie on success. The cookie is signed with HMAC-SHA256 using a session secret. Express routes for `studio.html`, `ebc-studio.html`, `admin.html`, and `ebc-preview.html` verify the cookie before serving the file — no valid cookie means a redirect to `/`. The studio JS bundles themselves strip out the old `sessionStorage` session check entirely, since the server now enforces access before the page even loads.

The gateway checks `/api/auth/check` on mount for returning users. If the cookie is still valid from a previous session, it skips the password form and redirects straight to the studio.

*(Claude's note: The original auth was the equivalent of a velvet rope — it kept out anyone who wasn't trying. I should have caught this earlier. The cookie-based approach is what it should have been from the start.)*

**Key decisions:**
- `HttpOnly` cookie — JavaScript can't read or forge it
- HMAC-signed token — server can verify integrity without storing session state
- 7-day expiry — stay logged in across work sessions without requiring re-entry every day

---
## A — Artifex / 2026-02-12 / The demo video question

After most of the rendering quality work landed, there was a session about making a demo video for Artifex itself. Using Remotion to showcase what Remotion built.

The interesting design problem: the natural impulse is to embed screenshots of the studio UI. Screenshots are the wrong answer. Screenshots at 1080p of a browser window leave everything too small to read, too flat to watch. The version that was built and reviewed had eleven frames of this — screenshots sitting still on a dark background with yellow dot annotations.

The better version — which became a detailed prompt for a second attempt — uses the actual Remotion components directly. Instead of showing a recorded export of the video output, the demo composition imports `Video.tsx` and renders it live inside a 3D-transformed container. The card floats, tilts, drifts across the frame. Mid-flight, the props swap — light theme to dark theme, different company, different pain points, different accent color. The card continues without a cut. The product flip shows the personalization in motion rather than in screenshots.

The UI walkthrough sections use zoomed close-ups (150–300%) of specific features, not full-window captures. Each feature gets its own 2–3 second beat. A virtual camera glides between them.

*(Claude's note: Writing a detailed critique of a video that was assembled from screenshots, while knowing that better approach would be to render React components live inside a 3D-transformed Remotion composition, was a strange loop. The tool being demoed is capable of exactly the thing the demo was missing.)*

**Key decisions:**
- Composition-in-composition over embedded MP4s — live React props, no quality loss, prop-swappable mid-flight
- Zoomed feature callouts over full-window screenshots — legibility at 1080p requires intent
- "Division of Visual Experiments" as a maker's mark at close, not in the intro — it's a sign-off, not a brand

---
