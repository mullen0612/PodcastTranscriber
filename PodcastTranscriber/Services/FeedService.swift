import Foundation

/// Service for fetching and parsing RSS feeds.
class FeedService {
    private let networkClient: NetworkClient

    init(networkClient: NetworkClient) {
        self.networkClient = networkClient
    }

    func fetchFeed(from url: URL) async throws -> (title: String, episodes: [Episode]) {
        let data = try await networkClient.fetchData(from: url)
        let parser = RSSParser()
        return try parser.parse(data: data, feedURL: url)
    }
}

/// Minimal RSS parser with accumulated text handling.
class RSSParser: NSObject, XMLParserDelegate {
    private var currentElement = ""
    private var currentElementText = ""
    private var currentEnclosureURL: URL?
    private var currentDurationRaw: String?
    private var episodes: [Episode] = []
    private var feedTitle: String?
    private var feedURL: URL?

    // Per-item accumulated fields
    private var itemTitle: String?
    private var itemGUID: String?
    private var itemPubDate: Date?
    private var itemEnclosureURL: URL?
    private var itemDurationRaw: String?

    func parse(data: Data, feedURL: URL) throws -> (title: String, episodes: [Episode]) {
        self.feedURL = feedURL
        let parser = XMLParser(data: data)
        parser.delegate = self
        // Many RSS feeds need namespace support
        parser.shouldProcessNamespaces = true
        guard parser.parse() else {
            throw FeedServiceError.parsingFailed
        }
        return (feedTitle ?? feedURL.absoluteString, episodes)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentElementText = ""

        // enclosure URL from attributes
        if elementName == "enclosure",
           let urlString = attributeDict["url"],
           let url = URL(string: urlString) {
            itemEnclosureURL = url
        }

        // itunes:duration from attributes (some feeds put it as an attribute)
        if (elementName == "duration" || qName == "itunes:duration"),
           let dur = attributeDict["duration"] ?? attributeDict["seconds"] {
            itemDurationRaw = dur
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentElementText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let text = currentElementText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "title":
            if feedTitle == nil {
                feedTitle = text
            } else {
                itemTitle = text
            }
        case "guid":
            itemGUID = text.isEmpty ? nil : text
        case "pubDate":
            itemPubDate = DateParsing.parse(text) ?? itemPubDate
        case "duration":
            itemDurationRaw = text.isEmpty ? nil : text
        case "enclosure":
            // already handled in didStartElement via attributes
            break
        case "item":
            let episodeID = itemGUID ?? itemEnclosureURL?.absoluteString ?? UUID().uuidString
            let duration = parseDuration(raw: itemDurationRaw)
            let episode = Episode(
                id: episodeID,
                podcastID: UUID(),
                title: itemTitle ?? "Untitled",
                pubDate: itemPubDate,
                enclosureURL: itemEnclosureURL,
                status: .discovered,
                audioPath: nil,
                transcriptMDPath: nil,
                error: nil,
                duration: duration,
                updatedAt: Date()
            )
            episodes.append(episode)

            // Reset item accumulators
            itemTitle = nil
            itemGUID = nil
            itemPubDate = nil
            itemEnclosureURL = nil
            itemDurationRaw = nil
        default:
            break
        }
    }

    /// Parse itunes:duration which can be seconds (1234) or HH:MM:SS format.
    private func parseDuration(raw: String?) -> TimeInterval? {
        guard let raw = raw, !raw.isEmpty else { return nil }
        // Try integer seconds
        if let seconds = TimeInterval(raw) {
            return seconds > 0 ? seconds : nil
        }
        // Try HH:MM:SS
        let parts = raw.split(separator: ":").compactMap { TimeInterval($0) }
        if parts.count == 2 {
            return parts[0] * 60 + parts[1]
        }
        if parts.count == 3 {
            return parts[0] * 3600 + parts[1] * 60 + parts[2]
        }
        return nil
    }
}

enum FeedServiceError: Error {
    case parsingFailed
}
