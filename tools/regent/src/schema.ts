// Schemat bazy zadań. Każda migracja to kolejna wersja `user_version`; istniejących nie zmieniamy.

import { openDb, type Db, type Migration } from './db.js';

export const MIGRATIONS: readonly Migration[] = [
  `CREATE TABLE tasks (
     id INTEGER PRIMARY KEY,
     project TEXT NOT NULL,
     parent_id INTEGER REFERENCES tasks (id),
     key TEXT,
     kind TEXT NOT NULL,
     tag TEXT,
     title TEXT NOT NULL,
     owner TEXT NOT NULL,
     state TEXT NOT NULL,
     refs TEXT NOT NULL DEFAULT '{}',
     closure_reason TEXT,
     session_id TEXT,
     transcript_path TEXT,
     file_sig TEXT,
     claimed_at TEXT,
     created_at TEXT NOT NULL,
     updated_at TEXT NOT NULL
   );
   CREATE INDEX tasks_project_state ON tasks (project, state);
   CREATE UNIQUE INDEX tasks_key ON tasks (project, ifnull(parent_id, 0), key) WHERE key IS NOT NULL;
   CREATE TRIGGER tasks_no_delete BEFORE DELETE ON tasks
     BEGIN SELECT RAISE(ABORT, 'tasks: zadanie nie ginie — zamknij je z powodem'); END;

   CREATE TABLE transitions (
     id INTEGER PRIMARY KEY,
     task_id INTEGER NOT NULL REFERENCES tasks (id),
     at TEXT NOT NULL,
     state TEXT NOT NULL,
     owner TEXT NOT NULL,
     actor TEXT NOT NULL,
     source TEXT NOT NULL,
     reason TEXT
   );
   CREATE INDEX transitions_task ON transitions (task_id, id);
   CREATE TRIGGER transitions_no_update BEFORE UPDATE ON transitions
     BEGIN SELECT RAISE(ABORT, 'transitions: log tylko do dopisywania'); END;
   CREATE TRIGGER transitions_no_delete BEFORE DELETE ON transitions
     BEGIN SELECT RAISE(ABORT, 'transitions: log tylko do dopisywania'); END;`,
  // Czas ostatniego sync projektu — `list` pokazuje go także wtedy, gdy sync niczego nie zmienił.
  `CREATE TABLE syncs (
     project TEXT PRIMARY KEY,
     at TEXT NOT NULL,
     source TEXT NOT NULL
   );`,
];

export const openTaskDb = (path: string): Db => openDb(path, MIGRATIONS);
