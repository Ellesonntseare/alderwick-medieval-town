# Measurement limitation

The industrial_30_overhead result (38.12 FPS) in loaded-map-performance.json was taken with the factory buildings loaded, but before correcting the origin of fixed workbench MultiMesh batches. Some workbench batches were culled at the wrong distance. Treat this as a pre-correction measurement, not a final fully visible industrial result. A new props-visible industrial verification is required. Other view results describe that same prior runtime source and have not been remeasured after the batch-origin correction.

## Superseding industrial measurement

The final industrial-visible run includes factories, 30 workers, 28 batched workbench/crate mesh instances and nine nearby batches; all visibility checks passed. Five-second warmup, ten-second sample: 32.15 FPS; p95 49.159 ms; longest frame 847.129 ms; mean reported physics 28.303 ms; mean draws 1117.88. See industrial-visible-performance.json and industrial-30-workers-final.png. This supersedes 38.12 FPS for the industrial area. Other view rows above are measurements from the earlier run, before the final batch-origin correction.
