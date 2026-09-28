#!/usr/bin/env node
// regent-watch — podgląd pracy agentów Claude Code w terminalu (tylko odczyt).
// React bez NODE_ENV działa w trybie deweloperskim: kilka razy wolniej i z dużo większą pamięcią,
// więc tryb produkcyjny ustawiamy przed pierwszym importem Reacta (import dynamiczny).

process.env.NODE_ENV ??= 'production';
const { run } = await import('./main.js');
run();
