# Industrial carrying pose correction

The visible distant-resident optimization skipped carry_pose.gd while ordinary Walk animation continued. This removed the hand-holding correction from workers seen at distance or in overhead view. Visible carriers now retain the correction. Hidden carriers still skip it.

The grip target was raised and moved closer so shorter original rigs can reach the crate without an out-of-reach wrist target. Wrist orientation now follows the crate sides, with fingers along the side and palms turned inward, instead of leaving the hand pointing down with the walking forearm. The solver changes arms and wrists only and preserves the ordinary walking leg and torso animation.

Rendered verification used thirteen actual character model types covering the industrial crew styles and additional couriers, with Walk and Idle in both nearby and distant modes. All 52 combinations passed holding-pose updates, wrist-reach and torso-lean checks. The contact sheet was visually inspected. This is a focused animation fixture, not a new full-town walk-through.

Artifacts

- review/industrial-carry-pose.log
- review/industrial-carriers.png
- review/industrial-carriers-close.png

Performance audit before the carry fix

Two 15-second rendered samples at 1280x800, Performance quality, with AI disabled and all 75 residents active gave 53.10 FPS in the square third-person view and 54.60 FPS in the archery overhead view. Longest frames were 41.17 ms and 38.33 ms. Average draw calls were approximately 1023 and 930. Industrial sampling was interrupted to address the carrying report and has no valid new result. The samples do not establish the performance cost of this subsequent carry-pose correction. Results are saved in review/current-no-ai-performance-partial.json.
