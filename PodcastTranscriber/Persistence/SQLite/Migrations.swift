import Foundation

/// Handles database migrations.
class Migrations {
    static func migrate(database: SQLiteDatabase) throws {
        let currentVersion = try getCurrentVersion(database: database)
        if currentVersion < 1 {
            try migrateToVersion1(database: database)
        }
    }

    private static func getCurrentVersion(database: SQLiteDatabase) throws -> Int {
        let rows = try database.query("PRAGMA user_version;")
        return rows.first?["user_version"] as? Int ?? 0
    }

    private static func migrateToVersion1(database: SQLiteDatabase) throws {
        let createPodcastsTable = """
        CREATE TABLE IF NOT EXISTS podcasts (
            id TEXT PRIMARY KEY,
            title TEXT,
            feed_url TEXT NOT NULL,
            created_at INTEGER NOT NULL
        );
        """

        let createEpisodesTable = """
        CREATE TABLE IF NOT EXISTS episodes (
            id TEXT NOT NULL,
            podcast_id TEXT NOT NULL,
            title TEXT,
            pub_date INTEGER,
            enclosure_url TEXT,
            status TEXT NOT NULL,
            audio_path TEXT,
            transcript_md_path TEXT,
            error TEXT,
            updated_at INTEGER NOT NULL,
            PRIMARY KEY (podcast_id, id)
        );
        CREATE INDEX IF NOT EXISTS idx_episodes_podcast_pub_date ON episodes (podcast_id, pub_date);
        CREATE INDEX IF NOT EXISTS idx_episodes_podcast_status ON episodes (podcast_id, status);
        """

        try database.execute(createPodcastsTable)
        try database.execute(createEpisodesTable)
        try database.execute("PRAGMA user_version = 1;")
    }
}