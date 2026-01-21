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
    private let logManager = LogManager.shared

    init(session: URLSession = .shared, keychainManager: KeychainManager = .shared) {
        self.session = session
        self.keychainManager = keychainManager
    }

    func searchIssues(instance: JiraInstance, jql: String) async throws -> [JiraIssue] {
        guard let baseURL = URL(string: instance.url) else {
            logManager.log(.error, "Invalid URL for instance '\(instance.name)': \(instance.url)", instanceId: instance.id)
            throw JiraClientError.invalidURL
        }

        do {
            let token = try keychainManager.getToken(for: instance.id.uuidString)
            logManager.log(.debug, "Retrieved API token for '\(instance.name)' from keychain", instanceId: instance.id)

            return try await performSearch(instance: instance, baseURL: baseURL, token: token, jql: jql)
        } catch let error as KeychainError {
            logManager.log(.error, "Failed to retrieve token for '\(instance.name)': \(error)", instanceId: instance.id)
            throw JiraClientError.noToken
        }
    }

    private func performSearch(instance: JiraInstance, baseURL: URL, token: String, jql: String) async throws -> [JiraIssue] {

        var components = URLComponents(url: baseURL.appendingPathComponent("/rest/api/2/search"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "jql", value: jql),
            URLQueryItem(name: "maxResults", value: "100"),
            URLQueryItem(name: "fields", value: "summary,status,updated,assignee,reporter,priority")
        ]

        guard let url = components.url else {
            logManager.log(.error, "Failed to construct search URL for '\(instance.name)'", instanceId: instance.id)
            throw JiraClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        logManager.log(.debug, "Executing JQL query for '\(instance.name)': \(jql)", instanceId: instance.id)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                logManager.log(.error, "Invalid HTTP response from '\(instance.name)'", instanceId: instance.id)
                throw JiraClientError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                logManager.log(.error, "HTTP \(httpResponse.statusCode) error from '\(instance.name)': \(errorMessage)", instanceId: instance.id)
                throw JiraClientError.httpError(httpResponse.statusCode, errorMessage)
            }

            let searchResponse = try JSONDecoder().decode(JiraSearchResponse.self, from: data)
            logManager.log(.debug, "Successfully retrieved \(searchResponse.issues.count) issues from '\(instance.name)'", instanceId: instance.id)
            return searchResponse.issues

        } catch let error as JiraClientError {
            throw error
        } catch let error as DecodingError {
            logManager.log(.error, "Failed to decode response from '\(instance.name)': \(error.localizedDescription)", instanceId: instance.id)
            throw JiraClientError.decodingError(error)
        } catch {
            logManager.log(.error, "Network error for '\(instance.name)': \(error.localizedDescription)", instanceId: instance.id)
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
