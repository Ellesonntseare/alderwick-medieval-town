# Life, needs and skills

Open **Life, needs & skills** in the collapsible menu, or press **L** while
exploring. The panel pauses your movement while you choose an action. Close it
to return to the town. The **Needs & moods** menu option disables need-driven
behaviour without removing cooking, skills or relationships.

## Needs and personalities

The player and all 53 residents have food, energy, cleanliness, comfort, fun and
social needs. Higher bars mean the need is satisfied. Food requires inventory;
sleep and seated breaks restore energy; washing at the town well restores
cleanliness. Conversations and shared meals improve social contact and fun.
There is no death or health punishment from low meters in this version.

Off-duty outdoor residents can seek a seat, wash at the well, or go to their
assigned home for a nap when exhausted. Guards keep their assigned shifts;
children do not acquire adult jobs or tavern drinking routines. Existing nightly
household and weather routines remain in charge of the corresponding trips.

Stable personalities affect sociability, cautious walking, industrious work,
and the context supplied to generated dialogue. Moods reflect needs and actual
recent activities. Dialogue receives the person's own feelings, skills and
relationship, rather than omniscient information about everyone in town.

## Skills

Cooking, Farming, Carpentry, Smithing, Trading and Archery range from level 0 to
10. Real activities grant practice: cooking, growing and harvesting, completed
deliveries and crafted work. An experienced, trusted resident can give a short
nearby lesson through the People tab. A lesson has a duration and releases the
teacher afterward. Skills improve crafting/harvest task speed, crop growth or
yield, and access to more advanced recipes.

## Relationships and reputation

The People tab lists the actual residents. Give food from carried inventory,
ask for a lesson, invite a friend home, argue or apologize. Conversation,
gifts and deeds update the existing mission relationship store; there is no
second competing trust ledger. Daily conversation/apology limits prevent rapid
repetition from creating unlimited trust. Arguments reduce trust and become
news only for involved residents or actual nearby witnesses.

Trusted market sellers charge 1 coin rather than 2 for a player food portion;
badly damaged relationships can raise that price to 3. NPC transactions retain
their normal market price. Purchases still move real coins and consume stock.

Romantic interest is an explicit interaction between uncommitted adults who
have built trust. Existing committed households are respected. Children and
the two child player appearances have friendship interactions only. This first
version supports mutual interest; weddings, pregnancy and ageing are outside
the selected scope.

## Cooking, garden and inventory

Cook at the Copper Stag's outdoor pot, or at the real kitchen counter in your
selected home. Stand nearby and use the Cooking & garden tab. Preparation takes
time; ingredients are checked again and consumed only on completion. Cancelled
preparation cannot create food. Cooked meals, herbs and mission belongings use
the same carried inventory. Vegetables continue using the existing food count.

| Recipe | Vegetables | Herbs | Cooking level | Servings |
| --- | ---: | ---: | ---: | ---: |
| Roasted vegetables | 1 | 0 | 0 | 1 |
| Vegetable stew | 2 | 0 | 0 | 2 |
| Garden broth | 1 | 1 | 1 | 1 |
| Family stew | 3 | 1 | 2 | 4 |

The community garden is near the southern farm at approximately **(-29, 38)**.
Planting costs a real vegetable portion. The crop must grow before harvest and
can be collected once per planting. Herbs regrow slowly. Harvesting supplies
food and gives farming practice.

## Home and households

The supplied potter's house and chosen spacious interior remain the player's
home and starting place. Cooking uses that interior's kitchen anchor; storage,
furniture and the bed use the home system. See **PLAYER-HOME.md** for entry/exit.

Adult friends can be invited through the People tab. They must physically reach
the exterior porch before the home system transfers them inside. Up to two
visitors may be admitted. They use a free sofa seat, stay briefly, then return
outside and resume their routines. On-duty guards remain at their posts.

Existing families meet, travel home together, share available packed food and
spend breaks together. Shared time improves mutual resident friendships and
moods. The new system preserves the 53 residents' permanent family beds.

## Saves and validation

Needs, personalities, skills, moods' underlying state and resident friendships
are saved in `user://character-life.json`. Cooking/garden timing is in
`user://town-cooking.json`. Existing adventure and economy saves remain the
owners of carried items, trust, coins and food. Gameplay review flags use
separate test data.

Validation: `character-life-review.log` exercises real resource transactions,
cancel/completion, crop growth, learning, relationship consequences, age rules,
washing and saving. `character-life-world-review.log` passed all 53 residents,
actual home cooking and visits, stock/currency conservation and grounded
movement. These establish a first functional version; longer play sessions may
still call for tuning need speeds, invitations and progression.
