# Four selected Sketchfab props for Casino Anomaly

**No fireplace.** All four official model ZIPs are now present on `dev`.
Sketchfab requires a signed-in account for official downloadable geometry.
All four original glTF ZIPs are committed. The GitHub Action imports the\noriginal geometry and full texture sets before the Windows build.

- `wall_light.zip` — Wall Light by [Lucas Garnier](https://sketchfab.com/3d-models/wall-light-c723fa0a1ac3478790192acdb39161b0) (CC BY 4.0). Replaces four simple wall-sconce meshes, retaining existing lights.
- `vintage_gramophone.zip` — Vintage Gramophone by [Maxim Mavrichev](https://sketchfab.com/3d-models/vintage-gramophone-a7508a4233a344008029d21a2f0024bd) (CC BY 4.0). Right-hand alcove, on a new wooden cabinet.
- `books_with_magnifier.zip` — Books with magnifier by [shuvalov.di](https://sketchfab.com/3d-models/books-with-magnifier-cc153ce6258b4e538d9fc7da5b5d0fe4). Replaces the paper register on the reception desk.
- `desk_bell.zip` — Desk Bell by [ClintonAbbott.Art](https://sketchfab.com/3d-models/desk-bell-cc21b304c4bb4750bdde7a8fb538b116) (CC BY 4.0). Replaces the handmade desk bell.

**Books license:** The owner confirmed the original Sketchfab page lists
**Creative Commons Attribution-ShareAlike (CC BY-SA 4.0)**. The supplied
`books_with_magnifier.license.txt` records the author, source, full license
link, attribution and asset modification notice. Adapted versions of this
model must retain compatible ShareAlike licensing. The license does not
automatically make an independent game combining it a CC BY-SA adaptation.

The downloaded, intact official ZIP archives are located in this folder. Each archive must be below 24 MiB (GitHub
browser limit). The CI importer safely extracts glTF models and PBR textures
into `models/tutorial_user/<id>/`. In the Godot editor and Windows export,
`gameplay/tutorial_sketchfab_props.gd` automatically fits available models
to the intended locations. Existing placeholders remain until replaced with
**real original meshes**, and no furniture is allowed into the middle aisle.
