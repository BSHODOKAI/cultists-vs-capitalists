# ROADMAP — Ideas to Ponder

> **These are not commitments.** This file is a parking lot for forward-looking ideas so the
> timeless reference in [`DESIGN_BIBLE.md`](DESIGN_BIBLE.md) stays clean. Nothing here is
> scheduled, promised, or scoped. Treat every line as a conversation starter.
>
> When an idea here becomes real design, move its **flavor** into the design bible and its
> **mechanics** into `AGENTS.md`.

---

## 1. Player-Side: More Cults, More Occultisms

The current cult is Lovecraftian. The design's *shape* (see Design Bible §8) is built to host
other traditions without losing the game's identity. Ideas to think about:

- **What traditions fit the "scrappy underdog repurposing junk" mold?** Candidates worth pondering:
  folk-saint / Santa Muerte devotionalism, hoodoo and rootwork, Norse runecraft, Theosophy and
  séance culture, urban shamanism, cargo-cult millenarianism (the game already has a cargo-cult
  windfall event — is that a seed?).
- **What is the shared meter called per cult?** Corruption/Rites/Reckoning is the Lovecraftian
  framing. Another cult might call the same bargain by a different theological name. Question to
  settle before building: **generalize Corruption behind a per-faction abstraction**, or clone it
  with new flavor? (Generalizing is cleaner; cloning is faster but risks drift.)
- **How does the cult choose at run start?** A faction-select screen, a seed-driven assignment, or
  an unlock progression?
- **Do cults share towers or have their own rosters?** Shared roster = less content, less identity.
  Own roster = the full tower pipeline (`data/towers`, upgrades, models, icons, cues) per cult.
- **Do enemy factions react differently to different cults?** The Wave Director already
  counter-picks by tag; a different cult presents a different coverage profile for free.

---

## 2. Corporate-Side Expansion

- **A fifth corpo faction** — the modern-capitalism angles not yet used: surveillance/social media,
  pharma, creditors/debt collectors, regulators, privatized utilities, media/propaganda. Each wants
  a distinct combat identity (Design Bible §8).
- **Sub-brands and subsidiaries** — bosses as *executives* invites named individuals and
  departments under the existing factions. Cheap way to add character without a new faction.
- **Event-deck growth** — the run-events deck is already a shuffled, non-repeating rotation
  (§8 of `AGENTS.md`). More buff/debuff cards, especially ones that reference corpo activity
  ("Hostile Audit", "New Subscription Tier", "Regulatory Capture"). Keep debuffs **soft** — no
  instant life loss.

---

## 3. Systems the Bible Now Implies

These are consequences of writing the bible down, not features anyone requested:

- **A per-faction "bargain" interface** — if more cults arrive, Corruption/Rites/Reckoning likely
  needs to become a pluggable shape so each cult supplies its own names and flavor without
  duplicating logic.
- **A content-lint for theme** — a lightweight check (a test, a skill step, or a checklist app) that
  flags new content failing the Design Bible §9 pre-flight (name pattern, emoji/register in
  strings, missing "bill" on a power-granting node). Optional, but it would stop drift.
- **Faction identity in the data layer** — today factions are mostly strings + colors. If cults
  multiply, a `FactionData` resource (name, voice line, palette, altar/UX flavor) would centralize
  what's currently spread across constants.

---

## 4. Presentation Polish

Long-term, the visual/audio layer is placeholder-driven (procedural meshes, icons, and sounds).
Ideas to ponder — **not** a mandate to replace systems that work:

- Authored 3D meshes for towers/units/bosses that keep the existing silhouette rules
  (towers < 1.5 height, units grounded and facing travel).
- A **title/menu identity pass** — the menu is a plain centered VBox; the theme is strong enough to
  carry a more atmospheric title screen.
- Music/ambience that sits the *corporate* and *occult* registers against each other.
- Localization-ready strings (the two-register voice in Design Bible §4 should survive translation).

---

## 5. Open Questions to Settle Before Big Moves

- **How central is the Corruption bargain?** If it's the game's thesis (the bible argues it is),
  new cults and systems should orbit it. Confirm.
- **Is "the cult" ever the player's *enemy*?** Rogue Entities already imply the player's own rot can
  turn on them. Worth pondering whether a future mode leans into that.
- **Multiplayer?** Out of scope here, but if co-op is ever considered, the faction/cult split and
  the deterministic seeded systems are assets — note it and move on.