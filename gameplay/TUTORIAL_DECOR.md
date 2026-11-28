# Tutorial room – intentional set dressing

The original 7.4 × 9.5 m introductory room contains a solid left-wall
reception desk, a clear center aisle, a front exit door and a spawn at
(0, 1.02, 2.7). The decoration is **saved in
`gameplay/tutorial_decor.tscn`**, instanced from
`gameplay/tutorial.tscn`. Open that subscene in the Godot editor to edit
individual props. It is not a runtime random decorator.

## Visual storytelling / architectural zones

- **Entrance sightline:** a burgundy jacquard PBR runner directs the player
  toward the far door, with two narrow metal bindings above the carpet plane.
  The central path remains free and the door's E interaction is unchanged.
- **Reception (left):** the existing physical reception desk is retained.
  A bound guest ledger and service bell occupy its remote ends, leaving the
  Croupier's face and interaction point unobstructed. Existing wood and brass
  surfaces match these small objects.
- **Waiting niche (right rear):** a genuine textured Poly Haven sofa faces
  the room beside a scaled wooden table, brass tray and warm glass ornament.
  Each imported mesh is ground-normalized from its actual glTF coordinates,
  not visually guessed. A conservative collider follows each footprint.
- **Gallery (side walls):** woven fabric above textured wood wainscoting,
  dado rail and crown moulding; raised pilasters articulate bays rather than
  randomly distributing objects. The two framed pictures are mounted against
  fitted backing plates. A small marble bust stands on a wood-and-brass plinth
  near the exit, outside the door's approach lane.
- **Lighting:** an imported textured chandelier is suspended from the real
  ceiling, supported by a rod. Four low-energy, non-shadowed sconces provide
  warmth on the right wall and flanking the far door.

## Exact physical constraints

The authored wall centerlines are x=±3.70 and z=±4.72. Structural surfaces
face the player at x=±3.575, z=−4.595, z=+4.595. Decorative infills are
offset inward with >1 cm air gap from coplanar structural faces. Raised
mouldings and their backings deliberately interlock at different depths
rather than duplicating entire surfaces.

Floor top is y=0; runner bottom is y=.002, sofa/table mesh bottoms are within
4 mm of the floor, ledger bottom at y=1.147 on reception top y=1.144, and the
marble bust is y=.932 above plinth top y=.9305. Imported chandelier top is
below ceiling underside y=4.02, with its mounting rod extending into the
ceiling. Sconces are above normal eye level and use short ranges.

Every new furniture collider remains beyond x=1.3 m, keeping the full
walkable aisle toward the start door open. No new collisions surround the
Croupier or interrupt the reception enclosure.

The scene reuses existing CC0 Poly Haven model textures and CC0/ambientCG
surface materials already documented in `ASSET_CREDITS.md`. Geometry,
floor support, wall clearances and imported mesh extents are validated by
`tests/tutorial_dressing_qa.gd`; the development workflow runs it on
Windows with Godot 4.5.1.


## Requested artist-supplied props — optional Sketchfab imports

The following **real source models** are not in the repository until their
original glTF ZIPs are uploaded. There is no fireplace. The dedicated
`UserSelectedProps` node loads only existing meshes. Until a corresponding
model exists, the procedural wall lights, register and desk bell remain visible.
Once available:

- Wall Light: four carefully bounded mounts, retaining the original
  low-intensity lights but hiding their simple placeholder geometry
- Desk Bell: replaces the small brass reception bell on the counter
- Books with magnifier: replaces the basic guest register at the other end
- Vintage Gramophone: right wall, on a small wood-finished cabinet with a
  grounded collider, outside the central passage

Objects are fit from their *actual imported 3D AABB*, so none rely on
arbitrary default Sketchfab scale. The importer and verified sources are
documented in `source_assets/tutorial_assets_drop/README.md`. The exact models and their
PBR textures are not yet bundled in this commit.

## Editing models in Godot (persisted, not runtime-generated)

The old `@tool` script previously created the Sketchfab lamp, gramophone,
book and bell models after entering the scene. Such unsaved children did not
appear as normal selectable scene nodes. The first CI import now runs
`tools/bake_tutorial_editor_scene.gd` **once**, saves the exact original
model transforms and gramophone cabinet into
`gameplay/tutorial_decor.tscn`, marks both old Poly Haven and new Sketchfab
GLTF instances **Editable Children**, and removes the dynamic script.
The file is committed to `dev`; subsequent builds never regenerate it and
therefore do not overwrite changes made with the editor.

Open `gameplay/tutorial.tscn` in Godot, expand `Decoration`, then
`UserSelectedProps`. Every individual model can be selected, moved,
rotated or rescaled with the 3D handles. Select the GLTF instance to edit its
transform or expand its editable children to override mesh materials.
Alternatively open `gameplay/tutorial_decor.tscn` directly to work on every
wall panel, rug, table, bust, painting, light and collision object.
The tutorial root explicitly enables editable children for the decoration
and CroupierStation subscenes. If changing physics-relevant furniture,
adjust its collision shape alongside the visible model.
