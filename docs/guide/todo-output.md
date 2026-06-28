# TODO: Output- und Export-Brücken (tclutils/tkutils → text/csv/json/pdf/odf)

**Stand:** 2026-06-01
**Typ:** Planung / Backlog — keine Umsetzungszusage. „Machen wir später."
**Ziel:** tclutils-/tkutils-Ergebnisse in die fünf Wunschformate ausgeben:
**text, csv, json, pdf, odg/odt/ods** (je nach Datenform).

---

## Ausgangslage

tclutils-Engines liefern Tcl-Werte (String/Liste/Dict). **text/csv/json**
erzeugt tclutils bereits selbst:

| Ziel | tclutils | Aufruf |
|------|----------|--------|
| text | —        | Rückgabe → `puts` / `::tclutils::common::writeFile` |
| csv  | `tucsv`  | `tucsv::text` / `writeFile` |
| json | `tujson` | `tujson::toJson` / `pretty` / `minify` |

Für **pdf** und **odf** kommen die vorhandenen, separaten Libs ins Spiel
(nicht Teil von tclutils, optionale Abhängigkeit):

| Lib | Version (geprüft) | Liefert |
|-----|-------------------|---------|
| `pdf4tcl`    | 0.9.x            | Low-Level-PDF (canvas-artig, `pdf4tcl::new`) |
| `pdf4tcllib` | 0.2              | Aufsatz: TTF/Unicode, Textumbruch, **Tabellen** (Header/Zebra/Seitenumbruch), Kopf/Fuß/Seitenzahlen, Zeichnen, Einheiten, Formular-Layout |
| `odf`        | 0.9              | OpenDocument pass-through: `odf::text` (.odt), `odf::sheet` (.ods), `odf::draw` (.odg), `odf::chart`, `odf::base` |
| `docir`      | (odt-0.4, pdf-0.2, txt-0.1 …) | Dokument-IR-Hub: ein Modell → Sinks txt/md/html/**odt**/**pdf**/svg/canvas/roff/Tk (+ Tile-Layouts) |

---

## Entscheidungsregel (Datenform → Zielformat → Kette)

| Datenform | Ziel | Kette |
|-----------|------|-------|
| beliebige Werte/Listen | text | tclutils-Rückgabe → `puts`/`writeFile`; Dokument-Text → DocIR → `docir::txt::render` |
| Tabelle | csv | `tucsv::text`/`writeFile` |
| Struktur/Objekte | json | `tujson::toJson` |
| Tabelle/Zahlen | **ods** | `odf::sheet`: `addTable` → `addStringRow`/`addRow`, `defineCellFormat` |
| Fließtext/Überschriften/Listen | **odt** | `odf::text`-Builder; oder DocIR → `docir::odt::render` |
| Boxen/Linien/Diagramm | **odg** | `odf::draw`: pages/shapes/paths |
| druckfertig (Tabelle/Report) | **pdf** | `pdf4tcllib` (Tabellen+Textfluss auf `pdf4tcl`); Dokument → DocIR → `docir::pdf::render` |

Merksätze:
- **DocIR** = „einmal schreiben, viele Formate" für dokumentförmigen Inhalt
  (txt/md/html/odt/pdf).
- **odf** = direkter Weg, wenn gezielt eine echte `.ods` (Tabelle) oder `.odg`
  (Zeichnung) gebraucht wird — das kann DocIR nicht.
- **pdf4tcl(+lib)** = präzises Druck-Layout.

---

## Geplante Exporter (priorisiert)

> Designprinzip: tclutils bleibt GUI-frei und **ohne harte Abhängigkeit** auf
> pdf4tcl/odf/docir. Exporter werden **optionale** Module (analog zu den
> optionalen tkutils-Widgets): sie `package require` die externe Lib **lazy**
> und liefern bei Fehlen eine klare Fehlermeldung (`{TCLUTILS <MOD> NODEP}`)
> statt beim Laden zu scheitern. Tests, die die Lib brauchen, nutzen einen
> `-constraints`-Skip.

### P1 — naheliegend, hoher Nutzen

1. **`tucsv` ⇄ `odf::sheet`** (CSV ↔ `.ods`)
   - `… toOds rows file ?-sheet name? ?-header 0/1?` → schreibt `.ods`.
   - `… fromOds file ?-sheet name?` → liefert `rows` (wie `tucsv::parse`).
   - Mapping: `addTable` + `addStringRow`/`addRow`; Header als erste Zeile,
     ragged Zeilen auffüllen (wie csv-editor).
   - Tests: round-trip rows → .ods → rows; Sonderzeichen; leere Felder.

2. **`tucsv`/`tunotes` → PDF-Tabelle** (`pdf4tcllib`)
   - `… tableToPdf rows file ?-title …? ?-header 0/1?` über pdf4tcllib-Tabellen
     (Seitenumbruch, Zebra, Kopf/Fuß).
   - Tests: PDF entsteht, %PDF-Header, Seitenanzahl plausibel (kein Pixel-Vergleich).

### P2

3. **`tunotes`/Markdown → DocIR → {txt,md,html,odt,pdf}**
   - tunotes-Baum (oder `tumd`-Struktur) in ein DocIR-Modell abbilden, dann die
     vorhandenen Sinks nutzen. Ein Adapter, fünf Ausgaben.
   - Klärt: stabiler DocIR-Knotentyp-Satz (heading/paragraph/list/table/code).

4. **Canvas/tkpath/SVG → `.odg`** (`odf::draw`)
   - Formen/Pfade aus einer einfachen Shape-Liste (oder `docir::svg`) nach
     `odf::draw` (pages/shapes/paths). Eher Nische.

---

## Offen / Scope

- Kein eigenes vollständiges PDF-/ODF-Modell — wir nutzen die Libs.
- Verfügbarkeit der Libs auf dem Zielsystem (Modulpfad) ist Voraussetzung;
  Exporter degradieren freundlich, wenn eine Lib fehlt.
- `odf` braucht `tdom` + `zlib`; auf dem Tcl-9-Stack ist `tdom` aktuell nicht
  installiert → ODS/ODT-Exporter dort übersprungen (wie bei tkxml/tksqlite).
- Lib-Quellen liegen als Uploads vor: `docir`, `odf` (0.9), `pdf4tcl`,
  `pdf4tcllib` (0.2).

---

## Nächster Schritt (wenn wir weitermachen)

Zuerst **#1 `tucsv` ⇄ `odf::sheet`** (CSV ↔ .ods), dann **#2 PDF-Tabelle** —
beide klein, gut testbar, decken die häufigsten „Daten raus"-Fälle ab.
