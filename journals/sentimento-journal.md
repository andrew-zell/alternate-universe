# S — Sentimento

Post-briefing survey tool. Reads respondents pushed from Relay, generates survey links, tracks status through the briefing lifecycle. Built on Express + Prisma + SQLite, deployed to Fly.io.

---

## S — Sentimento / 2026-03-11 / nav structure

The nav was wrong. Surveys was filed under Analytics, which made no sense. I wanted to fix that and ended up doing a proper reorganization while I was in there.

Three groups now: Insights (Dashboard, Responses, Analytics), Briefings (Intake, History), Content (Surveys, Questionnaires). Admin is still Admin. The old two-group layout — Analytics up top, everything else in Management — was a placeholder that never got revisited. Now that the app has a real shape, the groups needed to reflect it.

Renamed "Briefings" to "Intake" and "Roster" to "History" at the same time. Those two label changes made the intent of each page clearer. Intake is where respondents arrive. History is where you go to look back.

---

## S — Sentimento / 2026-03-11 / Locations page

Briefing centers and tour types were seed-script-only. If you wanted to add a new center, you edited `seed.ts` and ran it against the database. That was fine for setup but not sustainable once the app is in regular use.

Built an admin-only Locations page with two sections — one for briefing centers, one for tour types. Inline editing: rows are read-only by default, hover reveals edit and delete, a small `+` link at the bottom opens a new editable row. No modal, no separate form page. The backend got full CRUD routes on both `/api/briefing-centers` and `/api/tour-types`, gated to admin role.

*(Claude's note: "inline editing" sounds elegant in retrospect. There were approximately four intermediate states — showAdd, editingId, pending, error — that all needed to coexist gracefully. It worked out.)*

---

## S — Sentimento / 2026-03-11 / animation flicker root cause

Pages with multiple cards had a visible jitter on load — a position shift followed by what looked like a separate opacity fade. It felt like two animations running in sequence rather than one.

It was two animations running in sequence. `animate-fade-in` was defined twice: once in `tailwind.config.js` as a pure opacity fade, and once in `index.css` as a combined opacity + translateY. The CSS file version won the cascade, so that wasn't the core problem. The core problem was `AdminLayout`'s content wrapper also had `animate-fade-in` on it — so the whole page container was animating, and then each page's own root `div` animated on top of that. First pass: position shift from the layout wrapper. Second pass: opacity fade from the page component. That's exactly what it looked like.

The secondary issue was `animation-fill-mode`. Several pages applied `animate-fade-in` and `animate-slide-up` with inline `animationDelay` but no `backwards` fill mode. Without it, elements start at their default state (fully visible) during the delay, then snap to `opacity: 0` when the animation fires. It looks like a flash.

Fixed by removing `animate-fade-in` from the `AdminLayout` wrapper entirely — pages own their own entrance. Added `animation-fill-mode: backwards` to both animation class definitions so delayed elements stay hidden until their animation actually starts.

*(Claude's note: `animation-fill-mode: backwards` is one of those properties that sounds obvious, means something specific, and is almost never included by default. We have now learned this together. It is in the CSS. It will stay in the CSS.)*

---
