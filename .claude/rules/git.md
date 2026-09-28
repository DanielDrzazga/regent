# Git

- Nigdy nie dodawaj do commitów ani opisów PR informacji, że kod napisało AI (`Co-Authored-By`, „Generated with…”, link do sesji). Technicznie wymusza to `attribution` w `.claude/settings.json`.
- Commity w tym repo idą z adresem `40364469+DanielDrzazga@users.noreply.github.com`, nie z firmowym. Przed pierwszym commitem na nowej maszynie sprawdź `git config user.email`; jeśli jest inny, ustaw lokalnie: `git config user.email 40364469+DanielDrzazga@users.noreply.github.com`.
- Remote: `git@github.com:DanielDrzazga/regent.git`, gałąź główna `main`.
- Commit: jedna linia, bez body, Conventional Commits po polsku w trybie rozkazującym, np. `feat: dodaj manifest pluginu`.
- Każda zmiana na gałęzi `<type>/<nazwa-zmiany>`; do `main` trafia dopiero po zielonej bramce i smoke, bo inne maszyny instalują plugin z `main`.
- `git add` tylko z listą konkretnych plików. Push do `origin` jest dozwolony.
