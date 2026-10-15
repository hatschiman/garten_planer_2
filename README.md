# GartenPlan

Maßstabsgetreuer 2D-Gartenplaner (Vogelperspektive) für Android mit
regelbasierter automatischer Planung. Offline, ohne Konto, ohne Cloud.

**Status: lauffähiger Entwicklungsstand – nicht zur Veröffentlichung geprüft.**

## Voraussetzungen

- Flutter 3.44 (stable) mit Dart 3.12, Null Safety
- Android SDK (compileSdk aus Flutter-Standard, getestet mit API 35)
- VS Code mit Flutter-/Dart-Erweiterung
- Ein Android-Gerät mit USB-Debugging oder ein Emulator (AVD)

## Flutter installieren

1. **Flutter SDK laden**: Anleitung für das eigene System unter
   <https://docs.flutter.dev/get-started/install> befolgen.
   - macOS mit Homebrew: `brew install --cask flutter`
   - Windows/Linux: ZIP laden, entpacken und den Ordner `flutter/bin` in
     den `PATH` aufnehmen.
2. **Android Studio** installieren (<https://developer.android.com/studio>)
   und darüber das Android SDK, die Platform-Tools und einen Emulator
   (z. B. Pixel 9, API 35) einrichten.
3. **Lizenzen bestätigen**: `flutter doctor --android-licenses`
4. **Installation prüfen**: `flutter doctor` – Flutter und Android toolchain
   müssen ein Häkchen haben (Xcode/Chrome sind für diese App nicht nötig).
5. **VS Code**: Erweiterungen „Flutter“ und „Dart“ installieren.

## Projekt klonen und starten

```bash
git clone https://github.com/hatschiman/garten_planer_2.git
cd garten_planer_2
flutter pub get
flutter emulators --launch <AVD-Name>   # oder Android-Gerät per USB anschließen
flutter run
```

## Öffnen und Starten in VS Code

1. Projektordner in VS Code öffnen.
2. Terminal: `flutter pub get`
3. Gerät/Emulator in der Statusleiste auswählen.
4. `F5` (Run → Start Debugging) oder im Terminal `flutter run`.

## Start auf Android-Gerät oder Emulator

```bash
flutter emulators                       # verfügbare AVDs
flutter emulators --launch <AVD-Name>   # Emulator starten
flutter devices                         # Geräte-ID ermitteln
flutter run -d <Geräte-ID>
```

Debug-APK bauen: `flutter build apk --debug`
→ `build/app/outputs/flutter-apk/app-debug.apk`

## Bedienung des Editors

- **Projektübersicht**: Garten anlegen (Name, Breite, Länge in Metern,
  1–200 m), öffnen, umbenennen/Maße ändern, löschen (mit Bestätigung).
  Ein als „Beispiel“ gekennzeichneter Garten ist vorinstalliert.
- **Ansicht**: Pinch-Zoom, Verschieben mit einem Finger auf freier Fläche,
  Doppeltippen zum Hineinzoomen, Symbol „Gesamten Garten anzeigen“.
- **Auswählen**: Element antippen. Die Leiste unten zeigt Name, Maße und
  Schnellaktionen (90° drehen, fixieren, Eigenschaften, Auswahl aufheben).
- **Verschieben**: Ausgewähltes Element ziehen, oder ein beliebiges Element
  lange drücken und ziehen. Ungültige Positionen (außerhalb der Grenze,
  verbotene Überlappung) werden rot angezeigt und beim Loslassen
  zurückgesetzt.
- **Einrasten**: Menü ⋮ → „Am Raster einrasten (0,5 m)“.
- **Element hinzufügen**: Button unten → Katalog (Bottom Sheet) nach
  Kategorien: Flächen, Pflanzen, Ausstattung, Wege.
- **Eigenschaften** (Bottom Sheet): eigener Name, Breite/Tiefe bzw.
  Durchmesser, Rotation (±90°, +15°), fixieren, duplizieren, löschen.
- **Undo/Redo**: Symbole in der App-Leiste. Ein Ziehvorgang erzeugt genau
  einen Undo-Schritt.
- **Tablet/Querformat** (ab 900 px Breite): Katalog und Eigenschaften
  erscheinen seitlich statt als Bottom Sheet.
- **Export**: Menü ⋮ → „Als JSON teilen“ oder „Plan als Bild teilen“ (PNG)
  über den Android-Teilen-Dialog.

### Kollisionsregeln

| | Fläche | Pflanze | Möbel | Bau | Zone |
|---|---|---|---|---|---|
| **Fläche** (Rasen, Terrasse, Beete, Kies, Weg) | ✗ | ✓ | ✓ | ✓ | ✓ |
| **Pflanze** (Baum, Strauch, Hecke) | ✓ | ✗ | ✗ | ✗ | ✗ |
| **Möbel** (Sitzgruppe, Grill, Regentonne, Sandkasten) | ✓ | ✗ | ✗ | ✗ | ✓ |
| **Bau** (Hochbeet, Gewächshaus, Gartenhaus, Kompost, Teich) | ✓ | ✗ | ✗ | ✗ | ✗ |
| **Zone** (Spielbereich) | ✓ | ✗ | ✓ | ✗ | ✓ |

✓ = Überlappung erlaubt. Berührung an Kanten ist immer erlaubt.
Rotation wird bei Grenzen und Kollisionen exakt berücksichtigt
(Separating Axis Theorem; Kreise exakt).

## Automatische Planung: Funktionsweise und Grenzen

Die Planung ist **regelbasiert**, keine lernende KI.

1. Fixierte Elemente werden immer übernommen; vorhandene Elemente optional.
2. Wunschelemente werden nach Größe absteigend auf einem 0,5-m-Raster
   (bei großen Gärten gröber) platziert. Für jede gültige Position wird
   eine Bewertung berechnet; es wird die beste gewählt.
3. Weiche Kriterien: Bauten am Rand, Sitzgruppe auf/an der Terrasse,
   Gemüsebeete gruppiert, Spielbereich/Sandkasten nicht näher als 3 m an
   Teich oder Grillplatz, empfohlene Abstände, kompakte Anordnung,
   stilabhängige Boni (Familiengarten, Nutzgarten, Entspannung).
4. Rasenwünsche füllen zuletzt die größte freie Rechteckfläche.
5. Gesamtbewertung: Einzelbewertungen + zusammenhängende Freifläche −
   Abweichung vom gewünschten Freiflächenanteil.
6. Sechs Kandidaten mit unterschiedlichem Zufallsrauschen (fester Seed,
   reproduzierbar) werden berechnet, Duplikate entfernt, bis zu drei
   unterscheidbare Vorschläge angezeigt. Zeitlimit 3 s; die Berechnung
   läuft in einem Isolate, die Oberfläche bleibt bedienbar.

Jeder Vorschlag zeigt Vorschau, Begründung, erfüllte und nicht erfüllte
Wünsche. Nicht platzierbare Elemente werden mit Begründung gemeldet.
Der Plan ändert sich erst nach „Übernehmen“; die Übernahme ist ein
einzelner Undo-Schritt.

**Grenzen:** keine Sonnenstands-, Boden- oder Pflanzenanalyse, keine
Sicherheits- oder baurechtliche Prüfung. Die Vorschläge sind
Gestaltungshilfen.

## Speicherung

- Jedes Projekt ist eine JSON-Datei (`schemaVersion: 1`) im
  App-Dokumentenverzeichnis (`…/gardens/<id>.json`).
- Schreiben erfolgt atomar (temporäre Datei → Umbenennen).
- Autosave 0,8 s nach jeder Änderung, zusätzlich beim Verlassen des
  Editors und beim Wechsel in den Hintergrund.
- Beschädigte Dateien werden beim Laden gemeldet und als `.defekt`
  beiseitegelegt, nicht gelöscht.
- Keine personenbezogenen Daten, keine zusätzlichen Android-Berechtigungen.

## Tatsächlich ausgeführte Prüfungen

Siehe Abschnitt „Prüfprotokoll“ am Ende.

## Bekannte Einschränkungen

- Nur rechteckige Grundstücke (freie Polygone sind nicht umgesetzt).
- JSON-Import ist nicht umgesetzt (nur Export/Teilen).
- Größenänderung nur über Eigenschaften, nicht per Ziehgriff.
- Rotation frei in 15°-Schritten über Eigenschaften; Grenzen/Kollisionen
  werden dabei exakt geprüft, das Raster-Einrasten bezieht sich nur auf
  die Position.
- Planung platziert jeden Elementtyp mit seinen Standardmaßen.
- Kein App-Icon, keine Screenshots, kein signierter Release-Build.

## Projektstruktur

```
lib/
  main.dart                 Einstieg, Theme, Lokalisierung (de)
  app_state.dart            Projektliste (ChangeNotifier)
  models/                   Katalog, Elemente, Projekt, Planungseinstellungen, JSON
  storage/                  Atomare JSON-Dateispeicherung
  geometry/                 Rotierte Rechtecke, SAT, Grenzen, Regelmatrix
  editor/                   Viewport (Welt↔Bildschirm), Editorzustand, Undo/Redo
  planner/                  Regelbasierte automatische Planung
  ui/                       Bildschirme, CustomPainter, Gesten, Sheets, Export
test/                       Unit- und Widget-Tests
```

## Release-Checkliste (vor einer Veröffentlichung offen)

- Tests auf mehreren echten Android-Geräten (verschiedene Größen, Android-Versionen).
- Performance bei großen Plänen (z. B. 200 × 200 m, > 200 Elemente).
- Bedienbarkeit und Barrierefreiheit prüfen (TalkBack, Schriftgrößen, Kontraste).
- Datenerhalt bei Abstürzen und App-Updates (Schema-Migration testen).
- Abhängigkeiten und Lizenzen prüfen (`flutter pub deps`, Lizenzseite).
- Datenschutzerklärung und Play-Store-Datensicherheitsangaben.
- Aktuelle Android-/Play-Store-Anforderungen (Target-SDK, 16-KB-Pages, Edge-to-Edge).
- Eigene App-ID bestätigen (aktuell `de.gartenplan.app`), App-Icon, Screenshots.
- Signierter Release-Build und Android App Bundle (Keystore nur nach Freigabe).

## Prüfprotokoll (Stand 15.10.2026)

Ausgeführt auf macOS mit Flutter 3.44.4 / Dart 3.12.2:

| Prüfung | Ergebnis |
|---|---|
| `dart format .` | 32 Dateien, keine Änderungen nötig |
| `flutter analyze` | keine Hinweise |
| `flutter test` | 36 Tests bestanden (JSON-Roundtrip, Viewport-Transformation, Grenzen inkl. Rotation, Regelmatrix, Editor Undo/Redo und Drag, Dateiablage inkl. defekter Datei, Planung inkl. fixierte Elemente und unerfüllbare Wünsche, Widget-Ablauf) |
| `flutter build apk --debug` | erfolgreich, `build/app/outputs/flutter-apk/app-debug.apk` |
| Emulator Pixel 9 (Android 15, API 35, AVD `GartenPlan_Pixel`) | App gestartet; geprüft: Beispielgarten öffnen, Elemente auswählen, Element ziehen (eingerastet), Undo, automatische Planung mit drei Vorschlägen, Vorschlag übernehmen, Neustart der App mit erhaltenem Plan, Querformat mit Seitenpanel |

Nicht geprüft: Pinch-Zoom auf echtem Gerät (nur per Unit-Test der
Transformation), Teilen-Dialog für JSON/PNG auf dem Gerät, echte
Android-Hardware.
