.PHONY: plugin-marketplace-add plugin-install plugin-update plugin-status plugin-uninstall plugin-marketplace-remove plugin-reinstall help

plugin-marketplace-add:  ## Zarejestruj to repo jako lokalny marketplace "regent" (jednorazowo, na nowej maszynie)
	claude plugin marketplace add ./

plugin-install:          ## Zainstaluj plugin regent globalnie (zakres user)
	claude plugin install regent@regent --scope user -y

plugin-update:           ## Odśwież kopię pluginu po merge'u do main (marketplace trzyma kopię z commita, nie żywy klon)
	claude plugin marketplace update regent
	claude plugin update regent@regent

plugin-status:           ## Pokaż status instalacji
	claude plugin list | grep -A3 regent

plugin-uninstall:        ## Odinstaluj plugin (zakres user)
	claude plugin uninstall regent@regent --scope user -y

plugin-marketplace-remove:  ## Usuń zarejestrowany marketplace (ze wszystkich zakresów)
	claude plugin marketplace remove regent

plugin-reinstall: plugin-uninstall plugin-marketplace-remove plugin-marketplace-add plugin-install  ## Pełny reset: odinstaluj, usuń marketplace, dodaj marketplace, zainstaluj od nowa

help:                    ## Pokaż dostępne komendy
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-28s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
