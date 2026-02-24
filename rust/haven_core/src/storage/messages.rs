use rusqlite::{params, Connection};

/// A stored chat message.
pub(crate) struct StoredMessage {
    pub id: i64,
    pub peer_id: String,
    pub text: String,
    pub is_mine: bool,
    pub timestamp: i64,
}

/// Encrypted SQLite message store.
pub(crate) struct MessageStore {
    conn: Connection,
}

impl MessageStore {
    /// Open (or create) an encrypted database at `path` using `passphrase`.
    pub fn open(path: &str, passphrase: &str) -> Result<Self, String> {
        let conn =
            Connection::open(path).map_err(|e| format!("Failed to open database: {e}"))?;

        // Set encryption key BEFORE any other operations.
        // Use x'' hex key format to avoid SQL injection and quoting issues.
        conn.execute_batch(&format!("PRAGMA key = \"x'{}'\";", passphrase))
            .map_err(|e| format!("Failed to set encryption key: {e}"))?;

        // Create messages table if it doesn't exist.
        conn.execute(
            "CREATE TABLE IF NOT EXISTS messages (
                id        INTEGER PRIMARY KEY AUTOINCREMENT,
                peer_id   TEXT    NOT NULL,
                text      TEXT    NOT NULL,
                is_mine   INTEGER NOT NULL,
                timestamp INTEGER NOT NULL
            )",
            [],
        )
        .map_err(|e| format!("Failed to create messages table: {e}"))?;

        // Index for fast per-peer lookups.
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_messages_peer_ts ON messages (peer_id, timestamp)",
            [],
        )
        .map_err(|e| format!("Failed to create index: {e}"))?;

        // Olm account pickle (singleton row, id=1).
        conn.execute(
            "CREATE TABLE IF NOT EXISTS olm_account (
                id     INTEGER PRIMARY KEY CHECK (id = 1),
                pickle TEXT NOT NULL
            )",
            [],
        )
        .map_err(|e| format!("Failed to create olm_account table: {e}"))?;

        // Olm sessions, one per peer.
        conn.execute(
            "CREATE TABLE IF NOT EXISTS olm_sessions (
                peer_id TEXT PRIMARY KEY,
                pickle  TEXT NOT NULL
            )",
            [],
        )
        .map_err(|e| format!("Failed to create olm_sessions table: {e}"))?;

        Ok(MessageStore { conn })
    }

    /// Insert a message. Returns the row ID.
    pub fn insert(
        &self,
        peer_id: &str,
        text: &str,
        is_mine: bool,
        timestamp: i64,
    ) -> Result<i64, String> {
        self.conn
            .execute(
                "INSERT INTO messages (peer_id, text, is_mine, timestamp) VALUES (?1, ?2, ?3, ?4)",
                params![peer_id, text, is_mine as i32, timestamp],
            )
            .map_err(|e| format!("Failed to insert message: {e}"))?;
        Ok(self.conn.last_insert_rowid())
    }

    // -- Olm persistence --

    /// Save (upsert) the Olm account pickle.
    pub fn save_olm_account(&self, pickle_json: &str) -> Result<(), String> {
        self.conn
            .execute(
                "INSERT INTO olm_account (id, pickle) VALUES (1, ?1)
                 ON CONFLICT(id) DO UPDATE SET pickle = excluded.pickle",
                params![pickle_json],
            )
            .map_err(|e| format!("Failed to save olm account: {e}"))?;
        Ok(())
    }

    /// Load the Olm account pickle, if one exists.
    pub fn load_olm_account(&self) -> Result<Option<String>, String> {
        let mut stmt = self
            .conn
            .prepare("SELECT pickle FROM olm_account WHERE id = 1")
            .map_err(|e| format!("Failed to prepare olm_account query: {e}"))?;
        let mut rows = stmt
            .query_map([], |row| row.get(0))
            .map_err(|e| format!("Failed to query olm_account: {e}"))?;
        match rows.next() {
            Some(Ok(pickle)) => Ok(Some(pickle)),
            Some(Err(e)) => Err(format!("Failed to read olm_account row: {e}")),
            None => Ok(None),
        }
    }

    /// Save (upsert) an Olm session pickle for a peer.
    pub fn save_olm_session(&self, peer_id: &str, pickle_json: &str) -> Result<(), String> {
        self.conn
            .execute(
                "INSERT INTO olm_sessions (peer_id, pickle) VALUES (?1, ?2)
                 ON CONFLICT(peer_id) DO UPDATE SET pickle = excluded.pickle",
                params![peer_id, pickle_json],
            )
            .map_err(|e| format!("Failed to save olm session: {e}"))?;
        Ok(())
    }

    /// Load an Olm session pickle for a specific peer.
    #[allow(dead_code)]
    pub fn load_olm_session(&self, peer_id: &str) -> Result<Option<String>, String> {
        let mut stmt = self
            .conn
            .prepare("SELECT pickle FROM olm_sessions WHERE peer_id = ?1")
            .map_err(|e| format!("Failed to prepare olm_sessions query: {e}"))?;
        let mut rows = stmt
            .query_map(params![peer_id], |row| row.get(0))
            .map_err(|e| format!("Failed to query olm_sessions: {e}"))?;
        match rows.next() {
            Some(Ok(pickle)) => Ok(Some(pickle)),
            Some(Err(e)) => Err(format!("Failed to read olm_sessions row: {e}")),
            None => Ok(None),
        }
    }

    /// Load all Olm session pickles (peer_id, pickle_json) pairs.
    pub fn load_all_olm_sessions(&self) -> Result<Vec<(String, String)>, String> {
        let mut stmt = self
            .conn
            .prepare("SELECT peer_id, pickle FROM olm_sessions")
            .map_err(|e| format!("Failed to prepare olm_sessions query: {e}"))?;
        let rows = stmt
            .query_map([], |row| Ok((row.get(0)?, row.get(1)?)))
            .map_err(|e| format!("Failed to query olm_sessions: {e}"))?;
        let mut result = Vec::new();
        for row in rows {
            result.push(row.map_err(|e| format!("Failed to read olm_sessions row: {e}"))?);
        }
        Ok(result)
    }

    /// Load recent messages for a peer, ordered oldest-first.
    pub fn load_for_peer(
        &self,
        peer_id: &str,
        limit: i32,
    ) -> Result<Vec<StoredMessage>, String> {
        let mut stmt = self
            .conn
            .prepare(
                "SELECT id, peer_id, text, is_mine, timestamp
                 FROM messages
                 WHERE peer_id = ?1
                 ORDER BY timestamp DESC
                 LIMIT ?2",
            )
            .map_err(|e| format!("Failed to prepare query: {e}"))?;

        let rows = stmt
            .query_map(params![peer_id, limit], |row| {
                Ok(StoredMessage {
                    id: row.get(0)?,
                    peer_id: row.get(1)?,
                    text: row.get(2)?,
                    is_mine: row.get::<_, i32>(3)? != 0,
                    timestamp: row.get(4)?,
                })
            })
            .map_err(|e| format!("Failed to query messages: {e}"))?;

        let mut messages = Vec::new();
        for row in rows {
            messages.push(row.map_err(|e| format!("Failed to read row: {e}"))?);
        }
        messages.reverse(); // Oldest first for display.
        Ok(messages)
    }
}
