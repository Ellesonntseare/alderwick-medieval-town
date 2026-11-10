# Industrial-view pause investigation — 5 November 2026

## Captured cause

The 30-second industrial trace recorded an 896.181 ms longest frame. The life-state autosave occupied 763.140 ms on the scene thread in the same frame; its parent process callback occupied 763.176 ms. A second life save took 38.674 ms. The saved life JSON was approximately 32 KB. Events autosave reached 27.687 ms. Route searches were much smaller: city route maximum 11.629 ms, industrial route 4.290 ms. Nested trace timings overlap and must not be summed.

The machine was under substantially more memory pressure than earlier benchmarks: free physical memory fell below 1 GiB while loading. This can affect disk latency and frame time; the timing capture establishes the synchronous save call as the large blocking operation in this run, not a universal cause for every hitch.

## Fix

`background_json_save.gd` copies detached data on the scene thread, serializes and writes it on a low-priority worker, coalesces pending snapshots per path, and replaces the destination after a complete write. Automatic life and town-event timer saves use this background path. Explicit saves still return with the latest state on disk after draining older pending writes. Shutdown drains and joins the worker. Errors are recorded and reported; failed writes preserve the previous save.

Tracing is opt-in through `frame_costs.gd`; the industrial fixture enables it only with `--trace-stalls`. The normal game does not collect trace records.

## Focused verification

- `game/background-save-review.log`: gameplay frames continue while the disk worker is deliberately blocked; newest queued version wins; detached nested snapshots; explicit save ordering; multiple paths; real and injected failures; prior save preservation; recovery; shutdown flush/join.
- `game/life-save-integration-review.log`: actual life state, needs, skills, relationships, background snapshot isolation and explicit latest-save compatibility passed.
- Events save integration also passed in the owning chat's focused fixture.

Baseline artifacts: `industrial-stall-before.json`, `industrial-stall-before-performance.json`, `stall-capture-engine.log`. Post-fix rendered 30-second capture passed with all 30 workers and visible factories/props.

## Post-fix rendered result

| Metric | Before | After |
| --- | ---: | ---: |
| Worst life autosave scene-thread time | 763.140 ms | 0.634 ms |
| Worst town-event autosave scene-thread time | 27.687 ms | 0.090 ms |
| Longest rendered frame | 896.181 ms | 65.038 ms |
| p95 frame time | 43.294 ms | 33.498 ms |
| Average frame rate | 35.15 FPS | 43.03 FPS |

Both captures used the actual rendered industrial view with 75 residents, 30 industrial workers, factories loaded, 28 batched workbench/crate instances, and nine nearby prop batches. The 30-second post-fix run retained successful visibility checks. The after trace observed two life autosaves and eight event autosaves; no traced task exceeded 50 ms. Normal gameplay autosaves remain enabled.

These are short live-world samples, not deterministic matched frames. Available system memory changed across loading, so FPS changes cannot be attributed entirely to the save fix. The direct drop in scene-thread save cost establishes that the measured synchronous-save stall was removed in this capture. A longest frame of 65 ms still exceeds a 60 FPS frame budget.

Artifacts: `industrial-stall-after.json`, `industrial-stall-after-performance.json`, `stall-fixed-engine.log`, `stall-fixed-errors.log`.
