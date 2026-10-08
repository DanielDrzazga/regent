# Regent — kontrakt subagenta

> Wstrzykiwany sesji głównej i każdemu subagentowi w projektach z `ai/docs/`. Mapa skilli
> i agentów (`context/sdd-map.md`) trafia tylko do sesji głównej — subagent jej nie potrzebuje.

**Kontrakt subagenta:** subagent NIE może zablokować się w trakcie pracy i czekać
na odpowiedź użytkownika — działa do końca tury i zwraca raport. Bramki akceptacji
(pytania, zatwierdzenia) prowadzi sesja główna. Pętla pytań wygląda tak:

1. Subagent kończy turę raportem — niejasności w sekcji `OPEN QUESTIONS`.
2. Sesja główna zadaje pytania użytkownikowi.
3. Sesja główna **kontynuuje TEGO SAMEGO subagenta** (SendMessage / resume po
   `agentId`), przekazując odpowiedzi — agent zachowuje swój kontekst, bez
   re-delegacji od zera. Gdy kontynuacja niedostępna → re-delegacja z odpowiedziami
   w prompcie.

Subagent, który tworzy artefakty wymagające akceptacji, **zwraca ich treść w raporcie
końcowym** — pliki zapisuje sesja główna po akceptacji (lub kontynuowany subagent po
przekazaniu „zaakceptowano — zapisz").

