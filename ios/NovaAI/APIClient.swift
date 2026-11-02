import Foundation

private struct ChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }
    let messages: [Message]
}

private struct ChatResponse: Decodable {
    let reply: String
}

enum APIError: Error {
    case invalidURL
    case badResponse
}

final class APIClient {
    static let shared = APIClient()

    // Deployed Nova AI backend.
    private let baseURL = "https://nova-ai-backend-xtto.onrender.com"

    private init() {}

    func sendMessage(messages: [ChatMessage]) async throws -> String {
        let accessToken = try await AuthManager.shared.validAccessToken()

        guard let url = URL(string: baseURL + "/v1/chat") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        let payload = ChatRequest(messages: messages.map {
            ChatRequest.Message(role: $0.role.rawValue, content: $0.content)
        })
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.badResponse
        }
        return try JSONDecoder().decode(ChatResponse.self, from: data).reply
    }
}
