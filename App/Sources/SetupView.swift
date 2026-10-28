import SwiftUI
import UIKit
import Combine

/// 开始页：键盘装没装、完全访问给没给、共享配置通不通，一眼看清。
struct SetupView: View {
    @EnvironmentObject private var store: ConfigStore
    @State private var kbStatus: KeyboardStatus?
    @State private var groupOK = false
    @State private var copiedAt: Date?

    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            List {
                languageSection
                statusSection
                syncSection
                howSection
                privacySection
            }
            .navigationTitle("Jev Jarvis")
            .onAppear { refresh() }
            .onReceive(timer) { _ in refresh() }
        }
    }

    private func refresh() {
        kbStatus = JevStore.loadKeyboardStatus()
        groupOK = JevStore.groupWritable
    }

    private var languageSection: some View {
        Section(jevLocalized(store.language, zh: "语言", en: "Language")) {
            Picker(jevLocalized(store.language, zh: "界面语言", en: "Interface language"), selection: $store.language) {
                ForEach(JevLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
        }
    }

    // MARK: 状态卡

    private var statusSection: some View {
        Section {
            row(icon: "keyboard", title: jevLocalized(store.language, zh: "键盘已启用", en: "Keyboard enabled"),
                ok: kbStatus != nil,
                detail: kbStatus.map {
                    jevLocalized(store.language,
                                 zh: "最近使用：\(timeAgo($0.lastSeen))。若你已移除键盘，这里不会自动变灰——重新添加后在输入框唤起一次即可刷新",
                                 en: "Last used: \(timeAgo($0.lastSeen)). If you removed the keyboard this won't turn gray by itself — re-add it and open it once in any text field to refresh")
                } ?? jevLocalized(store.language, zh: "还没检测到键盘被唤起过（在任意输入框里切换到 Jev 键盘即可）", en: "The keyboard has not been opened yet. Switch to Jev in any text field."))

            row(icon: "lock.open", title: jevLocalized(store.language, zh: "允许完全访问", en: "Full Access"),
                ok: kbStatus?.hasFullAccess == true,
                detail: kbStatus == nil
                    ? jevLocalized(store.language,
                                   zh: "还没有键盘状态：先在任意输入框切到 Jev 键盘唤起一次，这里才会显示真实开关状态",
                                   en: "No keyboard state yet. Switch to the Jev keyboard in any text field once — this row then shows the real switch state.")
                    : (kbStatus?.hasFullAccess == true
                        ? jevLocalized(store.language, zh: "已开启：键盘可以联网、读剪贴板", en: "On: the keyboard can use the network and clipboard")
                        : jevLocalized(store.language, zh: "未开启：键盘无法联网和读剪贴板，也不会出候选", en: "Off: the keyboard cannot use the network or clipboard")))

            row(icon: "externaldrive.connected.to.line.below", title: jevLocalized(store.language, zh: "App Group 共享", en: "App Group sharing"),
                ok: groupOK, detail: groupOK
                    ? jevLocalized(store.language, zh: "配置可以同步到键盘", en: "Configuration syncs to the keyboard")
                    : jevLocalized(store.language, zh: "共享容器不可用（免费签名常见）：用下面的「复制配置给键盘」，再到键盘上点「从剪贴板导入配置」", en: "The shared container is unavailable (common with a free signing account). Use Copy config for the keyboard below, then tap Import config from clipboard on the keyboard."))
        } header: {
            Text(jevLocalized(store.language, zh: "状态", en: "Status"))
        } footer: {
            Text(jevLocalized(store.language, zh: "键盘每次被唤起时会回写状态，这里每 2 秒刷新。", en: "The keyboard writes its status when opened. This view refreshes every 2 seconds."))
        }
    }

    private func row(icon: String, title: String, ok: Bool, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(ok ? Color.green : Color.orange)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: 配置搬运（App Group 不可用时的退路）

    private var syncSection: some View {
        Section {
            Button {
                copyConfigForKeyboard()
            } label: {
                Label(jevLocalized(store.language, zh: "复制配置给键盘", en: "Copy config for the keyboard"),
                      systemImage: "doc.on.doc")
            }
            if let copiedAt {
                Text(jevLocalized(store.language,
                                  zh: "已复制（\(timeAgo(copiedAt))）。现在切到键盘，点「从剪贴板导入配置」",
                                  en: "Copied \(timeAgo(copiedAt)). Switch to the keyboard now and tap Import config from clipboard."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            Text(jevLocalized(store.language, zh: "配置同步", en: "Config sync"))
        } footer: {
            Text(jevLocalized(store.language,
                              zh: "免费签名时 App Group 常常拿不到，键盘就读不到这里存的配置。用这个按钮把整份配置（含 API Key）放进剪贴板，在键盘上导入一次即可。注意它会覆盖你刚复制的聊天内容——导入完再去复制消息。",
                              en: "With a free signing account the App Group is often unavailable, so the keyboard cannot read this config. This button puts the whole config (API key included) on the clipboard; import it once on the keyboard. It replaces whatever chat message you copied, so copy the message again afterwards."))
        }
    }

    private func copyConfigForKeyboard() {
        let cfg = JevStore.loadConfig()
        guard let payload = JevConfigTransfer.encode(cfg) else { return }
        UIPasteboard.general.string = payload
        copiedAt = Date()
    }

    // MARK: 步骤

    private var howSection: some View {
        Section(jevLocalized(store.language, zh: "三步启用", en: "Set up in three steps")) {
            step(1, jevLocalized(store.language, zh: "设置 → 通用 → 键盘 → 键盘 → 添加新键盘 → Jev 键盘", en: "Settings → General → Keyboard → Keyboards → Add New Keyboard → Jev Keyboard"))
            step(2, jevLocalized(store.language, zh: "回到「键盘」列表，点 Jev 键盘 → 打开「允许完全访问」", en: "Return to Keyboards, select Jev Keyboard, and turn on Full Access"))
            step(3, jevLocalized(store.language, zh: "去「模型」页填一个 API Key（如智谱 glm-4-flash），然后在聊天 App 中使用：长按消息 → 复制 → 键盘上点「分析剪贴板」", en: "Add an API key on Models (e.g. Zhipu glm-4-flash), then in any chat app long-press a message, copy it, and tap Analyze Clipboard"))
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(n))
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor))
            Text(text).font(.subheadline)
        }
        .padding(.vertical, 2)
    }

    // MARK: 隐私

    private var privacySection: some View {
        Section(jevLocalized(store.language, zh: "隐私边界", en: "Privacy")) {
            Label(jevLocalized(store.language, zh: "聊天内容只发给你自己配置的模型接口，无自建服务器、不落盘、不进日志", en: "Chat content is sent only to the model endpoint you configure. No server, storage, or logs."), systemImage: "hand.raised")
            Label(jevLocalized(store.language, zh: "Key 存在本机 App Group 私有容器，仅 App 与键盘可读", en: "The key stays in a private App Group container readable only by the app and keyboard."), systemImage: "key")
            Label(jevLocalized(store.language, zh: "候选只「插入」输入框，发送永远由你手动完成", en: "Suggestions are only inserted into the field. You always send manually."), systemImage: "square.and.arrow.down.on.square")
            Label(jevLocalized(store.language, zh: "键盘不监听、不上传按键内容；完全访问可随时在系统设置里关闭或移除键盘", en: "The keyboard does not monitor or upload keystrokes. Full Access can be disabled anytime."), systemImage: "shield")
        }
        .font(.subheadline)
    }

    private func timeAgo(_ d: Date) -> String {
        let s = Date().timeIntervalSince(d)
        if store.language == .english {
            if s < 60 { return "\(Int(s)) sec ago" }
            if s < 3600 { return "\(Int(s / 60)) min ago" }
            return "\(Int(s / 3600)) hr ago"
        }
        if s < 60 { return "\(Int(s)) 秒前" }
        if s < 3600 { return "\(Int(s / 60)) 分钟前" }
        return "\(Int(s / 3600)) 小时前"
    }
}
