# Visible resident activities

`game/resident_actions.gd` is attached by `TownRoutines._ready()`. No new
`town.gd` attachment is needed. It uses the existing resident bodies, routes,
routine cancellation, work, skills, dialogue memories and night schedule.

- Bakers show a small supported work table and loaves. Each completed eight
  seconds of work adds one real food portion, up to four. Consuming food removes
  a displayed loaf on the next work tick; further work can replace it.
- Smiths show a hand-mounted hammer and up to four repaired metal tools resting
  on a supported table. Each completed repair records a memory and Smithing XP.
- Existing carpentry production still owns its stools, wages and delivery
  behavior. A hand-mounted tool appears during its crafting timer.
- Between shifts, eligible outdoor adults can fetch water, sweep, put out animal
  feed, or practise at the range. Chores last six seconds after walking there,
  and begin on staggered name-based schedules rather than all together.
- Ten residents attend the archery school using `DrawArrow` and
  `AimOverdraw` while facing their own targets. Temporary hand-tracked bows
  show staggered shots along the range, and are removed after practice. Guards can
  occasionally examine their equipment while remaining at their posts.
- Farmers use `DigPlant` periodically at the field and `PullPlant` during
  harvest. The harvest clip fits the resident's existing work timer. A brief
  interruption resumes the clip at the same point in the task. Residents
  walking with a loaded crate use their normal `Walk`, and upright `Idle` when waiting.
  Hand constraints keep their hands on the real crate without freezing their legs. Equipped left-shield guards use `ShieldIdle`
  and occasionally `Examine` or a brief shield block drill at their posts. Standing residents
  use `WaveGesture` when greeted, and children can dance during play.
- Elsa uses the corrected archer model and keeps her western watch assignment.
  Her wooden shield attaches to her left forearm and turns upright during
  the block, then returns to its carrying angle.
- No more than four ordinary chore stations can be reserved at once, alongside
  ten separate archery lanes. The ordinary path
  planner must reach the station; it never teleports a resident to an errand.
- Guards, sellers, children, indoor workers, loaded couriers and industrial
  workers keep their existing assignments. Night or dialogue interrupts chores
  and removes their tools and reservations without granting a result.
- Seated direct conversations preserve the resident's chair, meal or visit.
  They use `SitPoint` when beginning a spoken reply and return to `SitIdle`
  afterward. Their meal or visit timer resumes after the conversation closes.
- `villager.gd` no longer changes every imported clip into a loop. Explicit
  locomotion/daily idle loops remain, and library one-shot policies survive.

Tests: `resident_actions_review.gd` uses real resident rigs in a small
fixture. It checks duty exclusions, unreachable routes, cancellation, hand-bone
attachments, bounded goods, food/display synchronization, water and animal
results, skill gains, night handoff, seated clip selection, one-shot policy,
farm planting and equipped shield drills. The shared rig audit passed 24
clips on 22 models in `all-action-rigs-grounded.log`.
`resident-actions-review.log` and `resident-actions-native.log` report no
failures. `resident-actions-life-regression.log` checks existing needs, cooking,
relationships and home visits. The native fixture produces preview PNGs and
exits itself; it does not start the full town.

Limits: the water count is a capped communal stock, not a full water economy.
Animal feeding records care on the actual animal; it does not invent an eating
animation or add animal hunger. Smith output is a bounded display and skill
result, not a new trade item. Existing meal/tavern behavior is retained. A full
town visual walkthrough is still needed to judge added tables against each
building's furniture. Shield drills run only on the left-shield guard rigs
that match the imported stance.
