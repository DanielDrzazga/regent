# Słownik domeny — [Nazwa projektu]

> **Czym jest ten plik:** słownikiem języka domeny tego projektu i **wyłącznie nim**.
> Termin, jego znaczenie tutaj, i synonimy, których unikamy.
>
> **Czego tu nie ma:** decyzji implementacyjnych, nazw klas i plików, opisu architektury,
> notatek roboczych. Te należą do `ai/docs/patterns/`, `design.md` i `ai/docs/adr/`.
> Plik ma zostać czytelny, gdy cały kod zostanie przepisany.
>
> **Kiedy dopisywać:** gdy w rozmowie rozstrzygnie się znaczenie terminu albo wyjdzie na jaw,
> że dwie osoby rozumiały słowo inaczej. Dopisuj od razu, w trakcie — nie zbieraj na później.

## Terminy

Wyłącznie terminy specyficzne dla TEJ domeny. Ogólne pojęcia programistyczne (repozytorium,
cache, middleware) zostają poza słownikiem.

**[Termin]** — [definicja w 1-2 zdaniach, w języku domeny, bez odwołań do kodu]
_Unikaj:_ [synonimy, które pojawiają się w rozmowach lub kodzie, a których nie używamy]

**[Termin]** — [definicja]
_Unikaj:_ [synonimy]

<!-- Przykład:
**Zlecenie** — pojedyncze żądanie wykonania usługi złożone przez Klienta, od przyjęcia
do rozliczenia. Ma dokładnie jednego Wykonawcę.
_Unikaj:_ zamówienie, task, job, order
-->

## Relacje

Jak terminy łączą się ze sobą — jedno zdanie na relację.

- [Termin A] zawiera wiele [Termin B]
- [Termin C] należy do dokładnie jednego [Termin A]

<!-- Przykład:
- Klient składa wiele Zleceń
- Zlecenie ma dokładnie jednego Wykonawcę
-->

## Rozstrzygnięte niejednoznaczności

Zapis sporów terminologicznych, które już zapadły. Chroni przed powrotem do tej samej dyskusji
i tłumaczy, dlaczego w kodzie jest tak, a nie inaczej.

- **[słowo]** znaczyło wcześniej zarówno [A], jak i [B]. Rozstrzygnięcie: [A] to **[Termin]**,
  [B] to **[Termin]**. [Data]

<!-- Przykład:
- **"anulowanie"** znaczyło zarówno wycofanie Zlecenia przed przyjęciem, jak i przerwanie
  w trakcie. Rozstrzygnięcie: przed przyjęciem to **Odwołanie**, w trakcie to **Przerwanie**.
  2026-09-13
-->
