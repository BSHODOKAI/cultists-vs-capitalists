## ObjectiveBalanceData
##
## Resource container for Objective placement, claim and capture tunables, stored
## at res://data/objective_balance.tres per engineering conventions.
class_name ObjectiveBalanceData
extends Resource

## Sites created per completed path growth.
const SITES_PER_GROWTH: int = 1
## A tower within this hex distance of a site keeps it CLAIMED.
const CLAIM_RADIUS_HEXES: int = 2
## An enemy within this hex distance of an unclaimed site pushes it toward capture.
const CAPTURE_RADIUS_HEXES: int = 2
## Consecutive waves of enemy presence before an unclaimed site flips to CAPTURED.
const CAPTURE_WAVES_REQUIRED: int = 2
## Hex radius of a site's local EFFECT aura. Sites buff the cult (or, when captured,
## the enemy) only inside this radius, so ground matters and not just ownership.
## Kept equal to CLAIM_RADIUS_HEXES on purpose: a wider aura swallows most of the
## buildable band (sites spawn within 2 hexes of the path), which makes "local"
## indistinguishable from "global". Widen only with that in mind.
const AURA_RADIUS_HEXES: int = 2
## No site is placed before this wave, so the opening stays about tower placement.
const FIRST_OBJECTIVE_WAVE: int = 10
## Max sites alive at once (older captured sites are the interesting ones).
const MAX_SITES: int = 8

@export var sites_per_growth: int = SITES_PER_GROWTH
@export var claim_radius_hexes: int = CLAIM_RADIUS_HEXES
@export var capture_radius_hexes: int = CAPTURE_RADIUS_HEXES
@export var capture_waves_required: int = CAPTURE_WAVES_REQUIRED
@export var aura_radius_hexes: int = AURA_RADIUS_HEXES
@export var first_objective_wave: int = FIRST_OBJECTIVE_WAVE
@export var max_sites: int = MAX_SITES