extends RefCounted
## Keep the original PackedScene and node identities. Split the attachment
## of known, self-contained room sections; never instantiate render nodes
## on a worker thread or change the editor's authored source.
const Trace = preload("res://gameplay/streaming_trace.gd")
const SECTIONS := ["Architecture", "RedCarpet", "SlotMachines", "GamingTables",
    "CornerBar", "Lounge", "Decor", "Lighting", "ModelInteriors",
    "SketchfabFurniture/EditableImportedModels", "StreamingPortals", "CasinoAtmosphere"]
const BUDGET_US := 2500
const MAX_ATTACH_JOBS := 12

var _root: Node3D
var _jobs: Array[Dictionary] = []
var _cursor := 0
var _section_cursor := 0
var _split_parent: Node
var _split_children: Array[Node] = []
var _split_cursor := 0
var _attached := false

func begin(hall: Node3D) -> void:
    _root = hall
    _root.set_meta("_streaming_assembly", true)

func _collect_owners(node: Node, owners: Dictionary) -> void:
    if node.owner != null:
        owners[node] = node.owner
    for child in node.get_children(true):
        _collect_owners(child, owners)

# Split individual subtrees rather than detaching a complete large
# section in one pass. Keep the authored sibling order in the job list.
func _advance_split(immediate: bool) -> bool:
    var started := Time.get_ticks_usec()
    var count := 0
    while _section_cursor < SECTIONS.size():
        if _split_parent == null:
            _split_parent = _root.get_node_or_null(SECTIONS[_section_cursor])
            if _split_parent == null:
                _section_cursor += 1
                continue
            _split_children = _split_parent.get_children()
            _split_cursor = 0
        if _split_cursor >= _split_children.size():
            _split_children.clear()
            _split_parent = null
            _section_cursor += 1
            continue
        var child := _split_children[_split_cursor]
        var owners: Dictionary = {}
        _collect_owners(child, owners)
        _split_parent.remove_child(child)
        _jobs.append({"parent": _split_parent, "node": child, "owners": owners})
        _split_cursor += 1
        count += 1
        if not immediate and (count >= MAX_ATTACH_JOBS or Time.get_ticks_usec() - started >= BUDGET_US):
            return false
    return true

func advance(tree_root: Node, immediate: bool = false) -> bool:
    var started := Time.get_ticks_usec()
    var trace_start := Trace.begin()
    if _section_cursor < SECTIONS.size():
        var split_done := _advance_split(immediate)
        Trace.finish("casino.split_sections", trace_start)
        if not split_done or not immediate:
            return false
        trace_start = Trace.begin()
    if not _attached:
        tree_root.add_child(_root)
        _attached = true
        Trace.finish("casino.attach_shell", trace_start)
        if not immediate:
            return false
    started = Time.get_ticks_usec()
    trace_start = Trace.begin()
    var count := 0
    while _cursor < _jobs.size():
        var job: Dictionary = _jobs[_cursor]
        var parent: Node = job["parent"]
        var child: Node = job["node"]
        parent.add_child(child)
        # remove_child clears owners pointing outside a detached subtree.
        # Restore the authored ownership before any room-level population.
        var owners: Dictionary = job["owners"]
        for item in owners:
            var node: Node = item
            var original: Node = owners[item]
            if is_instance_valid(node) and is_instance_valid(original) and original.is_ancestor_of(node):
                if node.owner != original:
                    node.owner = original
        _cursor += 1
        count += 1
        if not immediate and (count >= MAX_ATTACH_JOBS or Time.get_ticks_usec() - started >= BUDGET_US):
            break
    Trace.finish("casino.attach_chunk", trace_start)
    if _cursor < _jobs.size():
        return false
    _jobs.clear()
    return true

func cancel() -> void:
    # Attached children belong to the hall; only free detached jobs here.
    for i in range(_cursor, _jobs.size()):
        var child: Node = _jobs[i]["node"]
        if is_instance_valid(child) and child.get_parent() == null:
            child.free()
    _jobs.clear()
    _split_children.clear()
    _split_parent = null
    _root = null
