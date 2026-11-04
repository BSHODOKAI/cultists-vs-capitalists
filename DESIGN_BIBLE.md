# DESIGN BIBLE — Cultists vs. Capitalists

> **This doc is the tone-and-theme reference.** It says *what the game is about* and *how
> new content should feel*. It deliberately does **not** restate mechanics — for the numbers,
> systems, and formulas see [`AGENTS.md`](AGENTS.md); for step-by-step how-tos see the skills
> in [`.ziva/skills/`](.ziva/skills).
>
> If a mechanic in `AGENTS.md` is the *what*, this bible is the *why* and the *voice*.
> When the two seem to conflict, the bible wins on flavor and `AGENTS.md` wins on behavior.

---

## 1. Elevator Pitch

**Cultists vs. Capitalists** is an endless-mode, orthographic-isometric, axial-hex-grid tower
defense. A scrappy, broke, Lovecraftian street cult — mysticism welded to salvaged urban junk —
defends its **Sanctum** against sleek, sponsor-branded cyberpunk corporate warlords carving a
procgen metropolis into private property.

You are the underdog. You have no budget, no board, and no HR department. You have a nail gun,
a storm drain, a billboard nobody's renting this quarter, and something old and hungry that
answers when you hum the right way. The corporations have venture capital, compliance officers,
and a security division that files its violence as a line item.

---

## 2. The Core Tension (the actual thesis)

The mechanics are satire, but the game has one real idea underneath them:

> **Power is a debt, and someone always collects.**

Everything corrupt-flavored in the design is a *bargain* the player chose:

- **Corruption** is the rot you carry. It buys you damage (*+0.25% per point*), and it draws
  a line past which your own power wakes up hostile (**Rogue Entities** at 100).
- **Rites** are Corruption *spent as a resource* — but each one banks "Rite debt," which decides
  how bad the next **Reckoning** is. You draw power now; you pay attention later.
- **Corporate Attention** is the other ledger. The faster you grow, the more the Wave Director
  answers you. Winning harder makes the game harder, on purpose.

The player's whole emotional arc is *"I can hold one more hex"* versus *"I am one draw away from
the things in the dark noticing me."* Corporate evil is mundane and relentless; the eldritch is
real, and it is not your friend either. The cult sits between them, borrowing from both.

**Rule of thumb for any new system:** if it removes the *bargain* — if it lets the player take
power without a corresponding risk, bill, or Attention — it is off-theme.

---

## 3. The Three Pillars

Every piece of content — a tower, an enemy, an event card, a button label — should touch at least
one of these, and ideally two.

### Pillar A — Underdog Scrappiness
The cult wins with junk, ingenuity, and faith, not hardware. Broken things made to work;
salvaged things made sacred. This is the *heart* of the fantasy: it should feel *improvising*.

> Storm drains, highway billboards, incense burners, subway grates, server racks, collection
> plates, propane tanks, drone salvage, union picket hardware, hardware-store nail guns.

### Pillar B — Corporate Satire
The enemy is not "evil." The enemy is *efficient*. Corporate evil here is bureaucratic, branded,
and banal — taxes, audits, buyouts, subscriptions, same-day delivery. Play it straight and let it
be funny; the joke is that it's all totally normal.

> Swarm Syndicate, Iron Board, Hostile Takeover Inc., Skyline Logistics — each a recognizable
> flavor of modern capitalism wearing cyberpunk armor.

### Pillar C — Cosmic Occultism
The eldritch is real, literal, and load-bearing. Miracles happen on the hex grid. But the cosmic
is not a *get-out-of-the-debt-free* card — it is the debt. The stars are right, and that is bad
news for everyone, including the cult.

> Revealed branches, Void and Psychic damage, ley lines, corruption reservoirs, "The Stars Are
> Right," the Reckoning.

---

## 4. Tone & Voice

The signature is **deadpan sinister**: the occult described in the language of business, and
business described in the language of the occult. Both registers are played completely straight;
the comedy is in the collision, never in a wink at the camera.

- Corporate speak applied to the eldritch: *"COMPANY DROP INBOUND — SELECT ROUTE"*,
  *"Corporate Executive Threat"*, *"The Audit Comes Due"*, *"Reckoning: +N"*.
- Occult speak applied to business: *"the till audits itself"*, *"the song is billed"*,
  *"paid in flesh"*, *"blood tithe"*, *"the plate never empties"*.
- Failure is stated flatly and finally: *"SANCTUM OVERRUN — GAME OVER."* No whimsy, no apology.

**Voice rules:**
- Prefer **short, declarative, slightly ominous** sentences. A tooltip should sound like a warning
  and a receipt at the same time.
- The **UI is corporate** (headers, ALL-CAPS alerts, intel panels, debriefs). The **cult content is
  liturgical** (rites, tides, tithes, vigil, communion, the flock).
- **Never** break the fourth wall, never lampshade the theme, never use emoji or casual modern
  internet register.
- Keep it **Lovecraftian, not gory-for-shock**: dread, appetite, debt, and wrongness — not splatter.

**Good:** `"The Veil Thins — +20% tower damage this wave."`
**Bad:** `"lol the veil is thin now, free damage!!"`

---

## 5. Naming Convention

Names are the fastest way a new addition either feels native or feels bolted on. The pattern:

> **[mundane object OR corporate/ledger term] + [occult or transactional twist]**

Either half can lead. The mundane half grounds it; the twist half gives it teeth.

| Feels native | Why |
|---|---|
| `rust_censer` / Rust Censer | a real object (censer) + decay |
| `tithe_box` / Tithe Box | church object + money |
| `leveraged_buyout` | pure corpo finance, used as a weapon |
| `the_audit_comes_due` | accounting as apocalypse |
| `nail_of_accounting` | tool + ledger, both halves twist |
| `substation_effigy` | infrastructure + idolatry |
| `gig_runner`, `scooter_courier` | gig-economy job titles, no elitism |

| Feels off-theme | Why |
|---|---|
| `death_laser_3000` | no mundane half, no satire, generic |
| `space_wizard` | ignores the street-level scrappiness |
| `turbo_super_gun_v2` | reads as product marketing, not cult or corpo |
| `lovecraft_eldritch_horror_station` | says the theme instead of enacting it |

**Corpo names** should sound like real companies or job titles. **Cult names** should sound like
something a broke person would actually write on a cardboard sign in a basement — then a spirit
answers it. Prefer **lowercase `snake_case` ids** and **Title Cased display names**, matching the
rest of the data files.

---

## 6. Visual & Color Language

The palette in [`data/visual_theme.tres`](data/visual_theme.tres) /
[`scripts/core/visual_theme_data.gd`](scripts/core/visual_theme_data.gd) is *semantic* — colors
mean things. Preserve those meanings when adding content.

| Color | Meaning |
|---|---|
| Revealed purple | eldritch / forbidden branch |
| Rigged orange | salvaged / overvolted / jury-rigged branch |
| Rite crimson | blood-debt branch (deliberately distinct from the other two) |
| Cyan ring | attack-tower range |
| Gold ring | buff-tower aura |
| Objective green / white / red | claimed / unclaimed / captured site |
| Faction colors | Swarm Syndicate gold, Iron Board steel-blue, Hostile Takeover magenta, Skyline Logistics cyan, Coalition white |
| Damage-tag colors | Kinetic bone, Corrosive green, Psychic pink, Void violet, Electric cyan |

**Silhouette rules:** towers stay **strictly under height 1.5** (`TOWER_MAX_HEIGHT`) and read as
*improvised*, not manufactured. Enemy units are grounded at Y=0 and **face their direction of
travel**. A viewer should be able to tell a *cultist thing* from a *corporate thing* by silhouette
alone — jagged/handmade vs sleek/branded.

---

## 7. Do's & Don'ts

### Towers & Upgrades
- **Do** make every tower read as *salvaged junk made sacred* — a mundane object plus an occult
  purpose. The object should look like it was found, not bought.
- **Do** keep the three branches on-theme: **Revealed** = eldritch/blood/void; **Rigged** =
  overvolted/hacked/industrial; **Rite** = power bought with the Corruption meter itself.
- **Don't** give the cult clean, mass-produced, military-grade, or sponsor-branded hardware —
  that is the *enemy's* aesthetic. The cult does not have a supply chain.
- **Don't** add a tower that is just another tower's numbers with a new coat of paint. Every
  tower owns a distinct mechanical *and* thematic niche.

### Enemies & Bosses
- **Do** keep corporate evil **mundane and bureaucratic** — audits, buyouts, subscriptions,
  delivery logistics, health-and-safety violence. The horror is how *normal* it is.
- **Do** let bosses carry the satire in their **mechanics** (a leveraged buyout that literally
  converts your tower; a "restructuring" that changes a boss's resistances).
- **Don't** make corporate units *cosmically* scary. Cosmic dread belongs to the player's corner
  (Revealed, Void, the Reckoning) — and even there it is a *liability*, not a gift.
- **Don't** give enemies whimsy or pathos that undercuts the faceless-efficiency read.

### Run Events & the Director
- **Do** frame events as **market forces and omens** — a shuffled deck of cards the universe deals
  you, revealed only when they land. Buffs feel like brief grace; debuffs feel like the market
  correcting.
- **Do** keep debuffs *soft* — a squeeze, a tax, a rusting — never a cheap instant loss.
- **Don't** advertise the next card. The point is dread, not planning around a known schedule.

### UI Copy & Presentation
- **Do** write UI like a corporate system: ALL-CAPS alerts, terse intel, flat debriefs, a boss bar
  labeled *"Corporate Executive Threat."*
- **Do** keep the two registers — corporate UI, liturgical cult content — visibly distinct.
- **Don't** use emoji, memes, apologetic tooltips, or fourth-wall gags. The tone never winks.
- **Don't** describe the theme in the copy ("an eldritch horror arrives!") — *enact* it
  ("The Congregation").

---

## 8. Faction Guidelines

### The Corporate Side (the enemy)

Each faction is a **recognizable flavor of modern capitalism**, expressed through unit design:

| Faction | Identity | How it threatens | Voice |
|---|---|---|---|
| **Swarm Syndicate** | Precarious gig economy | Cheap, fast, plentiful; spawns and swarms | "You didn't sign up for benefits." |
| **Iron Board** | Corporate security & raw capital | Armored, shielded, breaking through | "This is a controlled environment." |
| **Hostile Takeover Inc.** | Predatory finance & hacking | Disables, cloaks, converts your towers | "We're acquiring your assets." |
| **Skyline Logistics** | Delivery/supply-chain dominance | Air superiority, healers, drop pods | "Your package is on the way." |
| **Coalition** | All of them, allied | Boss that cycles every faction's tricks | "The board has reached consensus." |

The **Rogue Entities** are the exception that proves the rule: they are not corporate at all.
They are what the *cult's own* Corruption becomes when it wakes — the player's mirror, the bill
for the power they bought.

**Adding a corpo faction?** Give it a distinct *modern-capitalism angle* (surveillance, pharma,
creditors, regulators, media), a distinct combat identity, and a voice that sounds like a real
company memo. It must not be "the same four with new colors."

### The Player Side (future cults)

Additional playable cult factions are planned. The occultism will vary; the **shape** must not.
Every player cult must satisfy **all four** of these:

1. **Scrappy underdog truth.** Whatever tradition it draws on, the cult is *broke, improvised, and
   street-level*. It repurposes mundane/corporate junk for sacred ends. No faction gets to be the
   sleek, well-funded one — that seat is taken by the enemy.
2. **A distinct occult tradition**, not a reskin. Different imagery, different vocabulary for its
   currency, its meter, and its rites. If two cults share more than structure, one is redundant.
3. **An analogous risk/reward meter** in the **Corruption → Rites → Reckoning** shape: a
   dangerous resource that is both *power* and *debt*, drawn on deliberately, that eventually
   collects. The *name and flavor* change per cult; the *bargain* does not. (The Corruption
   mechanic may be generalized behind this shape — see [`ROADMAP.md`](ROADMAP.md).)
4. **The shared interface of the fantasy** — a Sanctum to defend, an enemy that is corporate
   modernity, a world that is the same city (or a neighboring one).

**Design test:** a player should be able to say what makes cult B different from cult A *in one
sentence about its soul*, not just its build order.

---

## 9. Keeping To It (pre-flight checklist)

Before merging any new tower, unit, boss, event, faction, or UI string, ask:

- [ ] **Which pillars?** It touches at least one of Underdog Scrappiness / Corporate Satire /
      Cosmic Occultism — ideally two.
- [ ] **Which side of the line?** Cult content is improvising and liturgical; corporate content is
      sleek and bureaucratic. Nothing straddles blurrily.
- [ ] **Does it keep the bargain?** If it grants power, what is the bill — cost, Corruption,
      Attention, risk?
- [ ] **Does the name pass §5?** Mundane-or-corporate half plus occult-or-transactional half.
- [ ] **Does the copy pass §4?** Deadpan sinister; no winks, no emoji, no fourth wall.
- [ ] **Does it feel native?** Read it beside an existing entry of the same kind — do they belong
      in the same game?
- [ ] **Mechanics still valid?** Confirm numbers/rules against [`AGENTS.md`](AGENTS.md) and the
      relevant skill in [`.ziva/skills/`](.ziva/skills), and run the project's tests.

---

## 10. Where Ideas Go Next

This bible is the **timeless** reference. Forward-looking, speculative ideas — new cults, new
factions, new systems, presentation polish — live in [`ROADMAP.md`](ROADMAP.md), clearly marked as
*ideas to ponder, not commitments*. When a roadmap idea graduates into real design, fold its
flavor into this bible and its mechanics into `AGENTS.md`.