## ObjectiveLibrary
##
## Loads ObjectiveData resources from res://data/objectives/ and the
## ObjectiveBalanceData tunables from res://data/objective_balance.tres.
class_name ObjectiveLibrary
extends RefCounted

const OBJECTIVES_DIR: String = "res://data/objectives"
const BALANCE_PATH: String = "res://data/objective_balance.tres"


## Loads every .tres ObjectiveData in OBJECTIVES_DIR, sorted by filename so the
## catalog order is deterministic across platforms.
static func load_all() -> Array[ObjectiveData]:
	var out: Array[ObjectiveData] = []
	var dir: DirAccess = DirAccess.open(OBJECTIVES_DIR)
	if dir == null:
		return out
	var names: Array[String] = []
	dir.list_dir_begin()
	var f: String = dir.get_next()
	while not f.is_empty():
		if not dir.current_is_dir() and f.ends_with(".tres"):
			names.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	names.sort()
	for n: String in names:
		var d := load("%s/%s" % [OBJECTIVES_DIR, n]) as ObjectiveData
		if d != null:
			out.append(d)
	return out


static func load_balance() -> ObjectiveBalanceData:
	var b := load(BALANCE_PATH) as ObjectiveBalanceData
	if b == null:
		b = ObjectiveBalanceData.new()
	return b