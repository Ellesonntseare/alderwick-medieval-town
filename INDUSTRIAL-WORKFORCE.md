# Industrial town workers and road traffic

The first group uses six existing adults, keeping their names, household membership, dialogue histories, voices, wallets and life-simulation progress. Population remains 53; the user permitted an increase but this first group does not require new residents.

| Resident | Industrial duty |
|---|---|
| Jory | Timber supplier |
| Kael | Tool carrier |
| Duncan | Warehouse courier |
| Finn | Workshop carpenter |
| Corvin | Goods clerk |
| Beren | Yard supplier |

Guard posts, market sellers, children and indoor shopkeepers are excluded from reassignment. Workers use distinct outdoor work stations just inside the industrial town's northern area. Two begin at work; four begin distributed along the road on outbound/returning journeys. Those are initial simulation positions, not repeated commuting teleports.

`industrial_workforce.gd` builds a separate collision-sampled corridor graph from the city's southern gate through the forest road into the industrial district. The city's older grid ends before that district. The new graph samples actual floor heights and player-sized clearance, rejects walls and abrupt ground edges, and replans blocked waypoints. Actual villager movement retains crowd steering and walking animations.

At work they animate their task, make visible crates and earn actual wages. Returning supplies are visibly carried and increment the city's supply stock only when goods actually reach the city. Work contributes to the existing life-simulation skills. Breaks are staggered. Nightfall sends distant workers back along the road before handing them to their normal family-home routing; their relatives do not walk out to meet them at a distant industrial workplace.

Tests are in `industrial-workforce-final-review.log` (collision capsules on the actual industrial/forest geometry, completed work and night returns) and `industrial-rigged-review.log` (actual character models and crowd steering). Script validation is `industrial-parse.log`. Check each final result before treating a run as passed.

The actual-model review passed with `failures=[]`: every worker travelled and completed a shift, eight work cycles completed, ten loads reached the city and all six commuters returned for handoff to the home system. This focused fixture includes the actual forest and industrial map, character rigs, carried goods and crowd steering; its city-home endpoint is a test substitute for the existing separately tested household system. It does not constitute a fresh complete 53-resident bedtime test.

Already-running standalone game processes do not automatically reload these scripts. Changes appear on the next launch. The user's existing live game is preserved.

Subsequent complete-town verification passed (`industrial-world-final-review.log`): all 49 off-duty residents, including all six industrial commuters, reached their actual family beds; four night guards remained on duty. The controlled test held night until journeys completed. It also reproduces and checks the corrected public-stool start connection that previously trapped Oren. Weather no longer resets a held night while the clock is paused.
