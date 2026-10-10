.PHONY: plugin-marketplace-add plugin-install plugin-update plugin-status plugin-uninstall plugin-marketplace-remove plugin-reinstall

# Zarejestruj to repo jako lokalny marketplace "regent" (jednorazowo, na nowej maszynie)
plugin-marketplace-add:
	claude plugin marketplace add ./

# Zainstaluj plugin regent globalnie (zakres user)
plugin-install:
	claude plugin install regent@regent --scope user -y

# Odśwież kopię pluginu po merge'u do main (marketplace trzyma kopię z commita, nie żywy klon)
plugin-update:
	claude plugin marketplace update regent
	claude plugin update regent@regent

# Pokaż status instalacji
plugin-status:
	claude plugin list | grep -A3 regent

# Odinstaluj plugin (zakres user)
plugin-uninstall:
	claude plugin uninstall regent@regent --scope user -y

# Usuń zarejestrowany marketplace (ze wszystkich zakresów)
plugin-marketplace-remove:
	claude plugin marketplace remove regent

# Pełny reset: odinstaluj, usuń marketplace, dodaj marketplace, zainstaluj od nowa
plugin-reinstall: plugin-uninstall plugin-marketplace-remove plugin-marketplace-add plugin-install
