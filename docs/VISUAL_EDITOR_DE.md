# Godot 4.5.1: Den Casino-Raum visuell bearbeiten

Die **vorhandene Godot-3D-Ansicht** ist der Raumeditor. Kein eigenes Programm, keine GDScript-Kenntnisse erforderlich.

## Öffnen

1. [Godot 4.5.1 Standard](https://godotengine.org/download/archive/4.5.1-stable/) installieren.
2. Repository über GitHub Desktop klonen und den Branch `feature/godot-visual-room-editing` auschecken (nach dem Merge später `dev`).
3. `project.godot` im Godot-Projektmanager importieren und `main.tscn` öffnen. Beim ersten Import können die GLTF-Modelle kurz brauchen.
4. In der Szene `ModelInteriors`, `SlotMachines`, `GamingTables`, `CornerBar` oder `Lighting` aufklappen. In der 3D-Ansicht Objekte anklicken und W/E/R für Verschieben/Drehen/Skalieren benutzen.
5. Mit Strg+S speichern. GitHub Desktop zeigt `main.tscn` als Änderung an. Commit + Push übertragen den Raumstand.

## Was jetzt editierbar ist

- **Poly-Haven-Modelle:** Alle 41 platzierten Modelle haben einzeln benannte, gespeicherte `Node3D`-Anker (`LoungeSofa_01` usw.). Original-GLTFs erscheinen als Editor-Vorschau. Verschieben, Drehen und Skalieren verändert später auch das Spielmodell **inklusive dessen Kollision**. Die Vorschaumeshes werden nicht als separate Objekte gespeichert.
- **Slots:** `Slot_01` bis `Slot_10` sind gespeicherte Anker. Der erste wird beim Spielen weiterhin durch das Sketchfab-Modell ersetzt; seine neue Position wird mit übernommen.
- **Spieltische:** `Roulette2`, `Blackjack3`, `Roulette4`, `Cards5`, `Roulette6`, `Cards7`. Die Sketchfab-Austauschlogik bleibt erhalten.
- **Lichtquellen:** Neun echte `OmniLight3D`-Nodes unter `Lighting`: Position, Farbe, Intensität und Reichweite im Inspektor ändern.
- **Bar:** Der gesamte `CornerBar`-Knoten ist frei positionierbar; alle zugehörigen Teile und Kollisionskörper bewegen sich gemeinsam.
- **Materialien:** Bereits als `.tres` hinterlegte Boden-, Wand-, Holz-, Stoff-, Säulen- und Bar-Materialien können über den Dateisystembereich geöffnet und im Inspektor geändert werden. Ihre Vorschau wird von der vorhandenen Raumgeometrie verwendet.

## Vollständige Bearbeitung der bisher prozeduralen Elemente

Die zweite Umstellung überführt den gebauten Raum in echte, speicherbare Knoten der Szene `main.tscn`. Unter `SlotMachines/Slot_XX/PlayerStool` kannst du einen Hocker unabhängig von der Slotmaschine versetzen. Unter `Decor/Plant_XX` verschiebst du Topf, Blätter und Kollision gemeinsam. `ModelInteriors/BustPedestal_01` und `BustPedestal_02` enthalten die Sockel, `CasinoAtmosphere` die Neonstreifen, beleuchteten Schilderrahmen und Spotlights.

Wichtige Architekturteile und ihre Kollisionskörper sind als einzelne Knoten sichtbar und gespeichert; wenn ein Element mehrere Teile enthält, am besten den passenden übergeordneten Knoten auswählen. **Bei einzelnen separat gespeicherten Wand- und Säulenmeshes die zugehörigen Kollisionskörper nicht vergessen.** Beim Verschieben nur einer Meshfläche bewegt sich eine separat gespeicherte Kollision nicht automatisch mit. Neue Geometrie sollte künftig als gebündelte Szene aus Mesh und Kollision angelegt werden.

Objekt- und Positionsänderungen speichert Godot in `main.tscn`. Zusätzliche dekorative Laufzeit-Partikeleffekte (Staub) werden weiterhin durch das Atmosphärenskript gesteuert.

## Wichtig: Grenzen der ersten Editierfassung

Die Grundarchitektur und die prozeduralen Slot-Einzelteile sind jetzt als echte Szenenknoten gespeichert. Einzelne frei positionierte Meshes haben teilweise separate Kollisionsknoten; deshalb sollte bei Architekturumbauten die passende Kollision mitgeführt werden. Die Laufzeitanimationen und importierte Sketchfab-Ersatzmodelle werden weiterhin durch die jeweiligen Skripte verwaltet.

Die Poly-Haven-Vorschau zeigt die echten GLTF-Meshes. Die Sketchfab-Pakete sind als ZIPs im Repository und werden weiterhin vom Build-Prozess entpackt; der Godot-Editor benötigt diese entpackten Modelle nur für deren spielinterne Darstellung. Deren Slots/Spieltischpositionen sind auch ohne Entpacken editierbar.

Neue Objekte, Kollisionsregeln, Anomalien und Spiellogik bleiben Entwickleraufgaben. Für die Endfassung können wir die Architektur in eigene, ebenfalls gespeicherte Godot-Szenen aufteilen.

**GitHub-Sicherheit:** Immer erst in GitHub Desktop `Fetch/Pull`, dann bearbeiten, dann `Commit/Push`. Während derselben Sitzung sollte niemand anderes `main.tscn` bearbeiten; sonst können Merge-Konflikte entstehen.
