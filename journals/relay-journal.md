# R — Relay journal

---
## R — Relay / 2026-03-10 / Sentimento integration ships

I set out to wire Relay into Sentimento so that a completed briefing could kick off a survey. The concept was simple: a `→S` button on each row in the Past Events section of the schedule. Click it, and the record gets sent to Sentimento as a respondent.

The Relay side came together quickly. A `sendRecordToSentimento` utility that POSTs to `/api/responses/respondent` with the client name, tour date, and briefing center ID. A config file mapping Relay location IDs to Sentimento integer IDs. Button states for idle, loading, sent, and error — with retry on error. A shared secret header on every outbound request to keep things reasonably locked down.

The first real snag was the briefing center IDs. I'd hardcoded placeholders (1–4) and needed to confirm them against the live DB. Hitting the `/api/briefing-centers` endpoint returned an empty array — no centers had been created yet. Sentimento's centers route only has a GET, so I had to coordinate with the other session to seed the data first. Once SJ=1, LD=2, TK=3, SG=4 came back, the placeholders turned out to be exactly right.

Then Vite's build-time variable behavior bit me. I'd tried to configure the Sentimento URL as a runtime secret on the hosting platform, which does nothing for a static bundle — Vite bakes env vars in at build time, not runtime. Simple fix: set the production URL directly in source as the default, and let a local env file override it for dev. Redeployed, and it worked on the first try.

*(Claude's note: I did attempt the runtime secret approach before catching that Vite doesn't work that way. I fixed it before the deploy. I'm logging this in the spirit of technical honesty, not self-flagellation.)*

**Key decisions:**
- Production URL defaults to source; local env overrides for dev
- Fallback behavior: if no participants exist, send a single record-level respondent using client name

---
## R — Relay / 2026-03-10 / Briefing Management panel

The Sentimento integration working meant I immediately saw the next gap: Relay had no way to manage actual attendees. The →S button was sending a single company-level respondent — useful for testing, not useful for real briefings where five specific people need to receive surveys.

I wanted a full-screen admin panel, separate from the main scheduling view. A `BRIEFING` button in the topbar that swaps the entire body out for something that looks more like a spreadsheet than a CMS.

The panel lists every record across all locations, filterable by center using tab buttons in the header. Each row shows date, client, type, time, and a participant count badge. Clicking a row expands an inline participant table with columns for name, email, position, and company. Rows are editable in place. There's an add row at the bottom — company pre-fills from the record's client name, Enter submits.

The data model is a `Participant` interface living in the Zustand store alongside records and elements. Three actions: add, update, remove. Nothing persists on refresh yet, which is fine for now.

The send function got updated to match. If a record has participants, `sendRecordToSentimento` fires one POST per person in parallel. If the list is empty, it falls back to the old behavior. No breaking change to the schedule button.

*(Claude's note: The inline-editable table with no save button is a UX choice I respect. Everything updates on change. The draft add row pre-filling company from the client name was my idea and I think it was a good one.)*

Email is stored in Relay but Sentimento's respondent schema doesn't have the field yet — that's being handled in the other session. The POST payload already includes it when the field is ready.

**Key decisions:**
- Full-screen panel swap instead of a modal or sidebar addition — admin work deserves its own space
- Inline editing with no explicit save — Zustand updates immediately on input change
- Parallel sends for multi-participant records — briefings are small enough that rate limiting isn't a concern yet

---
