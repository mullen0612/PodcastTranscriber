import Foundation

/// Repository for managing podcasts in the database.
class PodcastRepository {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func addPodcast(id: UUID, title: String, feedURL: String, createdAt: Date) throws {
        let sql = "INSERT INTO podcasts (id, title, feed_url, created_at) VALUES ('\(sqlEscape(id.uuidString))', '\(sqlEscape(title))', '\(sqlEscape(feedURL))', \(createdAt.timeIntervalSince1970));"
        try database.execute(sql)
    }

    func deletePodcast(id: UUID) throws {
        let escapedID = sqlEscape(id.uuidString)
        try database.execute("DELETE FROM episodes WHERE podcast_id = '\(escapedID)';")
        try database.execute("DELETE FROM podcasts WHERE id = '\(escapedID)';")
    }

    func fetchAllPodcasts() throws -> [Podcast] {
        let sql = "SELECT * FROM podcasts;"
        let rows = try database.query(sql)
        return rows.compactMap { row in
            guard let id = row["id"] as? String,
                  let title = row["title"] as? String,
                  let feedURL = row["feed_url"] as? String,
                  let createdAt = row["created_at"] as? TimeInterval else {
                return nil
            }
            return Podcast(id: UUID(uuidString: id)!, title: title, feedURL: URL(string: feedURL)!, createdAt: Date(timeIntervalSince1970: createdAt))
        }
    }
}
