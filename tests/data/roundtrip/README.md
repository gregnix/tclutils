# Round-trip fixtures

Synthetic files (fictitious data, reserved example domains), not real
exports from the programs their names suggest. ICS and VCF use CRLF, the
HTML files LF. Read by `roundtrip.test`: read, write, read again, compare,
plus a few fixed facts per file (counts, recurrence, time zone, escapes).
Tests against real exports are still needed.
