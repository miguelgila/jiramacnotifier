import Foundation

enum JiraClientError: Error {
    case invalidURL
    case noToken
    case invalidResponse
    case httpError(Int, String)
    case decodingError(Error)
    case networkError(Error)
}

final class JiraClient: @unchecked Sendable {
    private let session: URLSession
    private let keychainManager: KeychainManager

    init(session: URLSession = .shared, keychainManager: KeychainManager = .shared) {
        self.session = session
        self.keychainManager = keychainManager
    }

    func searchIssues(instance: JiraInstance, jql: String) async throws -> [JiraIssue] {
        guard let baseURL = URL(string: instance.url) else {
            throw JiraClientError.invalidURL
        }

        let token = try keychainManager.getToken(for: instance.id.uuidString)

        var components = URLComponents(url: baseURL.appendingPathComponent("/rest/api/2/search"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "jql", value: jql),
            URLQueryItem(name: "maxResults", value: "100"),
            URLQueryItem(name: "fields", value: "summary,status,updated,assignee,reporter,priority")
        ]

        guard let url = components.url else {
            throw JiraClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw JiraClientError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw JiraClientError.httpError(httpResponse.statusCode, errorMessage)
            }

            let searchResponse = try JSONDecoder().decode(JiraSearchResponse.self, from: data)
            return searchResponse.issues

        } catch let error as JiraClientError {
            throw error
        } catch let error as DecodingError {
            throw JiraClientError.decodingError(error)
        } catch {
            throw JiraClientError.networkError(error)
        }
    }

    func testConnection(instance: JiraInstance) async throws -> Bool {
        guard let baseURL = URL(string: instance.url) else {
            throw JiraClientError.invalidURL
        }

        let token = try keychainManager.getToken(for: instance.id.uuidString)

        let url = baseURL.appendingPathComponent("/rest/api/2/myself")
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw JiraClientError.invalidResponse
        }

        return (200...299).contains(httpResponse.statusCode)
    }
}
