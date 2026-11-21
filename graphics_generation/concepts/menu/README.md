# Menu & Title Art — the splash and the main menu

**Why this folder exists:** [`scenes/main_menu.tscn`](../../../scenes/main_menu.tscn) is a flat
`ColorRect` behind a centred `VBox` — the game's first impression today is a plain colored rectangle.
This is the concept pass for a **title splash** and a **main-menu background**.

> **Prompts ARE recorded below, verbatim.** Every image = *subject block + shared style block*,
> concatenated exactly as sent (the same rule as every other concept set; see the
> [`create-3d-asset`](../../../.ziva/skills/create-3d-asset/SKILL.md) skill §7).

Generated 2026 · `generate_image` (kind `background`, finish `smooth`, **1280×720**, quality `low` —
a concept pass; re-shoot the chosen take at `medium`/`high` when it is approved).

---

## Shipped (approved)

Both takes were approved and are now wired:

- **`title_keyart_a.png` → the boot splash.** Copied to `assets/menu/title_splash.png` (the
  `concepts/` folder is `.gdignore`d, so art there is never imported). `project.godot` now sets
  `application/boot_splash/image`, `fullsize = true`, and a near-black `bg_color`.
- **`menu_bg_c.png` → the main menu background.** Copied to `assets/menu/menu_background.png`.
  `scenes/main_menu.tscn` gained two nodes between `Background` and `Center`: `BackgroundArt`
  (a `TextureRect`, `STRETCH_KEEP_ASPECT_COVERED`, ignore-size) and `Scrim` (a 0.35 dark `ColorRect`
  that keeps the centred text legible over the art).
- **Menu UI styled.** `themes/menu_theme.tres` now dresses every `Button` and `LineEdit` — dark
  translucent panels, a violet edge that turns cyan on hover and amber on press, ALL-CAPS button
  labels, and a dark outline on the title/subtitle. In theme (corporate UI, cult accent) and legible
  over the art. Verified by running the menu.
- **Title logotype wired.** You picked the single-line format (take **b**). Its `vs` was muddled, so
  the format was **re-shot three ways** (`logotype_b2`, `b3`, `b4`); the cleanest, **`logotype_b2`**
  (dripping CULTISTS — a sharp red/cyan **VS** — chrome CAPITALISTS), is now the menu title: copied to
  `assets/menu/title_logotype.png` and swapped in for the old `Label` as a `TextureRect`. The VBox was
  widened from 320 to 460 so the lockup reads at full width. Verified in the running menu.
- **Caveat that survives:** the logotype is still a generated raster. The provider garbles lettering
  often (two of six takes were misspelled), so before shipping it should be **reproduced as real type**
  — a wax-drip treatment on a display face against a geometric sans — so it can never garble and can be
  localised.

---

## The one rule for this art

> **Show what the game is about AND only what the roadmap has confirmed.**

The menu must carry the **thesis** — a scrappy occult cult against sleek corporate warlords — and it
may show the **four districts that are confirmed** (Urban Center, the Write-Off Belt, the Unceded
Greenbelt, the Cooling Basin). It must **not** invent factions or content that is not confirmed. So
every take crams the same three things into one frame:

1. the cult's **Sanctum compound** in the warm foreground (the fidelity baseline);
2. the **city of districts** receding behind it — neon towers, rust-orange salvage, dark forest, pale
   chalk basin — i.e. the roadmap's biomes;
3. **corporate war machines** advancing (the enemy), cold and cyan against the warm compound.

When new content is confirmed, this art is re-shot or extended — the biomes are already in it, so the
frame is built to grow.

---

## Deliverable A — the title splash (`title_keyart_*`)

A dramatic, cinematic key art for a boot/title screen. Built to **grow**: the districts are in it now.

**Shared splash style block (verbatim):**
> Painterly realist game key art, cinematic wide composition with dramatic depth and atmosphere. The
> world of a scrappy Lovecraftian street cult — occupied salvaged urban infrastructure: low weathered
> pale-grey cast concrete, steel pipe and chain-link railing, rusted corrugated lean-to, frayed olive
> tarpaulin with sprayed white sigils, narrow red banners, caged sodium lamps glowing warm orange with
> a red halo, clusters of dripping votive candles — besieged by sleek, sponsor-branded cyberpunk
> corporate war machines: chrome and matte armour, white sponsor livery with generic abstract
> geometric logos, thin cyan LED strips, orange-and-black hazard chevrons. Warm golden sodium key
> light against cold cyan corporate glow, deep near-black shadows, wet reflective ground. Hand-built
> and improvised on one side, clean and mass-produced on the other. **NEVER medieval masonry, no real
> brands, no text or lettering anywhere.**

| File | Subject block (verbatim) | Composition / use |
|---|---|---|
| `title_keyart_a.png` | A dramatic wide establishing key art: in the foreground the cult's low hexagonal Sanctum compound, lit by sodium lamps and dripping candles, hooded figures and a tentacled idol-shrine under a rusted lean-to with tarp banners; rising and receding behind it the districts of one city as a single skyline — sleek neon glass towers, then rust-orange salvage stacks and freight yards, then a dark forest canopy, then a pale chalk-white drained basin fading into haze; sleek corporate mechs and drones advancing down a wet neon avenue toward the compound under cold cyan searchlights. | Close and detailed; the shrine is the anchor. Busy — needs a title bar or a scrim. |
| `title_keyart_b.png` | A dramatic wide key art from a low heroic angle: the cult's small hexagonal Sanctum compound in the foreground centre, its tentacled idol-shrine and candles burning warm against the dark, red banners snapping; a corridor of neon city towers on the left, a rust-orange salvage belt and freight road on the right, a dark forest edge and a pale chalk-white basin in the distance; a sleek corporate mech with a cyan searchlight looming over the compound at the frame edge. | Low heroic angle; a giant mech at the edge. Strong "outmatched but defiant". |
| `title_keyart_c.png` | A dramatic wide key art with the Sanctum small and defiant at the bottom centre, dwarfed by the scale of the corporate city above and around it — towering glass towers with glowing signage, sponsor screens, a corporate dreadnought silhouette; warm cult lamplight pooling at the compound while everything else is cold cyan; a rust-orange salvage strip, a dark forest edge and a pale chalk-white chalk basin visible along the horizon. | Scale contrast: small warm cult vs colossal cold city. Best for a big title lockup. |

---

## Deliverable B — the main-menu background (`menu_bg_*`)

A calmer plate that sits **behind the menu**, so it must respect the UI layout. Today the menu is a
**centred** `VBox`, which is the trap: art with detail in the centre is unreadable under text. Each
take solves it differently.

**Shared menu style block (verbatim):**
> Painterly realist game environment key art, cinematic wide composition with dramatic atmospheric
> depth and haze. The districts of the same city: sleek neon cyberpunk Urban Center glass towers; the
> rust-orange Write-Off Belt with salvage stacks and a buckled freight road; a dark Greenbelt forest
> canopy with a firebreak; a pale chalk-white drained Cooling Basin with rusted cooling works; and,
> warm and small, the cult's salvaged hexagonal Sanctum compound — low pale-grey cast concrete, steel
> pipe railing, rusted lean-to, olive tarps with white sigils, red banners, caged sodium lamps,
> dripping votive candles. Warm golden lamplight against cold cyan city glow, deep near-black
> shadows, wet reflective ground, atmospheric mist. **NEVER medieval masonry, no real brands, no text
> or lettering anywhere.**

| File | Subject block (verbatim) | UI layout it implies |
|---|---|---|
| `menu_bg_a.png` | A calm, atmospheric wide background plate for a game menu: an elevated wide vista of the city of districts at dusk — sleek neon Urban Center glass towers, the rust-orange Write-Off Belt salvage yards and freight road, a dark Greenbelt forest edge, and a pale chalk-white drained Cooling Basin — with the cult's small hexagonal Sanctum compound glowing warm in the lower foreground; open, uncluttered hazy sky across the upper half for a title and buttons to sit on; subdued contrast. | **Menu over the upper sky.** Districts read across the middle, sanctum low. |
| `menu_bg_b.png` | A calm wide background plate for a game menu with open negative space: a hazy dusk panorama where the left third is empty sky and atmosphere, and the right two-thirds carry the city of districts — neon towers, a rust-orange salvage belt, a dark forest edge and a pale chalk-white basin — receding into mist, with the cult's warm-lit compound low in the scene; cinematic depth, muted and dark enough for UI text to read over it. | **Left-anchored menu** (title + buttons in the empty left third). Requires re-anchoring the VBox. |
| `menu_bg_c.png` | A calm wide background plate for a game menu with a lot of empty dark space: a high, distant aerial view of the whole city of districts at night under a vast dark sky — neon Urban Center, rust-orange salvage belt, dark forest, pale chalk-white basin — a single warm glow from the cult's sanctum at the centre-bottom; most of the frame is deep atmospheric dark with tiny city lights, leaving ample room for a title and menu. | **Centred menu over the dark sky** — lowest contrast risk for text. |

---

## Title logotype (concepts — awaiting pick)

The background plates carry no lettering by design, so the name gets its own lockup. The shared idea
is the game's own split: the words sit in **two registers** — the cult half hand-painted and dripping
with wax, the corporate half clean, chrome and precise. Generated on a **transparent background** so a
chosen one drops straight onto the menu.

| File | Take |
|---|---|
| `logotype_a.png` | **Two-line lockup — recommended.** CULTISTS dripping black wax with a red-violet inner glow on top; a small **vs.** with a red-and-cyan split; CAPITALISTS in polished chrome with a cyan underline and a corporate diamond below. Reads instantly; the stacked "two worlds" *is* the thesis. |
| `logotype_b.png` | Single-line wordmark; the two lettering styles meet mid-line. The weakest of the three — the **vs** is muddled. |
| `logotype_c.png` | **Split emblem** — an occult eye sigil on the left half, a corporate mark on the right — with the wordmark beneath. Pick this if you want a **logo mark** for icons/store art, not just a wordmark. |

**Verbatim prompts:**

- `logotype_a` — *"A video game logotype on a fully transparent background: a two-line wordmark reading
  exactly CULTISTS on the top line and CAPITALISTS on the bottom line, with a small lowercase vs.
  centred between them. The top word CULTISTS is lettered in a rough hand-painted occult brush style,
  the strokes thick and dripping with black candle-wax, its edges lit faint red-violet from within, a
  gritty grease-pencil texture. The bottom word CAPITALISTS is lettered in a clean geometric corporate
  sans-serif, precise and sharp, in polished chrome-white with a thin glowing cyan underline and a
  small generic abstract geometric corporate diamond mark beside it. The two halves sit stacked like
  two different worlds meeting. Transparent background, no other text, generous margin."*
- `logotype_b` — *"A video game logotype wordmark on a fully transparent background, single line,
  reading exactly CULTISTS vs CAPITALISTS. The left half CULTISTS is lettered in a rough hand-painted
  occult brush style dripping black candle-wax with a faint red-violet inner glow; the right half
  CAPITALISTS is lettered in a clean geometric corporate sans-serif in polished chrome-white with a
  thin glowing cyan underline; the two lettering styles meet and transition across the middle of the
  line. Transparent background, no other text, generous margin."*
- `logotype_c` — *"A video game logo on a fully transparent background: a circular emblem split down
  the middle — the left half an occult eye sigil with dripping black wax and a red-violet glow, the
  right half a clean corporate abstract geometric mark in chrome and cyan — and beneath it a wordmark
  reading exactly CULTISTS vs CAPITALISTS, the first word in a hand-painted occult brush face with
  dripping black wax, the second in a clean corporate sans-serif in chrome-white. Transparent
  background, no other text, generous margin."*

**Caveat:** the image provider renders lettering unreliably; takes **a** and **c** came out spelled
correctly, **b** did not. Any chosen logotype should be checked letter-by-letter before shipping, and
the safe path for a production asset is to reproduce it as a real type treatment rather than ship the
generated raster.

### Single-line re-shoots (`logotype_b2` / `b3` / `b4`)

The chosen format is the **single line**, so take `b` was re-shot three ways to fix its `vs` — all
three spelled correctly, the difference being how the divider is drawn:

| File | Divider | Note |
|---|---|---|
| `logotype_b2.png` | a sharp **red/cyan split `vs`** | **chosen** — cleanest and most balanced; the split echoes the game's two halves. Now the menu title. |
| `logotype_b3.png` | a chrome `vs` | clean, but a large occult cross sits behind CULTISTS, which reads more religious than Lovecraftian. |
| `logotype_b4.png` | a bold **red/cyan diagonal slash** | the most dynamic; a heavier divider that dominates the line. |

**Prompts (verbatim):**

- `logotype_b2` — *"A video game logotype wordmark on a fully transparent background, a single
  horizontal line reading exactly CULTISTS vs CAPITALISTS, with the three parts clearly and correctly
  spelled and well separated. The left word CULTISTS is lettered in a rough hand-painted occult brush
  style, the strokes dripping with black candle-wax, a faint red-violet glow inside the letters. A
  small, clearly legible lowercase vs sits centred between the words with a sharp red-and-cyan split
  down its middle. The right word CAPITALISTS is lettered in a clean geometric corporate sans-serif in
  polished chrome-white with a thin glowing cyan underline. Transparent background, no other text,
  generous margin, wide banner composition."*
- `logotype_b3` — *"A video game logotype wordmark on a fully transparent background, a single
  horizontal line reading exactly CULTISTS vs CAPITALISTS. The left word CULTISTS is lettered in a
  rough hand-painted occult brush style dripping black candle-wax with a faint red-violet inner glow;
  then a clean, bold lowercase vs in bright chrome-white; then the word CAPITALISTS in a clean
  geometric corporate sans-serif in polished chrome-white with a thin glowing cyan underline. The
  three parts are separate and clearly spelled. Transparent background, no other text, generous
  margin, wide banner composition."*
- `logotype_b4` — *"A video game logotype wordmark on a fully transparent background, a single
  horizontal line reading exactly CULTISTS vs CAPITALISTS. The left word CULTISTS is lettered in a
  rough hand-painted occult brush style dripping black candle-wax with a faint red-violet glow;
  between the two words sits a sharp diagonal slash mark, red on its left half and cyan on its right
  half, standing in for versus; the right word CAPITALISTS is lettered in a clean geometric corporate
  sans-serif in polished chrome-white with a thin glowing cyan underline. Both words are clearly
  spelled and well separated. Transparent background, no other text, generous margin, wide banner
  composition."*

## If these are approved — implementation path

1. **Boot splash:** set `application/boot_splash/image` to the chosen plate (Godot wants a texture;
   keep it small). The full plate is for the *menu*, not the boot splash.
2. **Main menu:** replace the `Background` `ColorRect` in `scenes/main_menu.tscn` with a
   `TextureRect` (`stretch_mode = STRETCH_KEEP_ASPECT_COVERED`, full-rect anchors), art on top of a
   dark base so unusual aspect ratios never show a bare edge.
3. **Layout:** for `menu_bg_a` / `menu_bg_c`, keep the centred VBox and add a subtle scrim behind the
   text. For `menu_bg_b`, re-anchor the VBox to the left third.
4. **Roadmap honesty:** the plate shows only confirmed districts. When a new district is confirmed,
   re-shoot; the composition is built to grow rather than be rebuilt.