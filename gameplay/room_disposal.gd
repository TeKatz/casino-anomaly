extends RefCounted
## Only retired, inaccessible halls enter this queue. Delete bottom-up so
## one free() cannot recursively destroy the complete casino in one frame.
const Trace = preload("res://gameplay/streaming_trace.gd")
const BUDGET_US := 2500
const MAX_NODES_PER_FRAME := 96
var _roots: Array[Node] = []
var _stack: Array[Node] = []

func enqueue(hall: Node3D) -> void:
    hall.hide()
    hall.process_mode = Node.PROCESS_MODE_DISABLED
    _roots.append(hall)
    _stack.append(hall)

func advance() -> void:
    if _stack.is_empty():
        return
    var started := Time.get_ticks_usec()
    var trace_start := Trace.begin()
    var count := 0
    while not _stack.is_empty():
        var node: Node = _stack.back()
        if not is_instance_valid(node):
            _stack.pop_back()
        elif node.get_child_count(true) > 0:
            _stack.append(node.get_child(0, true))
        else:
            _stack.pop_back()
            _roots.erase(node)
            node.free()
            count += 1
        if count >= MAX_NODES_PER_FRAME or Time.get_ticks_usec() - started >= BUDGET_US:
            break
    Trace.finish("casino.dispose_batch", trace_start)

func clear() -> void:
    for root in _roots:
        if is_instance_valid(root):
            root.queue_free()
    _roots.clear()
    _stack.clear()
