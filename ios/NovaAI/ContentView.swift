import SwiftUI

struct ContentView: View {
    @AppStorage("appLanguage") private var appLanguage = "en"

    private var isChinese: Bool { appLanguage == "zh" }

    var body: some View {
        TabView {
            ChatView(isChinese: isChinese)
                .tabItem {
                    Label(isChinese ? "聊天" : "Chat", systemImage: "bubble.left.and.bubble.right")
                }

            PlaceholderView(title: isChinese ? "发现" : "Discover", subtitle: isChinese ? "探索 AI 功能" : "Explore AI tools")
                .tabItem {
                    Label(isChinese ? "发现" : "Discover", systemImage: "sparkles")
                }

            PlaceholderView(title: isChinese ? "历史" : "History", subtitle: isChinese ? "你的对话记录" : "Your conversations")
                .tabItem {
                    Label(isChinese ? "历史" : "History", systemImage: "clock")
                }

            SettingsView(isChinese: isChinese, appLanguage: $appLanguage)
                .tabItem {
                    Label(isChinese ? "我的" : "Profile", systemImage: "person.crop.circle")
                }
        }
        .tint(.indigo)
    }
}

struct PlaceholderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: "sparkles", description: Text(subtitle))
                .navigationTitle(title)
        }
    }
}

struct SettingsView: View {
    let isChinese: Bool
    @Binding var appLanguage: String

    var body: some View {
        NavigationStack {
            Form {
                Section(isChinese ? "语言" : "Language") {
                    Picker(isChinese ? "界面语言" : "App language", selection: $appLanguage) {
                        Text("English").tag("en")
                        Text("简体中文").tag("zh")
                    }
                }
                Section(isChinese ? "关于" : "About") {
                    LabeledContent("Nova AI", value: "1.0.0")
                }
            }
            .navigationTitle(isChinese ? "我的" : "Profile")
        }
    }
}
