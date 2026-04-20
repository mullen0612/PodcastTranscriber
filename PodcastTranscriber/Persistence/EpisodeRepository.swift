import Foundation

/// Repository for managing episodes in the database.
class EpisodeRepository {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func upsertEpisode(episode: Episode) throws {
        let sql = """
        INSERT INTO episodes (id, podcast_id, title, pub_date, enclosure_url, status, audio_path, transcript_md_path, error, updated_at)
        VALUES ('\(episode.id)', '\(episode.podcastID.uuidString)', '\(episode.title)', \(episode.pubDate != nil ? String(episode.pubDate!.timeIntervalSince1970) : "NULL"), '\(episode.enclosureURL?.absoluteString ?? "NULL")', '\(episode.status.rawValue)', '\(episode.audioPath ?? "NULL")', '\(episode.transcriptMDPath ?? "NULL")', '\(episode.error ?? "NULL")', \(episode.updatedAt.timeIntervalSince1970))
        ON CONFLICT(podcast_id, id) DO UPDATE SET
            title = excluded.title,
            pub_date = excluded.pub_date,
            enclosure_url = excluded.enclosure_url,
            status = excluded.status,
            audio_path = excluded.audio_path,
            transcript_md_path = excluded.transcript_md_path,
            error = excluded.error,
            updated_at = excluded.updated_at;
        """
        try database.execute(sql)
    }

    func fetchEpisodes(forPodcastID podcastID: UUID) throws -> [Episode] {
        let sql = "SELECT * FROM episodes WHERE podcast_id = '\(podcastID.uuidString)';"
        let rows = try database.query(sql)
        return rows.compactMap { row in
            guard let id = row["id"] as? String,
                  let title = row["title"] as? String,
                  let statusRaw = row["status"] as? String,
                  let status = EpisodeStatus(rawValue: statusRaw),
                  let updatedAt = row["updated_at"] as? TimeInterval else {
                return nil as Episode?
            }
            return Episode(
                id: id,
                podcastID: podcastID,
                title: title,
                pubDate: (row["pub_date"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)),
                enclosureURL: (row["enclosure_url"] as? String).flatMap(URL.init(string:)),
                status: status,
                audioPath: row["audio_path"] as? String,
                transcriptMDPath: row["transcript_md_path"] as? String,
                error: row["error"] as? String,
                updatedAt: Date(timeIntervalSince1970: updatedAt)
            )
        }
    }
}
