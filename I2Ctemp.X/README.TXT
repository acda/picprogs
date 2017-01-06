PIC code fuer den Kuehschrank LED Streifen

Zum Bauen:

Ist als MP-Lab Projekt gespeichert. sollte direkt gehen. Wenn nicht:

in MP-Lab Projekt fuer einen PIC12F1840 anlegen. Source-files einfuegen. Nur main.asm 'bauen'. Die anderen unter 'Properties' auf 'exclude from build'. Sie werden per 'include' reingezogen.

Keine weiteren libs oder abhängigkeiten. Nur assembler-code. Kein C.

Projekt bauen mit internem Oszillator, brown-out reset. Flashen.


Aufteilung der Dateien:

main.asm       Init-code, Hauptschleife, glue-code
mathFuncs.asm  Math-funktionen. Multiplikation/division.
mathTables.asm Tabellen fuer Quadratzahlen und sinus
uartBuffer.asm Code zum Ansteuern von der seriellen Schnittstelle.
LEDstrip.asm   Code zum Senden an den LED streifen aus WS2811.
I2Ccode.asm    Code zum pollen der I2C temperatursensoren.
colorful.asm   Code zum Berechnen des Leuchtmusters.


