import Foundation

/// Repository for managing episodes in the database.
class EpisodeRepository {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func upsertEpisode(episode: Episode) throws {
        let pubVal = episode.pubDate.map { String($0.timeIntervalSince1970) } ?? "NULL"
        let durVal = episode.duration.map { String($0) } ?? "NULL"
        let encVal = episode.enclosureURL?.absoluteString
        let audioVal = episode.audioPath
        let mdVal = episode.transcriptMDPath
        let errVal = episode.error

        func quoteOrNull(_ value: String?) -> String {
            value.map { "'\(sqlEscape($0))'" } ?? "NULL"
        }

        let sql = """
        INSERT INTO episodes (id, podcast_id, title, pub_date, enclosure_url, status, audio_path, transcript_md_path, error, duration, updated_at)
        VALUES ('\(sqlEscape(episode.id))', '\(sqlEscape(episode.podcastID.uuidString))', '\(sqlEscape(episode.title))', \(pubVal), \(quoteOrNull(encVal)), '\(sqlEscape(episode.status.rawValue))', \(quoteOrNull(audioVal)), \(quoteOrNull(mdVal)), \(quoteOrNull(errVal)), \(durVal), \(episode.updatedAt.timeIntervalSince1970))
        ON CONFLICT(podcast_id, id) DO UPDATE SET
            title = excluded.title,
            pub_date = excluded.pub_date,
            enclosure_url = excluded.enclosure_url,
            status = excluded.status,
            audio_path = excluded.audio_path,
            transcript_md_path = excluded.transcript_md_path,
            error = excluded.error,
            duration = excluded.duration,
            updated_at = excluded.updated_at;
        """
        try database.execute(sql)
    }

    func fetchEpisodes(forPodcastID podcastID: UUID) throws -> [Episode] {
        let sql = "SELECT * FROM episodes WHERE podcast_id = '\(sqlEscape(podcastID.uuidString))' ORDER BY pub_date DESC;"
        let rows = try database.query(sql)
        return rows.compactMap { row in
            guard let id = row["id"] as? String,
                  let title = row["title"] as? String,
                  let statusRaw = row["status"] as? String,
                  let status = EpisodeStatus(rawValue: statusRaw),
                  let updatedAt = row["updated_at"] as? TimeInterval else {
                return nil
            }
            return Episode(
                id: id,
                podcastID: podcastID,
                title: title,
                pubDate: (row["pub_date"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)),
                enclosureURL: optionalString(row["enclosure_url"]).flatMap(URL.init(string:)),
                status: status,
                audioPath: optionalString(row["audio_path"]),
                transcriptMDPath: optionalString(row["transcript_md_path"]),
                error: optionalString(row["error"]),
                duration: row["duration"] as? TimeInterval,
                updatedAt: Date(timeIntervalSince1970: updatedAt)
            )
        }
    }

    /// Converts a DB value to String? (treats NSNull and literal "NULL" as nil).
    private func optionalString(_ value: Any?) -> String? {
        guard let str = value as? String, str != "NULL" else { return nil }
        return str
    }
}
