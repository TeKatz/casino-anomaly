extends SceneTree
## Regression: selecting the same profile twice or returning from another
## overlay must never grow either side card beyond its fixed preview height.
const MENU = preload("res://menu.tscn")

var temporary_slot := 0
var original_slot := 0


func _initialize() -> void:
    call_deferred("_run")


func _restore_profile() -> void:
    var profiles := root.get_node_or_null("ProfileManager")
    if profiles == null:
        return
    if temporary_slot > 0:
        profiles.delete_profile(temporary_slot)
        temporary_slot = 0
    if original_slot > 0 and profiles.profile_exists(original_slot):
        profiles.select_profile(original_slot)


func _fail(reason: String) -> void:
    _restore_profile()
    push_error("Profile side-card layout QA: " + reason)
    quit(1)


func _check_cards(side: Control, label: String) -> bool:
    var height: float = minf(535.0, maxf(255.0, side.size.y - 64.0))
    var left := side.get_node_or_null("StatisticsCard") as PanelContainer
    var right := side.get_node_or_null("ArchiveCard") as PanelContainer
    if left == null or right == null or not left.visible or not right.visible:
        push_error(label + ": side previews are not visible")
        return false
    for card in [left, right]:
        if absf(card.size.y - height) > 1.5:
            push_error("%s: %s enlarged from %.1f to %.1f" % [
                label, card.name, height, card.size.y])
            return false
        if not card.has_node("MarginContainer/VBoxContainer/PreviewScroll"):
            push_error(label + ": preview body needs bounded scrollable content")
            return false
    var picker := side.get("main_panel") as Control
    var central := picker.get_global_rect()
    var bounds := side.get_global_rect()
    var left_rect := left.get_global_rect()
    var right_rect := right.get_global_rect()
    if left_rect.end.x > central.position.x or right_rect.position.x < central.end.x:
        push_error(label + ": preview overlaps central profile panel")
        return false
    if not bounds.grow(1.0).encloses(left_rect) or not bounds.grow(1.0).encloses(right_rect):
        push_error(label + ": preview extends outside overlay")
        return false
    if absf(left_rect.get_center().y - central.get_center().y) > 2.0 or absf(right_rect.get_center().y - central.get_center().y) > 2.0:
        push_error(label + ": preview not vertically aligned with profile panel")
        return false
    return true


func _run() -> void:
    root.size = Vector2i(1650, 930)
    var profiles := root.get_node_or_null("ProfileManager")
    if profiles == null:
        _fail("ProfileManager autoload missing")
        return
    original_slot = int(profiles.active_slot)
    var selected := 0
    for slot in range(1, 6):
        if profiles.profile_exists(slot):
            selected = slot
            break
    if selected == 0:
        selected = 5
        if not profiles.create_profile(selected, "Side card layout QA"):
            _fail("Could not prepare QA test profile")
            return
        temporary_slot = selected

    var menu := MENU.instantiate() as Control
    root.add_child(menu)
    await process_frame
    menu.call("_on_play")
    await process_frame
    var picker := menu.get("profile_panel") as Control
    var side := menu.get("profile_side_cards") as Control
    if picker == null or side == null:
        _fail("Profile overlay missing its preview controls")
        return

    picker.call("_select_slot", selected)
    await process_frame
    await process_frame
    if not _check_cards(side, "First selection"):
        _fail("Side previews expanded on first selection")
        return

    picker.call("_select_slot", selected)
    await process_frame
    await process_frame
    if not _check_cards(side, "Second click"):
        _fail("Repeated profile selection changes side-card sizes")
        return

    menu.call("_open_profile_archive", "stats")
    await process_frame
    menu.call("_back_from_profile_archive")
    await process_frame
    await process_frame
    if not _check_cards(side, "Return from archive"):
        _fail("Restoring the profile menu changes side-card sizes")
        return

    # The preview panels must also fit a shorter 720p viewport after the
    # user changes resolution without recreating the menu.
    root.size = Vector2i(1280, 720)
    await process_frame
    await process_frame
    if not _check_cards(side, "720p resize"):
        _fail("Profile preview panels overflow after viewport resizing")
        return

    # Recreate the main menu as after quitting an in-game run, and open
    # Play immediately, before CenterContainer has settled its first sort.
    menu.queue_free()
    await process_frame
    for cycle in range(3):
        menu = MENU.instantiate() as Control
        root.add_child(menu)
        menu.call("_on_play")
        picker = menu.get("profile_panel") as Control
        side = menu.get("profile_side_cards") as Control
        picker.call("_select_slot", selected)
        # Resize mid-animation, including an aspect-ratio change. The
        # previous absolute-position tween kept obsolete destinations.
        root.size = Vector2i(1650, 930) if cycle % 2 == 0 else Vector2i(1280, 720)
        await process_frame
        root.size = Vector2i(1440, 900) if cycle % 2 == 0 else Vector2i(1600, 900)
        await create_timer(0.42).timeout
        if not _check_cards(side, "Fresh menu / resize during slide %d" % cycle):
            _fail("Side previews kept stale animation targets")
            return
        menu.call("_hide_overlay", menu.get("profile_overlay"))
        menu.call("_on_play")
        await create_timer(0.42).timeout
        if not _check_cards(side, "Interrupted close / reopen %d" % cycle):
            _fail("Side previews did not reset after rapid reopening")
            return
        menu.queue_free()
        await process_frame
    _restore_profile()
    print("Casino Anomaly profile side-card layout QA PASS")
    quit(0)
