import Foundation

/// Utility for parsing dates in various formats.
struct DateParsing {
    static func parse(_ string: String) -> Date? {
        let formats = [
            "E, d MMM yyyy HH:mm:ss Z", // RFC822
            "yyyy-MM-dd'T'HH:mm:ssZ"    // RFC3339
        ]
        let formatter = DateFormatter()
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }
}