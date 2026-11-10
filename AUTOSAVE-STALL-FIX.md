# Resident autosave stall

The first timed 30-second factory-yard capture found a 763.140 ms synchronous
`character_life.save_state` call inside a frame lasting 896.181 ms. The same
capture measured route-search maxima below 12 ms and industrial-route maxima
below 5 ms. The resident save was approximately 32 KB; write latency, rather
than a large save payload, dominated that measured pause. The source trace is
`industrial-stall-trace.json` from the initial capture; retain the before/after
copies made by the performance chat when comparing later runs.

`game/background_json_save.gd` now handles the periodic resident-life and
town-event autosaves. The scene thread takes a deep snapshot of plain data;
a low-priority worker serializes JSON and writes a temporary file, replacing
the destination only after the write succeeds. Repeated queued snapshots for
the same path coalesce to the most recent snapshot. Writes are serial within
each owner. No scene node or live mutable state is accessed by the worker.

Explicit `save_state()` calls retain synchronous behavior for existing actions
and checks. They first wait for older background jobs, then write the latest
state, so an old queued autosave cannot overwrite a newer explicit save.
Normal scene exit drains queued work and joins the worker thread. Errors are
recorded and reported on the scene thread; a failed write retains the previous
destination. Life autosaves use background mode every 15 seconds, and the
four-second town-event timer uses it too. NPC schedules and movement are
unchanged by this patch.

Focused verification passed:

- `game/background-save-review.log`: game frames continue while a deliberately
  blocked worker waits; newest queued state wins; nested snapshots remain
  detached; explicit saves override older work; multiple paths save correctly;
  simulated and real path failures are detected; prior saved data survives;
  recovery succeeds; shutdown drains the last snapshot and joins the thread.
- `game/life-save-integration-review.log`: existing needs, cooking, skills,
  relationships and explicit persistence checks pass. New checks verify a life
  autosave retains energy 41 after the live state changes to 99, and an explicit
  save then persists 99.
- `game/events-save-review.log`: event records and knowledge retain the queued
  snapshot, explicit saves are immediately readable, and scene exit persists
  the last queued event.

The full rendered after-change capture is owned by the performance chat.
Do not claim the long pause is eliminated until that result is available.
Available system RAM differed between captures, so FPS alone does not isolate
the benefit of this save change.
