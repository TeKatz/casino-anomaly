# Godot 4.5.1: Den Casino-Raum visuell bearbeiten

Die **vorhandene Godot-3D-Ansicht** ist der Raumeditor. Kein eigenes Programm, keine GDScript-Kenntnisse erforderlich.

## Öffnen

1. [Godot 4.5.1 Standard](https://godotengine.org/download/archive/4.5.1-stable/) installieren.
2. Repository über GitHub Desktop klonen und den Branch `feature/godot-visual-room-editing` auschecken (nach dem Merge später `dev`).
3. `project.godot` im Godot-Projektmanager importieren und `main.tscn` öffnen. Beim ersten Import können die GLTF-Modelle kurz brauchen.
4. In der Szene `ModelInteriors`, `SlotMachines`, `GamingTables`, `CornerBar` oder `Lighting` aufklappen. In der 3D-Ansicht Objekte anklicken und W/E/R für Verschieben/Drehen/Skalieren benutzen.
5. Mit Strg+S speichern. GitHub Desktop zeigt `main.tscn` als Änderung an. Commit + Push übertragen den Raumstand.

## Was jetzt editierbar ist

- **Poly-Haven-Modelle:** Alle 43 platzierten Modelle haben einzeln benannte, gespeicherte `Node3D`-Anker (`LoungeSofa_01` usw.). Original-GLTFs erscheinen als Editor-Vorschau. Verschieben, Drehen und Skalieren verändert später auch das Spielmodell **inklusive dessen Kollision**. Die Vorschaumeshes werden nicht als separate Objekte gespeichert.
- **Slots:** `Slot_01` bis `Slot_10` sind gespeicherte Anker. Der erste wird beim Spielen weiterhin durch das Sketchfab-Modell ersetzt; seine neue Position wird mit übernommen.
- **Spieltische:** `Roulette2`, `Blackjack3`, `Roulette4`, `Cards5`, `Roulette6`, `Cards7`. Die Sketchfab-Austauschlogik bleibt erhalten.
- **Lichtquellen:** Neun echte `OmniLight3D`-Nodes unter `Lighting`: Position, Farbe, Intensität und Reichweite im Inspektor ändern.
- **Bar:** Der gesamte `CornerBar`-Knoten ist frei positionierbar; alle zugehörigen Teile und Kollisionskörper bewegen sich gemeinsam.
- **Materialien:** Bereits als `.tres` hinterlegte Boden-, Wand-, Holz-, Stoff-, Säulen- und Bar-Materialien können über den Dateisystembereich geöffnet und im Inspektor geändert werden. Ihre Vorschau wird von der vorhandenen Raumgeometrie verwendet.

## Wichtig: Grenzen der ersten Editierfassung

Die Grundarchitektur (einzelne Wände, Säulen, Teppich-Geometrie), ein Teil der Pflanzen und die komplexen Slot-Einzelteile bleiben vorerst **procedural preview** und sind nicht als einzelne gespeicherte Nodes umgebaut. Sie werden in der Editor-3D-Ansicht durch das Tool-Skript `hall.gd` sichtbar, aber Änderungen an diesen *temporären* Kindern bitte nicht als dauerhafte Raum-Edits behandeln. Benutze dafür die oben genannten stabilen Anker bzw. die Materialressourcen.

Die Poly-Haven-Vorschau zeigt die echten GLTF-Meshes. Die Sketchfab-Pakete sind als ZIPs im Repository und werden weiterhin vom Build-Prozess entpackt; der Godot-Editor benötigt diese entpackten Modelle nur für deren spielinterne Darstellung. Deren Slots/Spieltischpositionen sind auch ohne Entpacken editierbar.

Neue Objekte, Kollisionsregeln, Anomalien und Spiellogik bleiben Entwickleraufgaben. Für die Endfassung können wir die Architektur in eigene, ebenfalls gespeicherte Godot-Szenen aufteilen.

**GitHub-Sicherheit:** Immer erst in GitHub Desktop `Fetch/Pull`, dann bearbeiten, dann `Commit/Push`. Während derselben Sitzung sollte niemand anderes `main.tscn` bearbeiten; sonst können Merge-Konflikte entstehen.
