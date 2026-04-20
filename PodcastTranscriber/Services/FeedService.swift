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

/// Minimal RSS parser.
class RSSParser: NSObject, XMLParserDelegate {
    private var currentElement = ""
    private var currentTitle: String?
    private var currentGUID: String?
    private var currentPubDate: Date?
    private var currentEnclosureURL: URL?
    private var episodes: [Episode] = []
    private var feedTitle: String?
    private var feedURL: URL?

    func parse(data: Data, feedURL: URL) throws -> (title: String, episodes: [Episode]) {
        self.feedURL = feedURL
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw FeedServiceError.parsingFailed
        }
        return (feedTitle ?? feedURL.absoluteString, episodes)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "enclosure", let urlString = attributeDict["url"], let url = URL(string: urlString) {
            currentEnclosureURL = url
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch currentElement {
        case "title":
            if feedTitle == nil {
                feedTitle = trimmed
            } else {
                currentTitle = trimmed
            }
        case "guid":
            currentGUID = trimmed
        case "pubDate":
            currentPubDate = DateParsing.parse(trimmed)
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            let episodeID = currentGUID ?? currentEnclosureURL?.absoluteString ?? UUID().uuidString
            let episode = Episode(
                id: episodeID,
                podcastID: UUID(), // Placeholder, should be set by caller.
                title: currentTitle ?? "Untitled",
                pubDate: currentPubDate,
                enclosureURL: currentEnclosureURL,
                status: .discovered,
                audioPath: nil,
                transcriptMDPath: nil,
                error: nil,
                updatedAt: Date()
            )
            episodes.append(episode)
            currentTitle = nil
            currentGUID = nil
            currentPubDate = nil
            currentEnclosureURL = nil
        }
    }
}

/// Errors related to FeedService.
enum FeedServiceError: Error {
    case parsingFailed
}