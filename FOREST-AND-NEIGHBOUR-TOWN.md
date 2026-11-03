# Woods and the connected southern town

The downloaded `a_forest_3_with_a_road_at_night_for_game.glb` supplies the woodland
terrain, trees and understory. The original download is preserved. Its derived
runtime patch is repeated around the city, western district and castles.

- The full world contains 28 patches and 2,324 trunk colliders. Patches that
  would overlap the two photographed chateaux are skipped.
- The ground is limited to gentle rises and blends into the shared earth at
  its edges. Canopy and understory use transparency; their leaf panels do not
  form invisible collision walls.
- Only trunks and the real terrain obstruct the player. A native test walked
  the actual player 37.76 metres through a woodland patch successfully.
- Small understory has a shorter rendering distance; canopy remains visible
  farther away and in overhead views.

The source map `chicken_shoot_gun_-_industrial_map.glb` from the Desktop is the
southern neighbouring town. Its supplied industrial architecture is retained.
It connects to the medieval city's south gate by a continuous six-metre-wide
road, with signs and an opening cut through the map's original boundary fence.
The same earth continues underneath and beyond the new district.

The footprint is about **379 × 338 metres**, centred around `(0, 410)` in the
world's horizontal coordinates. The main map uses a 0.85 source scale so the
warehouse personnel doors have roughly 2.24m clearance. One separately authored
hideout house used different units; its entire assembly is scaled separately
so its human door is about **1.18m wide × 2.244m high**, including matching
furniture. The oversized table is 0.82m high and large decorative barrels have
been brought down to 1m. Source downloads are unchanged.

All ten separate supplied door leaves use the game's opening-door interaction.
Use **E** near a door. Walk south from the city gate, or choose **Industrial
town — north gate** from the Visit a place menu. **Forest trail** takes you to
the woodland walk near the southern road. The town menu now scrolls so its
expanded set of controls stays reachable on a smaller window, and **H** still
collapses it.

The new town is presently an explorable district. The existing 53 residents
continue their established city, western and castle routines; a new resident
population and businesses for the industrial town have not been invented.

Evidence: `world-districts-review.log` passed the complete road and boundary
opening, ten opening doors and full cast preservation. `forest-walk-review.log`
passed actual player traversal; `neighbour-scale-review.log` covers the final
door-scale audit and expanded menu. `connected-towns-preview.png` and
`neighbouring-town-preview.png` show the layout; the final hideout assembly was
adjusted after those overview captures.
