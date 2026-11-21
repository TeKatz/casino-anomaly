# Casino Anomaly

Independent Godot 4.5.1 first-person prototype with a separate Windows updater and the dedicated [Development release](https://github.com/TeKatz/casino-anomaly/releases/tag/development).

## Welcome desk and first-room tutorial

The separately authored start room now includes a small casino counter and a
stationary croupier on the left of the unobstructed route to the exit door.
Looking at the croupier from the customer side and pressing E opens four
short bilingual dialogue options covering the first normal hall, the
ANOMALY/NORMAL exits, the 12-correct streak goal and subtle casino lore.
Talk is optional; E at the existing door still begins the run.

The counter and proxy are editable in gameplay/croupier_station.tscn.
The selected character is the CC BY 4.0 Sketchfab Business Man by
manoeldarochadeoliveira. Its original, checksum-pinned ZIP belongs at
sketchfab_drop/business_man.zip and is safely imported by
tools/import_croupier_asset.py during the Development build. Godot places
the glTF at CroupierStation/CharacterPivot/ModelAnchor, hides the proxy
automatically, and uses the supplied idle and talking animations. The
local proxy remains only until the source archive is uploaded.
Conversations lock movement and camera look, release the mouse, and close
with Esc without opening the global pause menu. Saves are unchanged.

## Room design pass

The current walkable hall is **L-shaped**: from the entrance it leads straight past slot-machine groups, turns **left** at the illuminated, wrap-around corner bar, and continues into the second wing, now twice as long after the first visual playtest, with more roulette/blackjack tables, multiple lounge groups and decorative exit doors. The counter is now one continuous rounded-corner L shape, with seating on both sides; the standalone slot machine previously blocking the bar sightline was relocated. The red-and-gold bordered carpet forms an uninterrupted route through the corner. Players can step off the carpet to inspect furniture. This is a first spatial and lighting pass using handcrafted primitive placeholder meshes, not final models or anomaly gameplay.

The wooden floor retains the CC0 Poly Haven [Oak Wood Planks](https://polyhaven.com/a/oak_wood_planks) PBR material. The runner uses the CC0 [Quatrefoil Jacquard Fabric](https://polyhaven.com/a/quatrefoil_jacquard_fabric) PBR maps, with a muted finish and a dark/gold border. Original source maps and their pinned SHA-256 values are managed by `tools/ensure_assets.py`.

## Playtest and controls

Download and fully extract `casino-anomaly-win-x64.zip` from the Development release. Start `CasinoAnomaly.exe`, then select **Raum betreten**. WASD moves, mouse looks, and Esc returns to the menu. Exit doors are decorative for now; there is no anomaly detection or round progression.

The main menu checks this repo's Development channel for updates. It runs a separate Windows updater which verifies package SHA-256 and size, stages the download, and attempts recovery after failures. Game and updater are independent of Blackjack Casino. Save data belongs in the Godot user-data directory outside the install folder.

`dev` publishes Development releases; `main` remains the reviewed integration baseline. Verified Windows builds use Godot 4.5.1, .NET 10 for the updater, and original CC0 asset sources. No checkout, terminal, editor or asset import is required for playtesting.

## Aktuelles Bedienungs- und Übergangsupdate

Die Casinoflur-Ausgänge sind jetzt **links „ANOMALIE“** und **rechts „NORMAL“** beschriftet. Die alten goldenen Platzhalterstreben wurden zur Laufzeit durch echte Holzrahmen aus dem bereits vorhandenen `WoodWainscoting`-Material ersetzt. Der Eingang des nächsten Flurs besitzt eine bündige, seitlich und oben geschlossene Anschlussmanschette (`EntrySleeve`); der vorige Gang bleibt nach dem Entladen als `ArrivalConnector` erhalten. Die Türinnenseiten wurden gegeneinander versetzt, damit sich keine Flächen überlagern. Die eigentliche `main.tscn` bleibt unverändert.

**WASD richtet sich an der globalen Kamera aus**, sodass der Bewegungsvektor durch gedrehte Elternräume nicht mehr invertiert wird. Mit **ESC** pausiert man nun den aktuellen Run, statt ihn zu verlassen. **Spiel fortsetzen** bringt die Spielfigur ohne Reload zurück. Im Pause-Menü sind auch Neues Spiel, Spielstand laden, Hauptmenü und Beenden verfügbar; folgenschwere Optionen werden bestätigt.

**Einstellungen** stehen im Haupt- und Pause-Menü bereit, mit vier als Buttons implementierten, hervorgehobenen Tabs:
- **Grafik:** Fenstermodus, Auflösung, VSync, FPS-Grenze, TAA und 3D-Auflösungsskalierung
- **Audio:** Gesamt-, Musik-, Effekt- und UI-Buslautstärke (für die zukünftigen Streams bereits vorbereitete Busse)
- **Steuerung:** Mausempfindlichkeit, vertikale Umkehr, Sprinten halten/umschalten
- **Gameplay:** FOV, Kamerabewegung und HUD-Sichtbarkeit

Alle Optionen werden sofort angewandt und in `user://casino_settings.cfg` gespeichert – getrennt vom Spielstand. Die Einstellungen können geändert werden, während die Spielwelt angehalten ist.

## Spielbarer Anomalie-Loop mit nahtlosem Raum-Streaming

**Neues Spiel** führt zuerst in den separat editierbaren Tutorialraum (`gameplay/tutorial.tscn`). Dort mit **E** durch die Tür gehen. Danach läuft das Spiel **ohne weitere Interaktionstaste**: Am westlichen Ende des L-förmigen Casinos führt die **linke, nun offene Ausgangspassage** zu „Anomalie“, die **rechte** zu „normal“. Die ursprünglichen Schilder und goldenen Rahmen werden weiterverwendet, die vorher durchgehende Wand und die dekorativen geschlossenen Türfüllungen werden nur zur Laufzeit passend geöffnet.

### Abgewinkelte, gegen Zurücklaufen gesicherte Verbindungsgänge

- Bereits vor dem Exit wird eine zweite `main.tscn`-Instanz vorbereitet; ihre teuren Materialien/Modelle werden gemeinsam benutzt. Der nächste Raum liegt **hinter einer massiven Ecke** und ist von den Exit-Türen aus nicht mehr sichtbar.
- Der **linke Ausgang** führt zunächst geradeaus, dann mit einem Knick **nach links** (+Z im ursprünglichen Casino). Der **rechte** führt mit einem Knick **nach rechts** (−Z). Beide Übergänge besitzen einen eigenen Boden, Wände, Decke, Licht und physikalische Kollisionen.
- Sobald man tief genug durch einen Ausgang gegangen ist, wird links/rechts bewertet. **Beide Rückwege werden hinter dem Spieler mit festen Sperrwänden verschlossen**; ein späterer Wechsel zum anderen Ausgang ist ausgeschlossen.
- Nach dem Abbiegen schließt der begehbare Gang exakt an den Eingang der vorbereiteten nächsten Rauminstanz an. Diese übernimmt **dieselbe Spieler- und Kamera-Instanz** in unveränderten Weltkoordinaten, ohne Ladebildschirm, Schwarzblende oder Teleport.
- Der alte Casinoraum wird danach freigegeben. **Der bereits durchquerte, am anderen Ende versperrte Verbindungsgang bleibt aber an der neuen Szene erhalten**, sodass man beim Zurückschauen nicht mehr die Außenseite des entladenen Raums sehen kann.
- Maximal zwei vollständige Casinoräume werden gleichzeitig gehalten. Beim Weiterlaufen wird derselbe Vorgang in den bereits gedrehten Koordinaten erneut durchgeführt.

Alle Wände, Sperren und Verbindungen existieren nur zur Laufzeit. **Die manuell gestaltete `main.tscn` bleibt unverändert.**


Die provisorischen drei Test-Anomalien verändern ausschließlich vorhandene 3D-Schilder und werden pro Durchlauf zurückgesetzt. Weitere Anomalien werden zentral in `gameplay/anomaly_catalog.gd` registriert; neue Effekt-Arten können eigene Handler unter `gameplay/anomalies/` implementieren. Das private, ausschließlich über **G** im laufenden Spiel aufrufbare Entwicklerfenster listet automatisch alle registrierten Anomalien mit Suche und Kategorien. Eine Auswahl erzwingt die Anomalie **einmalig im nächsten Raum**, selbst wenn dieser bereits vorgeladen wurde. Es gibt zusätzliche Aktionen für einen garantiert normalen oder wieder zufälligen nächsten Raum. Während das Entwicklerfenster offen ist, wird das Spiel pausiert. Diese Testauswahl wird nicht im Spielstand gespeichert und verändert niemals den garantiert normalen allerersten Casinoraum. Das Werkzeug erscheint nicht in der Steuerungsübersicht oder in den Einstellungen.

Der Prototyp verlangt **zwölf richtige Entscheidungen hintereinander**. Der **erste Casinoraum eines neuen Spiels enthält niemals eine Anomalie** und dient als sichere Referenz. Eine falsche Entscheidung setzt den Fortschritt auf **0** zurück, aber nicht den Spielstand; spätere Räume können auch bei Fortschritt 0 Anomalien enthalten. Die aktuelle Stufe erscheint als **emissive 3D-Neonzahl mittig an der Wand zwischen den beiden Ausgängen** (westlicher Casinoflügel, nahe X = −45,94 / Y = 4,45 / Z = −6,68), nicht als Bildschirm-HUD. Die Nummer ist auch ohne aktiven Spielstand in der Godot-Szenenvorschau sichtbar. Auch der Start-Hinweis hängt direkt an der Tür; beim Sieg betritt man ohne Überblendung den finalen Raum mit der leuchtenden **12**. Die laufende Runde wird unter `user://anomaly_run.cfg` gespeichert. Beim Fortsetzen startet man am Beginn des aktuellen Durchlaufs, nicht mitten im Übergang.

**Für Leveldesign wichtig:** `main.tscn` bleibt unverändert und vollständig im Godot-Editor bearbeitbar. `gameplay/stream_portals.gd` erzeugt die Öffnungen, Boden-, Decken- und Wandsegmente der Übergänge **nur im laufenden Spiel**. Für spätere grafische Gestaltung der Übergänge können wir daraus eigene `.tscn`-Szenen machen, ohne die Spiellogik zu ändern. Die Streaming- und Handoff-Logik liegt in `gameplay/loop_controller.gd`.

**Performance:** Kurzzeitig leben zwei große Hallen gleichzeitig; deshalb wird die zweite bereits vor dem Ausgang vorbereitet. Auf schwächeren PCs kann das erste Instanziieren noch einen kurzen Hänger verursachen. Diesen optimieren wir nach dem ersten visuellen Playtest mit Profilerwerten, statt zusätzliche Modelle einzubauen.

## Poly Haven interior pass

The next development pass loads **10 original CC0 Poly Haven 3D models** as reusable imported glTF scenes: both chandeliers, brass candleholders, marble bust, framed painting, CCTV camera, wine bottles, round bar chairs, coffee cart and wooden cabinet. They are integrated into the existing L-shaped hall and the wraparound corner bar, with low-cost non-shadow-casting practical lights, basic pedestrian collision for furniture and data-driven automatic alignment. Imported models use original source geometry and mostly 1K PBR texture maps to keep performance and download size reasonable. Asset manifests and SHA-256 checks are stored under `models/`, with licensing recorded in [ASSET_CREDITS.md](ASSET_CREDITS.md). Further visual tweaking will follow on-device playtests.

## Interior visual QA pass

Fixed seven issues from in-game screenshots: (1) both marble busts face the walkable hall; (2) stools are taller and all have matching burgundy upholstery; (3) grouped labelled bottles were removed from the customer-facing counter and moved to a dedicated shelf spot; (4) coffee cart rotated to face the room; (5) the wide donor sideboard rests on a wood base and has geometry-sized collision; (6) floor meshes now generate tangents required by their PBR normalmaps, restoring proper wood/jacquard lighting, with a subtle burgundy lift and more legible textile pattern; (7) individual tall candleholders are extracted from the three-piece glTF, with only one larger candlestick per table. No new third-party assets were added.

## Spatial QA pass (after dev.10)

The player-reported defects were fixed in the scene itself: no procedural stools behind the Poly Haven bar stools, greater spacing at the L-shaped counter, the bar and its colliders shifted away from the wall pilasters, physical collision on every architectural pillar, coffee cart in a free wall bay, topiary separated from the sofas, and no luminous spheres on lounge tables. The previously disabled ambient-light source has been replaced with color ambient lighting; both material meshes now render from either side. A new spatial regression test validates floor materials, pillar bodies, furniture spacing and lighting before release.

## Sketchfab casino objects (feature branch)

The uploaded models have been audited; the four original Sketchfab glTF
archives include CC BY 4.0 license files and author attribution. For the
first pass, the scene attempts to replace three roulette-table prototypes,
one blackjack table and one retro slot-machine prototype; the poker set
is reduced to a compact, approximately 27k-triangle cards/chips/dice display.

To complete the binary upload to GitHub, place the four verified, compressed
ZIP files for the four in-game props in `sketchfab_drop/` on
`feature/sketchfab-casino-assets`. They are individually under the 25 MiB
GitHub web-upload limit. Checksums are pinned in `catalog.json`.
The CI workflow extracts them before Godot import; no Godot authoring or
manual asset processing is required. The `dev` release workflow is not
modified until this feature branch is validated and merged.

## Room material and casino furniture pass

After the first Sketchfab playtest, the retro slot has a purpose-built raised
mahogany platform and collision. The roulette download is just a roulette WHEEL;
each wheel is now scaled to approximately a 1 m diameter and mounted on a
custom 3.5 m mahogany table with a green betting felt/grid and top collision.
The three roulette replacements preserve the existing main corridor clearance.

The lower wall is covered by Poly Haven **Wooden Panels** (CC0); the upper
wall by the olive-green woven **Book Pattern** material (CC0); the ceiling by
**Roof Planks** (CC0). All have diffuse, roughness and OpenGL normal maps.
The long wall and ceiling meshes repeat their UVs in world-proportional steps
rather than stretching one image over the entire room. Existing gold trim,
pillars and collisions remain, and the Oak floor and Jacquard runner are unchanged.

`tools/ensure_assets.py` pins all new CC0 maps on first verified download;
`tests/architecture_qa.gd` and the enhanced Sketchfab smoke check verify
materials, textured surfaces and furniture. No Sketchfab models were modified
or duplicated for this pass.

## Lounge renovation and roulette polishing

User-directed pass on `casino-anomaly/dev`:
- Replaced oversized Book Pattern upper-wall fabric with ambientCG **Fabric037 2K JPG**, from the user-supplied archive; all three PBR maps are checked against the uploaded file's SHA-256 values. Source: https://ambientcg.com/view?id=Fabric037 (CC0).
- Changed bar counter surfaces to Poly Haven `wood_table_worn` (tops) and `dark_wood` (facades/backboard).
- Pillar surfaces are Poly Haven `smoke_speckled_veneer`, keeping their existing collision shapes and gold ring trim.
- All three roulette cabinets use Poly Haven `wood_table_001`; top lowered about 15 cm, roulette wheel enlarged about 30 percent.
- Replaced all five primitive sofas and coffee tables with original Poly Haven `sofa_02` and `round_wooden_table_01` glTFs, individually aligned and collidable.
- Added one chess set and two animal sculptures (concrete cat, horse), each as a unique environmental landmark with pedestal collisions and without blocking the red runner.
- Added reproducible offline checks for imported material maps, model types and placement counts. The longstanding Gold/wood architecture and previous Sketchfab credits remain intact.

## Abstract menu and in-game credits

The main screen uses a lightweight 2D canvas shader instead of loading a second casino environment. Beveled animated buttons, fade transitions and a centralized UI palette are shared with settings and pause screens. Credits are accessible directly beneath Settings in both menus and contain attribution links to the project’s audio, Sketchfab CC BY 4.0 models and CC0 asset sources. The full verified attribution record remains in [ASSET_CREDITS.md](ASSET_CREDITS.md). The unused Casino_2 preview scene, corresponding source ZIP and its build pipeline have been removed; this does not affect the editor-only Sketchfab furniture previews.

## Custom Windows icon and loading transitions

The application and Windows export preset reference `branding/casino_anomaly.svg`, a bespoke portal emblem that Godot 4.5 converts to the native Windows executable icon during export. The same artwork appears on the in-game loading screen. If Explorer initially retains a previous icon after updating, its Windows icon cache may need refreshing.

A persistent `SceneLoader` autoload presents a rendered full-screen transition before requesting target scenes through `ResourceLoader.load_threaded_request`. The bar reflects actual resource progress; a separate final phase covers the main-thread scene activation, which cannot be accurately expressed as a percentage. This applies to New Game, Continue and the tutorial's E-door transition. The controller's seamless in-world casino-room streaming remains unchanged. The first clean casino room rule and persistent audio split remain intact. A separate regression test exercises both entry points in CI.

## Premium UI, original click sound and starting-door interaction

All styled menu and dialogue buttons use the shared sculpted-glass surface (including stateful hover/press/focus animation) and one short original procedural click sound. `UISfx` is a persistent audio controller routed to the already existing `UI` bus, so `Settings → Audio → Menu / UI` independently adjusts it. The croupier conversation now uses the same custom buttons as the main and pause menus instead of default Godot controls.

In the tutorial, the old world-space `ExitDoor/DoorHint` label is removed. A non-intercepting, gaze- and distance-sensitive `DoorInteractionHUD` presents an `E` keycap with translated `Enter the casino / Casino betreten` text only while the player looks at the entrance door. The existing E action continues to run through the threaded scene loader and preserves the tutorial completion logic.
