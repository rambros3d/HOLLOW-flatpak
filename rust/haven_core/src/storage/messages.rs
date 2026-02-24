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
