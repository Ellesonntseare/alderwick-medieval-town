# New wildlife credits and preparation

The metadata below is embedded in the user-supplied downloads. Originals remain unchanged in Downloads and preservation copies are in source-assets/new-wildlife.

## Cow Idle

- File: cow_idle.glb
- Author: kenchoo (https://sketchfab.com/kenchoo)
- License: CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
- Source: https://sketchfab.com/3d-models/cow-idle-16493ce34a4f41a6ba7b7d31032317c1

## Horse basemesh

- File: horse_basemesh.glb
- Author: sidahearne (https://sketchfab.com/sidahearne)
- License: CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
- Source: https://sketchfab.com/3d-models/horse-basemesh-0ef074acfc834c769a6ec37d6a4be1b9

## Sheep-Test (Non-Commercial)

- File: sheep-test_non-commercial.glb
- Author: Nyilonelycompany (https://sketchfab.com/Nyilonelycompany)
- License: CC-BY-NC-4.0 (http://creativecommons.org/licenses/by-nc/4.0/)
- Source: https://sketchfab.com/3d-models/sheep-test-non-commercial-196bb78e6e6343888d09f468a6a9dbc7

## Sheep

- File: sheep.glb
- Author: kenchoo (https://sketchfab.com/kenchoo)
- License: CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
- Source: https://sketchfab.com/3d-models/sheep-08b05ae799d947f1a68c49b2d661eb53

## Birds

- File: birds.glb
- Author: Zacxophone (https://sketchfab.com/Zacxophone)
- License: SKETCHFAB Standard (https://sketchfab.com/licenses)
- Source: https://sketchfab.com/3d-models/birds-3a9bb97be78944f9bffc23fb25c2154e

## Model 110A - Imperial Woodpecker Flying

- File: model_110a_-_imperial_woodpecker_flying.glb
- Author: DigitalLife3D (https://sketchfab.com/DigitalLife3D)
- License: CC-BY-NC-4.0 (http://creativecommons.org/licenses/by-nc/4.0/)
- Source: https://sketchfab.com/3d-models/model-110a-imperial-woodpecker-flying-63e44e9ae8b644f7a240ca57b25d4179

The noncommercial sheep is not spawned. A proven existing sheep model/rig replaces it at 0.82 m; the other downloaded sheep, cow and horse are used. The prepared ground animals have Idle and Walk clips. The previously unrigged horse received a four-leg deformation rig. Existing Quaternius animal credits remain in the original asset credits.

Preparation: tools/prepare_new_wildlife.py inspects/exports previews and preserves originals; tools/animate_new_farm_animals.py creates the in-place gaits; tools/finalize_wildlife_glbs.py removes incompatible morph tracks from the ground-animal derivatives. Birds retain their original valid skeletal and morph flight tracks. Failed sheep rig experiments are reference work, not the runtime spawn.

Native animal bounds/movement and source-rig replacement are checked by game/wildlife_review.gd. All13groundanimals/pasture containment and5skygroup routes passed the complete-town review.