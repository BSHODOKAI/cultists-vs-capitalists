# Enemy Concept Art — the corporate war machine (and the one that isn't)

The **fidelity target for the enemy side**, exactly as [`../README.md`](../README.md) (the Sanctum)
and [`../towers/README.md`](../towers/README.md) (the cult's emplacements) are the targets for the
cult. **Match the concept at its own value.**

> **Prompts ARE recorded below, verbatim.** Every image = *framing + subject + shared corporate
> style block*, concatenated exactly as sent. Same rule as the tower concepts (see the
> [`create-3d-asset`](../../../.ziva/skills/create-3d-asset/SKILL.md) skill §7).

Generated 2026 · `generate_image` (kind `sprite`, finish `smooth`, 768×768).

---

## The other half of the visual language

The cult concepts describe an *improvising* enemy: junk made sacred, kerbs and railings and tarps.
The corporations are the **opposite** and must never blur into them. Per
[`../../../DESIGN_BIBLE.md`](../../../DESIGN_BIBLE.md) §6, a viewer must be able to tell a
*cultist thing* from a *corporate thing* **by silhouette alone — jagged/handmade vs sleek/branded**.

| | Cult | Corporation |
|---|---|---|
| **Silhouette** | jagged, hand-cut, asymmetric | smooth, symmetrical, moulded |
| **Fabrication** | found, salvaged, patched, welded | mass-produced, standardized, seam-lined |
| **Surface** | rust, spray sigils, drip wax, moss | sponsorship livery, chrome, glass, LED strips |
| **Reads as** | sacred junk | corporate hardware |
| **Colour** | warm (rust, sodium orange, red) | cold (faction colour, chrome, white livery) |

**Faction palettes** (DESIGN_BIBLE §6): Swarm Syndicate **gold**, Iron Board **steel-blue**,
Hostile Takeover **magenta**, Skyline Logistics **cyan**, Coalition **white**.

### Banned on the corporate side
Anything that reads as **improvised, salvaged, cobbled-together, patched, or cult-made**; anything
**medieval**; and **any real brand** (logos are generic abstract corporate marks — the provider
rejects named brands, and theme-wise the joke is the *anonymity* of capital).

---

## The shared corporate style block (one accent slot per faction)

> Sleek mass-produced corporate cyberpunk hardware: injection-moulded matte armour plates with
> brushed chrome and dark glass, large white sponsor livery panels each carrying a generic abstract
> geometric corporate logo (no real brands), thin emissive `<ACCENT>` LED status strips, orange-and-black
> hazard chevron striping, clean panel lines and bolt clusters, cable looms and stub antennas, a
> faint holographic corporate signage shimmer. Sharp, clean, standardized fabrication — **NEVER
> medieval, NEVER improvised, salvaged, or cobbled together.** Cold studio rim-light with a subtle
> `<ACCENT>` key, crisp high-tech reflections, deep near-black shadows. Highly detailed game asset,
> painterly realism.

**Accent substitution:** `<ACCENT>` is the faction's colour word — Iron Board **cyan**, Swarm
Syndicate **amber**, Hostile Takeover **magenta**, Skyline Logistics **cyan**. The block was sent
verbatim with that one word substituted; everything else is identical. (The faction's *armour*
colour lives in its subject block, so the accent alone is not the faction tell — Iron Board and
Skyline share cyan lights but are steel-blue vs white-bodied.)

## Per-take framing blocks (verbatim)

**Take `a` — centred hero**
> Isometric 3/4 view, orthographic feel, matching the game camera yaw 45 degrees and pitch 35
> degrees, of a single dark hexagonal ground tile standing alone on a pure black background — wet
> dark asphalt with faint corporate hazard markings. A sleek, sponsor-branded cyberpunk corporate
> war machine built by corporate warlords carving a city into private property. The subject is
> **[SUBJECT]**. *[+ shared style block]* Square composition, centered hero view.

**Take `b` — close, low three-quarter**
> Close three-quarter isometric view, lower camera angle (yaw 45 degrees, pitch about 30 degrees),
> tight and dramatic, the subject dominating the frame. A single dark hexagonal ground tile on a
> pure black background. A sleek, sponsor-branded cyberpunk corporate war machine — the subject is
> **[SUBJECT]**. *[+ shared style block]*

**Take `c` — wide gameplay distance**
> Wide isometric 3/4 view at gameplay distance (yaw 45 degrees, pitch about 35 degrees), showing a
> whole single dark hexagonal yard to its perimeter, orthographic feel, pure black background. A
> sleek, sponsor-branded cyberpunk corporate war machine — the subject is **[SUBJECT]**, the machine
> smaller and centred within the yard. *[+ shared style block]*

---

## The images

### Iron Board — `sponsor_mech` (unit)

**Subject block (verbatim):**
> a HEAVY ARMOURED CORPORATE SPONSOR-MECH: a sleek mass-produced four-legged combat walker in matte
> steel-blue armour with brushed-chrome trim, huge white sponsor livery panels each carrying a
> different generic abstract geometric corporate logo, a low armoured cockpit of dark glass, emissive
> cyan status LEDs, orange-and-black hazard chevron stripes along the leg guards, heavy hydraulic
> industrial legs ending in broad steel feet, cable looms and stub antennas, sponsor pennants on
> outriggers

`unit_sponsor_mech_a.png` · `unit_sponsor_mech_b.png` · `unit_sponsor_mech_c.png`

Reads as: the archetypal sponsor-branded warlord — a Walking billboard in steel-blue. Breakthrough:
it crushes through blockers.

### Iron Board — `the_chairman` (boss)

**Subject block (verbatim):**
> THE CHAIRMAN, a corporate executive dreadnought: an enormous sleek command tank on broad
> continuous tracks, matte steel-blue armour with brushed chrome and a gold pinstripe, a domed
> dark-glass boardroom observation cupola on top with a faint holographic bar chart and a
> high-backed executive chair silhouette visible inside, white sponsor livery panels with generic
> abstract corporate logos, a polished brass nameplate (no legible text), emissive cyan LED strips,
> orange-and-black hazard chevrons, folding entry steps, and two smaller riot-shield security robots
> flanking it

`boss_the_chairman_a.png` · `boss_the_chairman_b.png` · `boss_the_chairman_c.png`

Reads as: the boardroom as a fortress. Restructuring: at 100/66/33% HP it shifts a resistance and
halts, immune, while two `riot_shield_unit` escorts deploy — hence the escorts in the shot.

---

### Swarm Syndicate — `gig_van` (unit)

**Subject block (verbatim):**
> a GIG-ECONOMY DELIVERY VAN of the Swarm Syndicate: a cheap, boxy, mass-produced urban cargo van on
> tall utilitarian tyres, matte amber-gold and dark-grey bodywork, a huge side panel of white sponsor
> livery carrying a generic abstract geometric delivery-app logo, a roof cargo pod with a hinged hatch
> propped open, cheap clip-on plastic trims and a plain plastic grille, emissive amber-yellow LED
> status strips and a glowing roof sign, orange-and-black hazard chevrons on the rear bumper, small
> worker-drone launch racks on the roof — a fleet vehicle, plainly engineered and utterly expendable

`unit_gig_van_a.png` · `unit_gig_van_b.png` · `unit_gig_van_c.png`

Reads as: gig-economy logistics. Corporate, but *cheap* — a plain fleet van, no premium hardware.
SpawnOnTimer: the roof racks are where its `gig_runner`s come from.

### Hostile Takeover Inc. — `acquisitions_rep` (unit)

**Subject block (verbatim):**
> AN ACQUISITIONS REP of Hostile Takeover Inc.: a sleek black and magenta corporate agent, a slim tall
> humanoid executive in a glossy armoured business suit, its head a smooth magenta-lit visor faceplate
> with no visible face, a long moulded-armour overcoat trimmed with magenta pinstripes, thin emissive
> magenta LED piping along the limbs, a slim briefcase-shaped hacking device in one hand projecting a
> magenta holographic acquisition reticle and a thin magenta conversion beam from a headset antenna,
> white sponsor livery patches carrying generic abstract corporate logos on the shoulders, thin cable
> tendrils running from the briefcase into the sleeve, sharp angular corporate shoes

`unit_acquisitions_rep_a.png` · `unit_acquisitions_rep_b.png` · `unit_acquisitions_rep_c.png`

Reads as: predatory finance as a person. The faceless visor and the **acquisition reticle / conversion
beam** are the `TowerConvert` mechanic made visible — it locks onto your best tower and takes it.

### Skyline Logistics — `drone_carrier` (unit)

**Subject block (verbatim):**
> A DRONE CARRIER of Skyline Logistics: a broad, sleek autonomous cargo aircraft hovering low over the
> ground, white and cyan delivery livery, a canopy-like dish fuselage with a large white sponsor livery
> panel carrying a generic abstract geometric logistics logo, rows of recessed modular drone bays along
> its flanks each glowing cyan, four tilt-rotor pods on stub wings and retracted landing skids, thin
> emissive cyan LED status strips, orange-and-black hazard chevrons around the underside hatch, a few
> small quadcopter delivery drones docked in its bays with two launching, faint holographic routing
> lines in the air

`unit_drone_carrier_a.png` · `unit_drone_carrier_b.png` · `unit_drone_carrier_c.png`

Reads as: supply-chain dominance, in the air. The modular drone bays are its `SpawnOnTimer` —
`courier_drone`s launching from the flanks.

---

### Swarm Syndicate — `the_disruptor` (boss)

**Subject block (verbatim):**
> THE DISRUPTOR, a Swarm Syndicate command roadshow vehicle: a heavy mass-produced flatbed corporate
> broadcast truck on tall tyres, matte amber-gold and dark-grey bodywork, a banked wall of huge
> loudspeakers and stacked sponsor video screens along its flanks, a tall scrolling amber LED
> price-ticker mast on the roof, a warning siren beacon, white sponsor livery panels carrying generic
> abstract geometric gig-platform logos, orange-and-black hazard chevrons, heavy cable looms, flanked
> by a loose swarm of identical small cheap expendable delivery-runner robots that crowd around it

`boss_the_disruptor_a.png` · `boss_the_disruptor_b.png` · `boss_the_disruptor_c.png`

Reads as: a mobile surge-pricing rally. **SurgePricing** is the siren + the crowd it whips up;
**NetworkEffect** is why it is *surrounded* — its toughness scales with the Syndicate bodies near it.
(The generated signs — *"MORE PEOPLE, HIGHER OUTPUT"*, *"A BRIGHTER TOMORROW TOGETHER"* — are the
model's own invented livery text; the prompt asked only for generic sponsor panels.)

### Hostile Takeover Inc. — `the_raider` (boss)

**Subject block (verbatim):**
> THE RAIDER, a Hostile Takeover Inc. acquisition flagship: a sleek angular hovering dreadnought with
> a shark-like wedge silhouette, glossy black and magenta plating with a white sponsor livery panel
> carrying a generic abstract geometric corporate logo, a huge forward-projecting magenta
> acquisition-beam projector array aimed down at the ground, a glass executive podium dome with a
> faint holographic deal contract floating in the air above it, thin emissive magenta LED piping,
> orange-and-black hazard chevrons, and a small black armed bid-drone tethered on a launching rail
> beneath it

`boss_the_raider_a.png` · `boss_the_raider_b.png` · `boss_the_raider_c.png`

Reads as: **LeveragedBuyout** as a machine — the projector *is* the conversion channel, and the
tethered `bid_drone` is the hostage that keeps it alive.

### Skyline Logistics — `the_prime_dispatcher` (boss)

**Subject block (verbatim):**
> THE PRIME DISPATCHER, a Skyline Logistics air command ship: an enormous sleek cargo airship and
> dropship hybrid hovering high over the ground, white and cyan delivery livery, a long armoured
> gondola fuselage with a huge white sponsor livery panel carrying a generic abstract geometric
> logistics logo, a rotating radar dish and antenna arrays, underslung cargo bay doors open and
> dropping a glowing cyan supply pod on a projected landing reticle, rows of drone launch tubes on
> its flanks, thin emissive cyan LED status strips, orange-and-black hazard chevrons, small quadcopter
> courier drones swarming around it

`boss_the_prime_dispatcher_a.png` · `boss_the_prime_dispatcher_b.png` · `boss_the_prime_dispatcher_c.png`

Reads as: **SameDayDelivery** — the open bay, the descending `supply_pod` and its landing reticle,
and the courier swarm are the mechanic drawn literally. It is the only **Air** boss.

### Coalition — `the_holding_company` (boss)

**Subject block (verbatim):**
> THE HOLDING COMPANY, a Coalition conglomerate war engine: a colossal white and chrome corporate
> mega-machine that visibly combines all four member factions into one towering chassis — a broad
> heavy tracked base with steel-blue Iron Board armour plating, an amber-gold Swarm Syndicate sponsor
> billboard and loudspeaker bank on one flank, a black-and-magenta Hostile Takeover hacking array on
> an articulated arm on the other flank, a cyan Skyline Logistics drone bay on its shoulder, all
> crowned by a glass boardroom observation dome with a faint holographic bar chart and a high-backed
> executive chair inside, white Coalition sponsor livery with generic abstract geometric corporate
> logos, accents of every faction colour, thin emissive white LED strips, orange-and-black hazard
> chevrons

`boss_the_holding_company_a.png` · `boss_the_holding_company_b.png` · `boss_the_holding_company_c.png`

Reads as: **"the board has reached consensus"** — the four factions welded into one chassis, because
its `HoldingCompany` mechanic cycles all four bosses' tricks at 70% strength. The one machine that is
not *a* faction, so its white Coalition livery is the only thing they share.

---

## The exception — the Rogue Entity (not corporate)

`rogue_entity` is the one enemy that is **not** a corporation. It is what the *cult's own Corruption*
becomes when it wakes — the player's mirror, the bill for the power they bought
([`../../../DESIGN_BIBLE.md`](../../../DESIGN_BIBLE.md) §8). It carries no livery and no branding,
because it was never sold to anyone. So it gets a **third** style register, between the other two:

| Register | Belongs to | Reads as |
|---|---|---|
| Cult | the player | salvaged junk made sacred, **static** |
| Corporate | the enemy | sleek, branded, mass-produced |
| **Eldritch** | **the Rogue** | the cult's own ritual matter, **alive and hostile** |

It deliberately reuses the **cult's** vocabulary — candle wax, spray sigils, olive tarp, red banners,
scaffold pipe — because that is *what it is made of*. The horror is that the cult's own materials have
stood up and turned around. It must never read as slick corporate hardware (no chrome, no livery, no
LED strips), and unlike the cult's compounds it is an **entity**, not a place.

### Style block (verbatim)

> An eldritch entity born from the cult's own Corruption: a hunched humanoid mass of black dripping wax
> and tar, its body a fused parody of the cult's salvaged junk — rusted scaffold pipe and chain for
> bones, cracked pale-grey cast-concrete plating, a ripped olive tarp and tattered red banners clinging
> to it like shroud rags, thick running candle-wax and embedded votive stubs — covered in the cult's own
> red and violet spray sigils that glow and pulse from within, a cluster of unblinking eyes where a face
> should be, long glistening black tentacles trailing, wet void-black dripping beneath. **NOT sleek, NOT
> corporate, NOT mass-produced** — hand-made horror, the cult's own ritual matter standing up and
> walking. Deep blacks with a violet and bloody-red emissive glow from within, warm sigils against a
> void body. Highly detailed game asset, painterly realism.

### Subject block (verbatim)

> a ROGUE ENTITY: a single hunched humanoid horror, roughly person-height but wrong — a body of fused
> black dripping wax and tar shaped like a parody of a kneeling cultist, its shell cracked pale-grey cast
> concrete and rusted scaffold pipe for bones, a shredded olive tarp and torn narrow red banners hanging
> off it like a shroud, thick running candle-wax and a hundred guttering votive candle stubs embedded
> across it, its hide covered in the cult's own red and violet spray sigils glowing and pulsing from
> within, a vertical cluster of mismatched unblinking eyes where a face would be, several long glistening
> black tentacles trailing from its back and arms, wet black corruption pooling and dripping beneath it

### Framing blocks (verbatim)

**Take `a`**
> Isometric 3/4 view, orthographic feel, matching the game camera yaw 45 degrees and pitch 35 degrees,
> of a single dark hexagonal ground tile standing alone on a pure black background — wet dark asphalt
> with scorched ritual markings and scattered candle stubs. A thing that should not be here: the cult's
> own corruption given a body. The subject is **[SUBJECT]**. *[+ style block]* Square composition,
> centered hero view.

**Take `b`**
> Close three-quarter isometric view, lower camera angle (yaw 45 degrees, pitch about 30 degrees), tight
> and dramatic, the entity dominating the frame. A single dark hexagonal ground tile on a pure black
> background. The cult's own corruption given a body — the subject is **[SUBJECT]**. *[+ style block]*

**Take `c`**
> Wide isometric 3/4 view at gameplay distance (yaw 45 degrees, pitch about 35 degrees), showing a whole
> single dark hexagonal yard to its perimeter, orthographic feel, pure black background. The cult's own
> corruption given a body — the subject is **[SUBJECT]**, the entity smaller and centred within the yard.
> *[+ style block]*

`unit_rogue_entity_a.png` · `unit_rogue_entity_b.png` · `unit_rogue_entity_c.png`

Reads as: **the Reckoning**. `Breakthrough` + the `TowerDisable` pulse are why it is a heavy, deliberate
thing rather than a fast swarm; the cult's own sigil on its banner is the point — it is wearing the
cult's marks back at them.

---

## Wiring these to the game data

Mechanical identities are in [`../../../UNITS.md`](../../../UNITS.md) §3 and §6 and
`res://data/units/*.tres`. The concepts were generated from the display name, tags, role and
signature ability, so they read at a glance as: **a sponsor-mech is a sponsored heavy** (armour,
livery, industry) and **the Chairman is a command machine** (boardroom dome, escorts, finance).