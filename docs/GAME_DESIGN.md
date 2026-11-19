# Game Design Sheet — Working Concept

**Version:** 0.1
**Status:** Early concept / three-floor prototype
**Genre:** 2D survival dungeon crawler
**Tone:** Gloomy but adventurous
**Design priority:** Fun, readable physics-driven combat

## High Concept

A prisoner escapes down through a vast, decaying fortress in the middle of sealed dead lands. The fortress is occupied by monsters and other hostile creatures. The player must descend through its floors, find keys, survive encounters, and reach friendly territory.

The player was lured into the sealed lands after their family was taken. The immediate goal is escape. Rescuing the family is a possible story for a later game or post-escape chapter.

## Setting and Story

The fortress was built by a once-great empire. Its halls, machinery, and architecture still hint at its former grandeur, but the structure has been abandoned and overtaken by hostile creatures.

The visual direction is dark, immense, and oppressive, balanced by the adventure of exploring a mysterious place and finding ways to survive.

**Originality note:** Build a distinct fortress, history, creatures, symbols, and visual identity. Use broad inspiration such as imposing architecture and a fallen empire, rather than copying recognizable elements from existing fantasy works.

## Core Player Experience

The player studies a room, chooses whether to sneak, distract, or engage, and uses weapons and the environment to gain an advantage. Combat begins deliberately and becomes fast and evasive once enemies close in.

**Core question:**
*Do I take a risk to get through this room or find useful loot, or conserve my health and continue toward the exit?*

## Core Gameplay Loop

1. Enter a floor.
2. Explore connected rooms.
3. Find enemies, hazards, supplies, and keys.
4. Choose whether to sneak, distract, fight, or use the environment.
5. Find the main key and unlock the exit.
6. Optionally use other keys to open helpful rooms.
7. Choose a floor reward and descend.

A floor should have a clear route forward, while optional rooms reward players who accept additional risk.

## Run Structure

The full game has a limited number of floors. A boss appears every third floor.

**Initial prototype:** Three floors, ending with the first boss. This tests the main loop without requiring a large amount of content.

### Prototype Floor 1 — The Prison

**Purpose:** Teach movement, stealth, basic combat, and keys.

- A ruined prison wing where the player begins with limited equipment.
- One main key unlocks the route to Floor 2.
- An optional key opens a supply room with healing food or a distraction item.
- Introduce a basic enemy patrol and an opportunity to sneak, distract, or fight.
- Teach that enemies can be pushed or knocked from a ledge.

### Prototype Floor 2 — The Cistern

**Purpose:** Introduce environmental hazards and noise.

- An old waterworks with flooded chambers, narrow walkways, and abandoned machinery.
- One main key unlocks the route to Floor 3.
- An optional key opens a useful room, such as a refuge or equipment cache.
- Introduce water as a combat opportunity: enemies can be pushed or lured into deep water.
- Loud actions may attract a nearby patrol. The consequence should be understandable and limited.

### Prototype Floor 3 — The Foundry

**Purpose:** Combine the learned mechanics and deliver the first major milestone.

- A vast, abandoned imperial foundry.
- The player searches for the main key while navigating enemies and machinery.
- An optional key opens a cache that may help with the boss.
- A boss guards the descent.
- The arena offers environmental opportunities, but no particular weapon or trick is required to win.
- After the boss, the player chooses a significant reward.

## Keys and Rooms

- Each floor has one clearly identifiable **main key** that opens the exit.
- Some floors have additional **optional keys**.
- Optional keys open rooms with useful items, shortcuts, supplies, clues, or other advantages.
- Players should be able to understand the likely value of an optional room before choosing whether to search for its key.
- Avoid making every floor a long checklist: the main key is the objective; optional rooms are a risk-and-reward choice.

## Combat and Stealth

**Combat feel:** Deliberate and weighty before engagement; fast and evasive when enemies pursue the player.

**Approaches available to the player:**

- Fight directly with available weapons.
- Sneak around enemies where possible.
- Throw a rock to distract or reposition an enemy.
- Use the room's hazards and objects to create an advantage.
- Retreat or reposition when a fight turns dangerous.

Physics combat is the defining feature. Environmental interactions should be predictable enough to plan around, while allowing satisfying chain reactions.

### Candidate Physics Interactions

- Knock enemies from ledges or ladders.
- Push or lure enemies into deep water and drown them, where appropriate.
- Set selected parts of the environment on fire.
- Throw rocks to distract enemies.
- Use arrows or another suitable weapon to pin enemies to walls.
- Trigger machinery or move objects to block, stagger, or harm enemies.

These are candidate mechanics, not all requirements for the first prototype.

## Survival and Equipment

### Health and Food

- Food is not a constantly draining survival meter.
- Food is a scarce, useful resource that heals the player immediately.
- Using food now means having less available for later.

### Noise

- Loud actions—such as certain attacks, breaking objects, or triggering machinery—can attract enemies.
- Noise creates a readable risk, such as a nearby enemy investigating or a patrol changing its route.
- Avoid using noise as an excuse for endless enemy spawns.

### Equipment Wear

- Only selected powerful equipment wears down.
- The basic weapon should remain dependable so the player cannot become helpless because all their gear broke.
- Wear should make powerful equipment feel valuable without making ordinary play frustrating.

## Progression and Currencies

There are two separate currencies with different purposes.

### Run Currency — Temporary

- Earned relatively quickly during a run, including through combat and possibly exploration.
- Spent during that run on temporary abilities, upgrades, or other run-specific improvements.
- Lost when the run ends or the player dies.
- Gives the player short-term build choices and rewards progress within the current attempt.

### Legacy Currency — Permanent

- Earned more slowly and persists between runs.
- Used to unlock weapons the player has discovered and make them available as starter choices.
- Can also unlock selected permanent options or abilities, subject to balance.
- The player may spend it to bring an unlocked starter weapon into a new run.

**Progression principle:** Keep the strongest build improvements temporary. Permanent progression should expand choices, not make future runs automatic wins.

**Fairness consideration:** Do not make fighting every enemy the only way to gain long-term progress. Reaching floors, discovering rooms, or other accomplishments can also contribute.

## Death and Run Stakes

Death is high stakes.

**Lost on death:**

- Current run's weapons and carried supplies.
- Temporary upgrades and run currency.
- Current floor and run progress.

**Kept between runs:**

- Legacy currency.
- Weapons already unlocked for future starter choices.
- Any other explicitly permanent unlocks.

The player should understand what is lost and what persists before beginning a run.

## Floor Rewards

Every cleared floor provides a meaningful reward choice. The exact reward system remains to be designed.

Possible reward categories:

- A new combat or movement capability.
- An upgrade to an existing weapon or ability.
- A survival benefit, such as improved healing or equipment maintenance.
- A specialized option that supports a particular play style.

Rewards should encourage different approaches without making one option mandatory.

## Scope for the First Prototype

Prioritize testing whether physics combat and the floor loop are fun.

**Prototype includes:**

- Three floors: Prison, Cistern, Foundry.
- One main key per floor and a small number of optional keys.
- A small set of enemy types.
- One reliable basic weapon and one special weapon.
- Basic stealth and noise attraction.
- Two or three physics interactions.
- One boss.
- One post-boss reward choice.
- Temporary run currency and persistent legacy currency, initially in simple form.

**Defer until the core loop works:**

- A large ability tree.
- Many weapon types and complex durability rules.
- A large number of floors or bosses.
- Numerous environmental hazards and advanced physics interactions.
- The family-rescue story continuation.

## Open Design Questions

1. How many total floors should the completed game have?
2. Which two or three physics interactions should be in the first playable prototype?
3. What determines how much legacy currency a run earns?
4. Are temporary abilities purchased during a run, selected at level-up, or awarded as floor rewards?
5. How does the player learn what a key's optional room contains?
6. What are the basic weapon and special weapon for the prototype?
7. How does the player identify the floor exit and main key?
8. What makes the first boss distinct from ordinary enemies?

---

## Decisions

- **Engine:** Godot 4.7.
- **Viewpoint:** Top-down. "Ledges" are pits and chasms. Ladders are dropped.
- **Weapon select:** the loadout is chosen on a select screen at the start and locked in for the run.
- **Crouch:** crouching is slow, and hides you from guards behind low cover (crates, barricades). Standing, guards see over low cover. Tall walls always block sight.
- **Light and shadow:** visibility depends on torchlight at the player's position, with walls casting shadows. Torches and braziers can be doused with a bolt or rock (a noise that draws a guard to relight it).
- **Gaoler charge rule:** it never charges across a pit, water, a wall or a half wall at you. A pit *behind* you is fair game: sidestep and it overshoots.
- **Loadouts:** Each loadout pairs one lethal weapon with one non-lethal physics tool:
  - **Crossbow + Shove:** lethal at range, physics push up close.
  - **Blade + Stun Rock:** lethal up close, physics hit at range (stun, knockback and noise).
- **First milestone:** M0 combat sandbox (built; see README).
- **Non-lethal tools use charges.** The kick and the stun rock start with 1 charge that refills on a cooldown. More charges are an upgrade (a floor reward or a legacy unlock), not something combined across loadouts.
- **Ammo is limited and retrievable.** Bolts and rocks land on the floor and can be picked up again. Anything that falls into a pit or water is lost, and some bolts snap on stone. Crates can hold spare ammo.
- **The player can fall.** Only when thrown by a hit (never by walking), and it costs health (pit 2, water 1) rather than killing outright. You're placed back on the last safe ground.
- **Guards:** a suspicion meter fills before an alert. An alerted guard shouts, bringing nearby guards running; silencing it mid-shout prevents the alarm. After an alert, guards stay wary. Wind-ups are sometimes held longer as a feint.
- **Environment:** crumbling pit rims, and breakable crates that crush guards, block sight, and make noise when broken.
- **Feel:** a short hit stop on heavy hits, and brief slow motion on hazard kills.

## Enemy Ideas (menu to prototype from)

Each idea has a different relationship with the physics, so each one tests something new. Names are working titles.

| Enemy | What it does | Physics hook | How you beat it | Fits |
|---|---|---|---|---|
| **Gaoler** (brute) | Big, slow, hits hard. Shoulder-charges in a straight line. | Too heavy to kick until staggered. A wall slam, a chain hit or a crate crush staggers it. Its charge can throw *you* into a pit. | Sidestep the charge so it slams into a wall, then kick it while it's dazed. | Prison |
| **Scent-hound** | Fast, fragile, hunts in pairs. Follows your recent trail instead of using sight. | Very light: kicks and rocks send it twice as far. | Break its trail across water. Kill it fast or get it into a hazard. | Prison, Cistern |
| **Bell-warden** | Doesn't fight. When it notices you, it runs to an alarm bell. | Can be knocked off its route or into a hazard on the way. | A priority target. If it rings the bell, every guard on the floor is wary. | Prison |
| **Shieldbearer** | A frontal shield blocks bolts and slashes. | Kicking the shield pushes *you* back. Hits from behind or the side work normally. | Flank it, or lure it with a rock so it turns its back. | Cistern |
| **Pit-lurker** | Hides in pits or deep water and grabs anyone on the rim. | Makes the rim dangerous for both sides. It drags guards in too. | Stay off the rim, or bait guards past it. | Cistern |
| **Crawler swarm** | Packs of tiny, weak creatures. | Chain reactions galore: one kick scatters the pack. Crates crush several at once. | Area control: crates, chokepoints, hazards. | Cistern, Foundry |
| **Hook-jailer** | Throws a chain hook that *pulls you* towards it. | The reverse of your kick: it can drag you over a pit. A wall or a crate in between blocks the hook. | Keep cover between you, or dodge the telegraphed throw. | Prison, Foundry |
| **Foundry automaton** | Leftover imperial machinery. Slow, armoured, ignores stuns. | Immune to weapons. Only hazards or machinery destroy it. A walking environment puzzle. | Lure it into a pit, crusher or furnace. | Foundry |
| **Lantern-bearer** | Carries the only light in a dark area and reveals you within it. | A kicked lantern breaks and darkens the area (and could start fires later). | Put the light out, then sneak. | Cistern, Foundry |
| **Crossbow sentry** | Ranged. Keeps its distance, with a visible aiming line. | Its bolts can hit other guards. | Use cover. Close the distance, or make it shoot its friends. | Foundry |

**Built in the sandbox: Gaoler and Scent-hound.** One change from the table: deep water can't break the hound's trail (the player can't swim), so its trail fades over time and rocks distract it instead. The Gaoler also crushes anything its charge pins against a wall.

Originally suggested as the first pair: They sit at opposite ends of the physics (too heavy to kick vs. flies across the room), so together they show whether kicking has depth.

## Setting (v0.2, from the latest discussion)

- **The Sunken Lands** are sealed dead lands. The fortress stands on the edge of **the Rift**, a vast chasm leading down into the earth.
- **Going up is worse:** the surface beyond the fortress is held by flying beasts and orc warbands. No one escapes that way.
- **So the prisoner goes down.** The fortress descends into the Rift, and below it lies a complete underground world. That world is said to connect to the **ancient mines of an old king**, and through them back to friendly territory. Every floor down is both more dangerous and closer to freedom.
- **The chasms** (Option A, "The Drop", adapted): the fortress is built down the wall of the Rift. Its chasms are places where floors have collapsed towards the depths. Things that fall are gone, or land somewhere far below.
- **The floors as a journey:** Prison (the fortress's upper levels) → Cistern (the waterworks cut into the Rift wall) → Foundry (the forges at the bottom of the fortress) → the gates of the underground world.

**Naming note (keeping it original):** "Deeping", an underground king's mines, orcs and flying beasts together echo a very famous fantasy series closely. The design brief asks for a distinct identity, so I'd suggest original names. A few starting points:
- **The underground world:** *the Hollowreach*, *the Undervault*, *the Lowmarch*, *Gloamhold*
- **The old king and his mines:** *the Mine-Kings of Varrow*, *the Hearthless King*, *the Ashen Delvings*
- **The surface threats:** keep "orcs" (a generic fantasy term) or give them a culture of their own. The flying beasts could become something specific, e.g. *wyrmkites* or *carrion drakes*.

## The Chasms: What Are They? (options to choose from)

Pits are the game's signature hazard, so they should mean something in the world. Here are three framings that can be combined.

### Option A: "The Drop" (recommended as the main idea)
The fortress wasn't built *on* the dead lands. It was built *down into* a great rift at their edge, as a prison that goes downwards. Imperial law sentenced the worst prisoners "to the Drop": the deeper you were sent, the worse your crime. Over centuries the floors decayed, and the chasms are places where floors have collapsed into the levels below.
- **Why the player goes down:** the way out of the sealed lands runs *under* the border, through the fortress's foundations. Escaping means descending further into the place everyone fears.
- **Gameplay links:**
  - *Crumbling rims:* the fortress is still collapsing into the rift.
  - *Falling enemies:* a guard you knock into a chasm lands on a floor below. You might find its body (and the bolts in it) when you get there, a reward for good kicks.
  - *Later upgrade:* a rope or grapple could make a risky "take the Drop" shortcut possible.
- **Atmosphere:** wind moaning up from the shafts, faint lights far below (floors you haven't reached), imperial sentencing carvings above the bigger shafts, rusted chains bolted at the rims.

### Option B: "The Wound"
The empire sealed the dead lands with a vast engine driven deep into the earth. The seal is failing, and the chasms are cracks spreading from it. Things crawl up out of them.
- Gives the Foundry and its machinery a purpose (they powered the seal) and offers a long-term mystery for the family-rescue story.
- The cracks could glow or breathe, and get worse the deeper you go.

### Option C: Each floor has its own hazard with a purpose
- **Prison: oubliette shafts.** Grated holes where prisoners were dropped and forgotten. Some grates have rusted away; these are the crumbling rims.
- **Cistern: sluice channels.** Deep water that the old waterworks still pushes through. Sluice gates could later be opened and closed as machinery.
- **Foundry: slag chutes and casting pits.** Later they could be molten, giving fire as a hazard.

**Recommendation:** use **A** as the backbone (the fortress is a downward prison and the chasms are collapses into the Drop), **C** for each floor's flavour, and keep **B** as a whispered mystery for later chapters.

## More Mechanics to Explore (next round)

**Stealth depth**
1. **Bodies get discovered.** A guard who finds a body raises the alarm or turns wary. *Bodies that fall into a pit or water are never found,* which gives the physics kills a stealth purpose.
2. **Light and shadow.** *(Built.)* Guards see less far into darkness. Torches can be knocked out with a rock (Blade) or a bolt (Crossbow), and crouching in shadow is safer still.
3. **Footstep noise.** Walking makes a little noise, crouching none, dodging a lot. Rubble and puddles are louder.
4. **Silent takedown.** Crouch up behind an unaware guard and take it down without a weapon. Slow (about a second), and it fails if anyone sees it.

**Combat depth**
5. **Blade parry.** A slash timed in the last moment of a guard's wind-up staggers it. This gives the Blade a skill ceiling to match the Crossbow's aim.
6. **Charged kick.** Hold the kick to push further (more distance, longer commitment).
7. **Spiked walls and hanging cages.** A wall slam into spikes kills. A bolt or rock drops a hanging cage on whoever is underneath.
8. **Grab and throw.** Pick up a crate, rock or body and throw it.

**Pressure and stakes**
9. **Eating takes time.** Food heals, but eating takes about a second during which you're vulnerable.
10. **Guard morale.** When guards see allies thrown into the Drop, the rest hesitate. A few might even flee and raise the alarm elsewhere.
11. **One-use tools.** For example a smoke pot that blocks vision cones, or an oil flask (fire, later).

**Suggested next three:** *bodies get discovered* (with pits hiding them), *light and shadow*, and the *Blade parry*. The first two deepen stealth and tie it to the physics and the gloomy setting. The parry gives the Blade loadout its own skill moment.

## Proposed Answers (draft, not yet decided)

These are suggestions to discuss. Nothing here is final until marked as decided.

1. **Total floors:** 9 floors in three acts of three, with a boss closing each act. The prototype is Act 1 (Prison, Cistern, Foundry).
2. **Prototype physics:** (a) **Shove**: a short-range push with real knockback that sends enemies into pits and chasms. (b) **Deep water**: enemies pushed or lured in sink and drown; the player can wade in shallows but not deep water. (c) **Thrown rock**: makes a noise where it lands, pulling enemies away from their route. Fire and pinning are deferred.
3. **Legacy currency:** Mostly from floors reached, optional rooms opened, and bosses defeated, with only a small amount from kills. This rewards sneaking as much as fighting.
4. **Temporary abilities:** Two sources. Floor rewards offer a choice of one from three. Run currency is spent at a refuge or vendor between floors. No level-ups.
5. **Optional room preview:** You can partly see inside through barred windows or a grate, and the locked door shows an icon for the room type (food, gear, shortcut).
6. **Weapons:** Decided (see Decisions): two loadouts, Crossbow + Shove and Blade + Stun Rock.
7. **Main key and exit:** The main key has a unique glow and sound, and the exit door carries a matching imperial seal. The map marks the exit once you have seen it.
8. **First boss:** A heavy foundry guardian. It can't be shoved until it is staggered, its attacks are telegraphed in phases, and the arena reuses what the player learned (pits and machinery). It can be beaten with plain weapons alone.

## Build Milestones (draft)

Each milestone should be playable and tested before moving on.

- **M0 — Combat sandbox:** One gray-box room containing the player (movement, dodge, basic weapon, shove), one enemy type that patrols and chases, a pit, and deep water. Goal: find out whether shoving things into hazards is *fun*.
- **M1 — Stealth and noise:** Enemy vision cones, awareness states (unaware, suspicious, alert), thrown rocks, noise from loud actions.
- **M2 — Floor structure:** Connected rooms, the main key, the exit door, an optional key and room, food pickups. Floor 1 (Prison) in gray-box form.
- **M3 — Floor 2 (Cistern):** Water-heavy layouts, patrols that react to noise, the crossbow.
- **M4 — Floor 3 (Foundry) and boss:** Machinery hazard, boss fight, post-boss reward choice.
- **M5 — Run loop:** Death and restart, run currency and refuge vendor, legacy currency saved to disk, starter weapon choice.
- **Later:** Art pass, sound, lighting and atmosphere, more floors.
