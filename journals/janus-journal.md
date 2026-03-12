# J — Janus journal

---
## J — Janus / 2026-03-12 / First full build

I came into this session with a 952-line architecture spec and a clear sense of what problem it was solving. Zoom runs executive briefing centers. Coordinating those briefings is currently a mess of spreadsheets and email chains. Janus is the system that fixes that: intake from Salesforce opportunity data, a request-and-approval workflow, agenda building, and a handoff to Relay when the briefing is ready to run.

Before writing a line of code, I spent time with the companion apps — Relay and Sentimento — to understand what patterns were already established. The stack decision was quick: same monorepo shape as Sentimento, React/Vite client and Express/TypeScript server, Prisma over SQLite for dev. SFDC integration got deferred immediately. The goal is a proof of concept the broader team can react to, not a live Salesforce connection. So the intake layer became synthetic data — ten accounts seeded with real Zoom product families and opportunity types pulled from the int-wheel catalog.

The schema has twelve models. The ones that matter most: `BriefingRequest` and `Briefing`, which are distinct on purpose. A request is a proposal with a state machine. A briefing only exists once a request is approved — it's the execution record. The `ExecutionPackage` and `RelaySync` models handle the Janus-to-Relay handoff: a reduced JSON payload with only what Relay needs to run the room. Auth followed Sentimento's pattern: JWT with bcrypt, three roles (admin, coordinator, viewer). The whole API surface got built in a single session.

Evangelists came next. The briefing center staff who host sessions have a specific role — they're tour guides, not subject matter experts. So there's now an `Evangelist` model with specialty tags, bio, home EBC location, and an active/inactive flag. Five got seeded across San Jose, London, Tokyo, and Singapore. The Speaker Bench page lists them with specialty pills and bios, and a `Briefing` can have a lead evangelist assigned.

The routing fix was quick: the agenda route file had routes defined without a prefix, so `POST /api/agendas/:id/sessions` never matched. Five routes fixed. The dashboard replaced a redirect-to-queue placeholder with real content: stat cards, upcoming briefings, approval queue snapshot, relay health alerts, activity feed. User management and a self-serve profile page landed at the same time.

The design direction took about thirty seconds: stone and cement, Darker Grotesque, headings bold, nothing too rigid. Uppercase labels, no bright accents.

*(Claude's note: Seeding ten distinct Zoom accounts with authentic sales motion data — specific opportunity amounts, plausible contact hierarchies, real product families — was genuinely more interesting than seeding lorem ipsum users. Palo Alto Networks expanding from Meetings to full Zoom Workplace is a real story. I am also personally partial to the name "Speaker Bench.")*

**Key decisions:**
- Separate `BriefingRequest` and `Briefing` models — request is a proposal, briefing is execution; conflating them would lose the audit trail
- Evangelist distinct from Participant — the conceptual line is "host" versus "attendee"
- `ExecutionPackage` as a reduced, revisioned JSON payload — Relay gets only what it needs; Janus keeps the full record

---
## J — Janus / 2026-03-12 / Hardening, workflow clarity, and a crash that hid behind the wrong error

Second session same day, and the theme was correcting first-pass assumptions.

The intake page had been built as a form — the coordinator was expected to fill in requested dates, location, briefing type, objectives — when the whole premise of intake is that this data comes from Salesforce already. The AE submits a request through SFDC with all of that attached to the opportunity. The coordinator's job is to review it, not re-enter it. So the "Request from Salesforce" card got rebuilt as a pure read-only display. The coordinator has one editable area: a notes field at the bottom that travels with the request to the approval queue. The seed was also walling off stale data — every synthetic data upsert had `update: {}`, silently no-oping on fields added after the first run. Fixed by wiping synthetic tables before re-seeding.

Intake also got triage actions. Previously the only move was "submit to approval queue." Now there are three: Hold, Reject, Submit. Hold and Reject both require a message that gets flagged for relay back to the AE. The left column of the intake page became three sections: New, On Hold, Rejected. The approval queue only ever sees submitted requests.

The `under_review` request status got removed entirely. It had been an intermediate step triggered by a "Begin Review" button in the approval queue — the idea being that a coordinator would explicitly claim a request before acting on it. But if something is in the approval queue, it is by definition under review. The status communicated nothing, added a click, and created a filter tab nobody needed. Gone. Submitted goes directly to approved or rejected.

Nav got restructured around actual workflow logic: Dashboard alone at the top, then a WORKFLOW section (Intake, Approval Queue, Planning), then ADMIN (Speaker Bench, User Management). The briefings page was renamed Planning — the old name was confusing because everything in the system is a briefing.

Then the debugging session. The server had been crashing on first request and the surface symptom was port conflicts — multiple `npm run dev` processes had stacked up, EADDRINUSE errors were loud. But killing the zombie processes and restarting didn't fix it. The actual fault was a Prisma validation error in `intake.ts`: a `sourceOpportunityId: { not: null }` filter on a non-nullable field. Prisma refuses that. It threw on every intake search request, killed the `tsx` process, took the server down. The port noise was a red herring.

The Speaker Bench had a related bug. Deactivating an evangelist made the card vanish entirely. An optimistic update had been added to patch the React Query cache immediately — correct in theory — but the post-mutation `invalidateQueries` re-fetch was the problem. The server's evangelists route defaulted to active-only when no filter was passed, so the re-fetch simply didn't include the newly inactive evangelist. Fixed the route (no filter = all evangelists), fixed the Speaker Bench query to pass no filter, fixed the seed to include `isActive: true` in the upsert update block so re-seeding restores any cards deactivated during testing.

*(Claude's note: The server crash was one of those bugs where the real error and the visible error are completely different things. EADDRINUSE felt urgent and looked causal. It was neither. I'll admit I chased the port issue longer than I should have before reading the full crash log.)*

**Key decisions:**
- Intake is read-only for SFDC data — the coordinator is a reviewer, not a data entry clerk
- Hold and Reject at intake, not the approval queue — triage before the request reaches the queue
- `under_review` removed — a status that doesn't communicate anything to anyone shouldn't exist
- No filter = return all on the evangelists route — requiring an explicit flag to get all records is backwards
- Seed should restore operational state — `update: {}` is fine for static fields, but `isActive` should reset on every seed run

---
