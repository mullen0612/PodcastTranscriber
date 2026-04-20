import Foundation

/// A simple network client for making HTTP requests.
class NetworkClient {
    func fetchData(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.invalidResponse
        }
        return data
    }
}

/// Network-related errors.
enum NetworkError: Error {
    case invalidResponse
}