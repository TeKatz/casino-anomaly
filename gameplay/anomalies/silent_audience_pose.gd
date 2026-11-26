extends RefCounted
## Snapshot and pose-blend the licensed rig without moving animated roots
## into tables. Different bone timing groups produce varied rise silhouettes.
static func snapshot(rig: Skeleton3D) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for i in range(rig.get_bone_count()):
        result.append({"p":rig.get_bone_pose_position(i),
            "q":rig.get_bone_pose_rotation(i),
            "s":rig.get_bone_pose_scale(i)})
    return result


static func restore(rig: Skeleton3D, state: Array[Dictionary]) -> void:
    for i in range(mini(rig.get_bone_count(),state.size())):
        rig.set_bone_pose_position(i,state[i]["p"])
        rig.set_bone_pose_rotation(i,state[i]["q"])
        rig.set_bone_pose_scale(i,state[i]["s"])


static func blend(rig: Skeleton3D, a: Array[Dictionary], b: Array[Dictionary],
        fraction: float, personality: int) -> void:
    var p := clampf(fraction,0.0,1.0)
    for i in range(mini(rig.get_bone_count(),mini(a.size(),b.size()))):
        var name := rig.get_bone_name(i).to_lower()
        var t := p
        # One guest leans forward before straightening. Another stretches
        # the legs first. Another lifts the head early. None runs the same
        # six-second canned sitting_end clip in lockstep.
        if personality == 0:
            if "spine" in name or "chest" in name: t = smoothstep(0.16,0.84,p)
            if "head" in name or "neck" in name: t = smoothstep(0.08,0.78,p)
            if "leg" in name or "foot" in name: t = smoothstep(0.27,0.95,p)
        elif personality == 1:
            if "spine" in name or "chest" in name: t = smoothstep(0.28,0.96,p)
            if "leg" in name or "foot" in name: t = smoothstep(0.04,0.74,p)
            if "arm" in name or "hand" in name: t = smoothstep(0.25,0.92,p)
        else:
            if "spine" in name or "chest" in name: t = smoothstep(0.05,0.73,p)
            if "head" in name or "neck" in name: t = smoothstep(0.26,0.98,p)
            if "arm" in name or "hand" in name: t = smoothstep(0.10,0.80,p)
        var start: Dictionary = a[i]
        var finish: Dictionary = b[i]
        rig.set_bone_pose_position(i,(start["p"] as Vector3).lerp(finish["p"] as Vector3,t))
        rig.set_bone_pose_rotation(i,(start["q"] as Quaternion).slerp(finish["q"] as Quaternion,t))
        rig.set_bone_pose_scale(i,(start["s"] as Vector3).lerp(finish["s"] as Vector3,t))
