import SwiftUI

struct LoginView: View {
    let isChinese: Bool
    @ObservedObject var auth: AuthManager

    @State private var email = ""
    @State private var password = ""
    @State private var isCreatingAccount = false
    @State private var message: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 42))
                            .foregroundStyle(.indigo)
                        Text("Nova AI")
                            .font(.largeTitle.bold())
                        Text(isChinese ? "登录后开始使用你的 AI 助手" : "Sign in to start using your AI assistant")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }

                Section(isChinese ? "账户" : "Account") {
                    TextField(isChinese ? "邮箱地址" : "Email address", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                    SecureField(isChinese ? "密码（至少 6 位）" : "Password (at least 6 characters)", text: $password)
                }

                Section {
                    Button {
                        submit()
                    } label: {
                        HStack {
                            Spacer()
                            if auth.isLoading { ProgressView() }
                            Text(isCreatingAccount
                                 ? (isChinese ? "注册账户" : "Create account")
                                 : (isChinese ? "登录" : "Sign in"))
                            Spacer()
                        }
                    }
                    .disabled(auth.isLoading || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.count < 6)

                    Button(isCreatingAccount
                           ? (isChinese ? "已有账户？去登录" : "Already have an account? Sign in")
                           : (isChinese ? "没有账户？立即注册" : "New here? Create an account")) {
                        isCreatingAccount.toggle()
                        message = nil
                        errorMessage = nil
                    }
                    .frame(maxWidth: .infinity)
                    .font(.footnote)
                }

                if let message {
                    Text(message).foregroundStyle(.green).font(.footnote)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle(isChinese ? "欢迎使用" : "Welcome")
        }
    }

    private func submit() {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        message = nil
        errorMessage = nil
        Task {
            do {
                if isCreatingAccount {
                    let hasSession = try await auth.signUp(email: cleanEmail, password: password)
                    if !hasSession {
                        message = isChinese
                            ? "注册请求已提交。请检查邮箱并完成验证，然后返回登录。"
                            : "Sign-up submitted. Check your email to confirm, then sign in."
                    }
                } else {
                    try await auth.signIn(email: cleanEmail, password: password)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
