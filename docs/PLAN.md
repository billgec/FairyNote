# FairyNote – Plan

Kostenlose, quelloffene Notiz-App fürs Studium, primär für iPad mit Apple Pencil.
Funktional orientiert an bekannten Handschrift-Notiz-Apps, aber mit eigenem Namen, eigenem Design und eigenem Code.
Keine fremden Assets, Icons, Vorlagen oder Texte übernehmen.

## 1. Zielgruppe & Leitlinien

- Studentin auf dem iPad, Apple Pencil als Haupteingabe, Finger zum Scrollen/Zoomen.
- Offline zuerst: alles lokal, Sync ist ein Bonus und darf nie Daten verlieren.
- Apple-Frameworks statt Fremd-Bibliotheken (PencilKit, PDFKit, Vision, SwiftData, CloudKit). Kein Server, keine Kosten.
- Datenformat offen und exportierbar (PDF-Export immer möglich).

## 2. Features nach Priorität

### P0 – MVP (damit sie im Alltag damit arbeiten kann)
| Feature | Umsetzung |
|---|---|
| Bibliothek mit Notizbüchern (Grid mit Cover) | SwiftUI `LazyVGrid`, SwiftData |
| Ordner (verschachtelt) | `Folder`-Modell mit Parent/Children |
| Notizbuch mit mehreren Seiten, vertikal scrollen | `ScrollView` + eine Canvas pro Seite |
| Handschrift mit Apple Pencil: Stift, Marker, Radierer, Lasso | PencilKit `PKCanvasView` + `PKToolPicker` |
| Papiervorlagen: blanko, liniert, kariert, gepunktet | Eigene Hintergründe per SwiftUI `Canvas` |
| Seite hinzufügen / löschen / duplizieren | |
| Undo/Redo | `UndoManager` von PencilKit |
| Automatisches Speichern | `PKDrawing.dataRepresentation()` in SwiftData |
| Umbenennen, Löschen, Verschieben von Notizbüchern | Kontextmenü |
| Nur-Pencil-Modus (Finger scrollt, Pencil zeichnet) | `drawingPolicy = .pencilOnly` |

### P1 – Studium-Features
| Feature | Umsetzung |
|---|---|
| PDF importieren (Skripte, Folien) und annotieren | PDFKit rendert Seiten als Hintergrund, Zeichnung darüber |
| PDF-Export eines Notizbuchs (inkl. Annotationen) | `UIGraphicsPDFRenderer` |
| Bilder einfügen, verschieben, skalieren | Eigene Element-Ebene über der Canvas |
| Textfelder (getippt) | Eigene Element-Ebene |
| Seitenübersicht (Thumbnails), Seiten umsortieren | `PKDrawing.image(from:scale:)` |
| Zoom pro Seite | `UIScrollView`-Zoom bzw. Canvas-Zoom |
| Favoriten, zuletzt geöffnet, Sortierung | |
| Eigene Farben/Stiftstärken als Favoriten | |
| Formen erkennen (Linie, Kreis, Rechteck geradeziehen) | Eigene Heuristik auf `PKStroke`-Punkten |

### P2 – Komfort
| Feature | Umsetzung |
|---|---|
| Suche über Titel, getippten Text und PDF-Text | SwiftData-Query + `PDFDocument.findString` |
| Handschrift-Suche (OCR) | Vision `VNRecognizeTextRequest` auf Seiten-Rendering, Index im Hintergrund |
| iCloud-Sync zwischen Geräten | SwiftData mit CloudKit-Container |
| Gliederung/Lesezeichen im Notizbuch | |
| Split View: zwei Notizbücher nebeneinander | Mehrere Fenster (`WindowGroup`) |
| Eigene Cover & Papiervorlagen (z. B. Cornell, Wochenplaner) | |
| Präsentationsmodus / Laserpointer | |

### P3 – Später / optional
- Audioaufnahme synchron zur Mitschrift
- Karteikarten-Lernmodus
- Teilen/Zusammenarbeit
- Mac-Version (Mac Catalyst) und iPhone-Ansicht
- Import aus anderen Apps (über PDF-Export der anderen App)

## 3. Architektur

```
FairyNote (SwiftUI App, iPadOS 17+)
├── App/            Einstieg, ModelContainer
├── Models/         SwiftData: Folder, Notebook, Page, PaperStyle
├── Features/
│   ├── Library/    Ordner-Sidebar, Notizbuch-Grid, Kontextmenüs
│   ├── Notebook/   Seitenliste, Toolbar, Seiten-Verwaltung
│   └── Canvas/     PencilKit-Wrapper, Papierhintergrund
├── Services/       (später) PDFImport, PDFExport, Search/OCR, Thumbnails
└── Resources/      Assets
```

- **UI:** SwiftUI mit `NavigationSplitView` (Sidebar: Ordner, Detail: Bibliothek bzw. Notizbuch).
- **Zeichnen:** `PKCanvasView` per `UIViewRepresentable`, ein gemeinsamer `PKToolPicker` pro Fenster.
- **Persistenz:** SwiftData. Zeichnungen als `Data` mit `@Attribute(.externalStorage)`, damit große Seiten nicht die DB aufblähen.
  Modelle sind von Anfang an CloudKit-kompatibel (alle Felder optional oder mit Default, keine `unique`-Constraints, Beziehungen optional).
- **PDF:** Importiertes PDF wird als Datei im App-Container gespeichert, jede `Page` verweist auf Dokument + Seitenindex. Gezeichnet wird in einer transparenten Canvas darüber.
- **Export:** Hintergrund (Papier oder PDF-Seite) + `PKDrawing` werden in `UIGraphicsPDFRenderer` zusammengerendert.
- **Suche:** Hintergrund-Task rendert geänderte Seiten, Vision-OCR schreibt erkannten Text in `Page.recognizedText`.
- **Tests:** Unit-Tests für Modelle/Services (XCTest), UI wird manuell auf dem iPad geprüft.

## 4. Meilensteine

| # | Meilenstein | Inhalt | Ergebnis |
|---|---|---|---|
| M0 | Gerüst | Xcode-Projekt, Modelle, Bibliothek, Canvas mit Tool-Picker | App startet, man kann auf einer Seite zeichnen ✅ (dieser PR) |
| M1 | MVP | Ordner, Seitenverwaltung, Vorlagen, Autosave, Umbenennen/Löschen | Täglich für Mitschriften nutzbar |
| M2 | PDF | PDF-Import, Annotation, PDF-Export, Seitenübersicht | Vorlesungsfolien bearbeiten |
| M3 | Inhalte | Bilder, Textfelder, Formenerkennung, Zoom | Vollwertige Notizen |
| M4 | Suche | Titel-/Textsuche, OCR der Handschrift | Alles wiederfinden |
| M5 | Sync | iCloud über CloudKit, Konfliktverhalten testen | iPad + Mac/iPhone |
| M6 | Feinschliff | Eigene Cover/Vorlagen, Split View, App-Icon, TestFlight | Verteilung ohne App-Store-Kosten über TestFlight bzw. direkte Installation |

## 5. Build & Verteilung

- Bauen nur auf dem Mac mit Xcode 16+ (`FairyNote.xcodeproj` öffnen, iPad-Simulator oder echtes iPad wählen).
- Ohne bezahlten Apple-Developer-Account: Installation per Kabel aufs eigene iPad mit kostenlosem Account, Profil läuft nach 7 Tagen ab und muss neu installiert werden.
- Mit Developer-Account (99 €/Jahr): TestFlight und iCloud-Sync (CloudKit braucht den bezahlten Account).
