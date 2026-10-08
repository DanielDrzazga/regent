# Code style

- Funkcje i moduły ESM z nazwanymi eksportami; bez klas poza błędami domenowymi.
- Dane zwracane na zewnątrz to kopie (`{ ...note }`) — magazyn nie wypuszcza referencji.
- Czas przez wstrzykiwany zegar (`now`), nigdy `new Date()` w logice testowanej.
- Komentarze tylko tam, gdzie kod nie mówi „dlaczego”.
