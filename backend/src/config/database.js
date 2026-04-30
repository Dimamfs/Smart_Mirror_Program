const { open } = require("sqlite");
const sqlite3 = require("sqlite3");
const path = require("path");
const fs = require("fs");

const DB_PATH = path.join(__dirname, "../../data/smart_mirror.db");
fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });

// Module-level promise — resolved once on first require, reused everywhere
const dbPromise = open({ filename: DB_PATH, driver: sqlite3.Database }).then(
  async (db) => {
    await db.run("PRAGMA journal_mode = WAL");
    await db.run("PRAGMA foreign_keys = ON");

    await db.exec(`
    CREATE TABLE IF NOT EXISTS households (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      name       TEXT    NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS accounts (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      household_id  INTEGER NOT NULL,
      email         TEXT    NOT NULL UNIQUE,
      password_hash TEXT    NOT NULL,
      created_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (household_id) REFERENCES households(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS profiles (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      household_id  INTEGER NOT NULL,
      name          TEXT    NOT NULL,
      email         TEXT,
      google_sub    TEXT,
      mirror_id     TEXT,
      face_filename TEXT,
      created_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (household_id) REFERENCES households(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS gmail_connections (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      profile_id    INTEGER NOT NULL UNIQUE,
      access_token  TEXT    NOT NULL,
      refresh_token TEXT    NOT NULL,
      expiry_date   DATETIME NOT NULL,
      connected_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS active_mirror_users (
      mirror_id  TEXT    PRIMARY KEY,
      profile_id INTEGER NOT NULL,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS spotify_connections (
      id                INTEGER PRIMARY KEY AUTOINCREMENT,
      profile_id        INTEGER NOT NULL UNIQUE,
      access_token      TEXT    NOT NULL,
      refresh_token     TEXT    NOT NULL,
      expires_at        DATETIME NOT NULL,
      spotify_user_id   TEXT    NOT NULL,
      display_name      TEXT,
      connected_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE
    );
  `);

    // Migrations for existing databases
    // These force existing databases to add the new columns without wiping the data.
    await db
      .run(`ALTER TABLE profiles ADD COLUMN mirror_id TEXT`)
      .catch(() => {});
    await db
      .run(`ALTER TABLE profiles ADD COLUMN face_filename TEXT`)
      .catch(() => {});
    // Add the new JSON config column
    await db
      .run(`ALTER TABLE profiles ADD COLUMN widgets_config TEXT`)
      .catch(() => {});

    return db;
  },
);

// All services call: const db = await getDb();
function getDb() {
  return dbPromise;
}

module.exports = { getDb };
