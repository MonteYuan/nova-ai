import Foundation
import Combine
import Security

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published private(set) var isAuthenticated = false
    @Published private(set) var isLoading = false

    // Supabase publishable keys are intended for client-side use.
    // Never put a Supabase secret/service-role key or an AI provider key here.
    private let supabaseURL = "https://roczknzmeivxcsczvpw.supabase.co"
    private let supabaseAnonKey = "sb_publishable_QN6oBOz0v7PpZxRbvsN3GQ_7W4QjqNq"

    private let accessTokenKey = "nova.supabase.access-token"
    private let refreshTokenKey = "nova.supabase.refresh-token"
    private let expiryDefaultsKey = "nova.supabase.token-expiry"

    private init() {
        isAuthenticated = Keychain.read(accessTokenKey) != nil
    }

    func signUp(email: String, password: String) async throws -> Bool {
        try await authenticate(path: "signup", email: email, password: password)
    }

    func signIn(email: String, password: String) async throws {
        _ = try await authenticate(path: "token?grant_type=password", email: email, password: password)
    }

    func signOut() async {
        if let token = Keychain.read(accessTokenKey),
           let url = URL(string: supabaseURL + "/auth/v1/logout") {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: request)
        }
        clearSession()
    }

    func validAccessToken() async throws -> String {
        guard let token = Keychain.read(accessTokenKey) else {
            throw AuthError.sessionExpired
        }

        let expiry = UserDefaults.standard.double(forKey: expiryDefaultsKey)
        if expiry > Date().timeIntervalSince1970 + 60 {
            return token
        }

        guard let refresh = Keychain.read(refreshTokenKey),
              let url = URL(string: supabaseURL + "/auth/v1/token?grant_type=refresh_token") else {
            clearSession()
            throw AuthError.sessionExpired
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(RefreshRequest(refresh_token: refresh))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let session = try? JSONDecoder().decode(AuthResponse.self, from: data),
              let newAccess = session.access_token,
              let newRefresh = session.refresh_token else {
            clearSession()
            throw AuthError.sessionExpired
        }
        saveSession(access: newAccess, refresh: newRefresh, expiresIn: session.expires_in ?? 3600)
        return newAccess
    }

    private func authenticate(path: String, email: String, password: String) async throws -> Bool {
        isLoading = true
        defer { isLoading = false }

        guard let url = URL(string: supabaseURL + "/auth/v1/" + path) else {
            throw AuthError.invalidConfiguration
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(Credentials(email: email, password: password))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AuthError.network }
        guard (200..<300).contains(http.statusCode) else {
            let serverError = try? JSONDecoder().decode(SupabaseError.self, from: data)
            throw AuthError.server(serverError?.msg ?? serverError?.message ?? "Please check your email and password.")
        }

        let session = try JSONDecoder().decode(AuthResponse.self, from: data)
        guard let access = session.access_token, let refresh = session.refresh_token else {
            // Supabase may require email confirmation before creating a session.
            return false
        }
        saveSession(access: access, refresh: refresh, expiresIn: session.expires_in ?? 3600)
        return true
    }

    private func saveSession(access: String, refresh: String, expiresIn: Int) {
        Keychain.save(access, for: accessTokenKey)
        Keychain.save(refresh, for: refreshTokenKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970 + Double(expiresIn), forKey: expiryDefaultsKey)
        isAuthenticated = true
    }

    private func clearSession() {
        Keychain.delete(accessTokenKey)
        Keychain.delete(refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: expiryDefaultsKey)
        isAuthenticated = false
    }
}

private struct Credentials: Encodable {
    let email: String
    let password: String
}

private struct RefreshRequest: Encodable {
    let refresh_token: String
}

private struct AuthResponse: Decodable {
    let access_token: String?
    let refresh_token: String?
    let expires_in: Int?
}

private struct SupabaseError: Decodable {
    let msg: String?
    let message: String?
}

enum AuthError: LocalizedError {
    case notConfigured
    case invalidConfiguration
    case network
    case sessionExpired
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Supabase 尚未配置，请先设置项目 URL 和 publishable key。"
        case .invalidConfiguration: return "Supabase 配置无效。"
        case .network: return "网络连接失败，请稍后重试。"
        case .sessionExpired: return "登录已过期，请重新登录。"
        case .server(let message): return message
        }
    }
}

private enum Keychain {
    static func save(_ value: String, for key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    static func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ] as CFDictionary)
    }
}
