# Château map additions

Both scans are by **Archéomatique**, supplied under **CC BY-NC 4.0** according to the embedded GLB metadata. Keep these attributions and the noncommercial restriction with distributed derivatives.

- Château de Fère en Tardenois (02): https://sketchfab.com/3d-models/chateau-de-fere-en-tardenois-02-4fd189d7fd2c45a185a0c4d08facc656
- Château de Montfaucon (25): https://sketchfab.com/3d-models/chateau-de-montfaucon-25-fcd390105b554e2697cb4024ef190d78

Original downloads remain unchanged, with preservation copies in `source-assets/chateaux`. `tools/prepare_chateaux.py` produces the runtime derivatives: reduced mesh detail, adult-sized entrance clearance, normalized scale and ground level, and softened terrain boundaries. Runtime materials retain the photographic textures through a simple lit shader. Shared-ground cutouts preserve the Fère moat; exterior edge gaps receive ground backing.

Fère is approximately 144 × 137 metres at (245, 0, 70); Montfaucon is approximately 92 × 39 metres at (265, 0, -90). Both are connected player exploration sites, with real scanned courtyards and passages. These assets are ruins, without complete furnished interior rooms. Residents have not been assigned new routines in these districts.

`chateaux-access-review.log` records successful entrance routes and actual player movement into both sites. `chateaux-integration-review.log` confirms 49 locations, 45 residents, and both Visit menu destinations. Native visual captures are `town-fere_chateau.png` and `town-montfaucon_chateau.png`.
