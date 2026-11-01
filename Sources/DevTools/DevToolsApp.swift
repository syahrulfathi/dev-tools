import SwiftUI
import AppKit
import DevToolsCore

// Explicit alias selects the stable property wrapper on SDKs that also expose a State macro.
private typealias LocalState<Value> = SwiftUI.State<Value>

enum Utility: String, CaseIterable, Identifiable, Sendable {
    case base64 = "Base64", json = "JSON", yaml = "YAML", diff = "Compare", uuid = "UUID v7"
    var id: Self { self }
    var icon: String {
        switch self { case .base64: "textformat.abc"; case .json: "curlybraces"; case .yaml: "list.bullet.indent"; case .diff: "arrow.left.arrow.right"; case .uuid: "number" }
    }
    var subtitle: String {
        switch self {
        case .base64: "Encode and decode UTF-8 text, instantly."
        case .json: "Bring structure to your JSON."
        case .yaml: "Validate and format YAML documents."
        case .diff: "See exactly what changed between two texts."
        case .uuid: "Generate time-based UUIDs, right on your Mac."
        }
    }
    var sample: String {
        switch self {
        case .base64: "Hello, developer! 👋"
        case .json: "{\"name\":\"dev-tools\",\"offline\":true,\"tools\":[\"Base64\",\"JSON\",\"YAML\",\"Compare\"]}"
        case .yaml: "app:\n  name: dev-tools\n  offline: true\n  tools:\n    - Base64\n    - JSON\n    - YAML\n"
        case .diff: "Hello, developer!\nEverything runs locally.\nReady to build.\n"
        case .uuid: ""
        }
    }
}

struct Workspace {
    var input = ""
    var output = ""
    var comparison = ""
    var error: String?
    var status = "Ready"
}

@main
struct DevToolsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 920, minHeight: 640)
        }
        .defaultSize(width: 1180, height: 800)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

struct ContentView: View {
    @LocalState private var selected: Utility = .base64
    @LocalState private var workspaces: [Utility: Workspace] = [:]
    @LocalState private var urlSafe = false
    @LocalState private var sortKeys = false
    @LocalState private var ignoreWhitespace = false
    @LocalState private var running = false
    @LocalState private var wrap = true
    @LocalState private var uuidCount = 1
    @AppStorage("darkMode") private var darkMode = false
    private var accent: Color { darkMode ? Color(red: 0.38, green: 0.85, blue: 0.73) : Color(red: 0.02, green: 0.40, blue: 0.31) }
    private var canvas: Color { darkMode ? Color(red: 0.065, green: 0.08, blue: 0.10) : Color(red: 0.96, green: 0.97, blue: 0.98) }
    private var border: Color { Color.primary.opacity(darkMode ? 0.08 : 0.10) }

    private var current: Workspace { workspaces[selected] ?? Workspace() }
    private func value(_ key: WritableKeyPath<Workspace, String>) -> Binding<String> {
        let tool = selected
        return Binding(get: { (workspaces[tool] ?? Workspace())[keyPath: key] }, set: { newValue in
            workspaces[tool, default: Workspace()][keyPath: key] = newValue
            workspaces[tool, default: Workspace()].status = "Edited · run to refresh result"
            workspaces[tool, default: Workspace()].error = nil
        })
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(alignment: .leading, spacing: 22) {
                header
                actions
                if let error = current.error {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(error).textSelection(.enabled).lineLimit(5)
                        Spacer()
                        Button { workspaces[selected, default: Workspace()].error = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                    }
                    .font(.system(size: 12)).foregroundStyle(darkMode ? Color(red: 1, green: 0.67, blue: 0.56) : Color(red: 0.65, green: 0.20, blue: 0.10))
                    .padding(12).background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                }
                if selected == .uuid {
                    editor(title: "GENERATED UUID V7", text: value(\.output), editable: false, placeholder: "Click Generate or press ⌘Return to create UUIDs…")
                } else if selected == .diff {
                    VSplitView {
                        HSplitView {
                            editor(title: "ORIGINAL", text: value(\.input), editable: true, placeholder: "Paste the original text here…")
                            editor(title: "MODIFIED", text: value(\.comparison), editable: true, placeholder: "Paste the modified text here…")
                        }.frame(minHeight: 150)
                        editor(title: "UNIFIED DIFF", text: value(\.output), editable: false, placeholder: "Your comparison will appear here…", diff: true).frame(minHeight: 130)
                    }
                } else {
                    HSplitView {
                        editor(title: "INPUT", text: value(\.input), editable: true, placeholder: "Paste \(selected == .base64 ? "text or Base64" : selected.rawValue) here…")
                        editor(title: "OUTPUT", text: value(\.output), editable: false, placeholder: "Your result will appear here…")
                    }
                }
                footer
            }
            .padding(.horizontal, 28).padding(.top, 42).padding(.bottom, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(canvas)
        .preferredColorScheme(darkMode ? .dark : .light)
        .tint(accent)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "terminal.fill").font(.system(size: 23)).foregroundStyle(accent)
                Text("dev-tools").font(.system(size: 22, weight: .semibold, design: .rounded))
            }.padding(.bottom, 7)
            Text("A little space to build.").font(.system(size: 11)).foregroundStyle(.secondary)
            Text("WORKBENCH").font(.system(size: 10, weight: .bold)).tracking(1.8).foregroundStyle(.secondary).padding(.top, 40).padding(.bottom, 12)
            ForEach(Array(Utility.allCases.enumerated()), id: \.element) { index, tool in
                Button {
                    selected = tool
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: tool.icon).frame(width: 22).font(.system(size: 16))
                        Text(tool.rawValue).font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text("⌘\(index + 1)").font(.system(size: 10)).opacity(0.5)
                    }
                    .foregroundStyle(selected == tool ? accent : Color.primary.opacity(0.65))
                    .padding(.horizontal, 12).padding(.vertical, 13)
                    .background(selected == tool ? accent.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 9))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                .padding(.bottom, 5)
            }
            Spacer()
            Picker("Appearance", selection: $darkMode) {
                Label("Light", systemImage: "sun.max").tag(false)
                Label("Dark", systemImage: "moon").tag(true)
            }
            .pickerStyle(.segmented).labelsHidden().padding(.bottom, 18)
            VStack(alignment: .leading, spacing: 8) {
                Label("Local by design", systemImage: "lock.shield").foregroundStyle(accent).font(.system(size: 12, weight: .medium))
                Text("No uploads. No accounts.\nJust you and your tools.").font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
            }.padding(13).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 10))
            Text("dev-tools  /  1.1").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.4).foregroundStyle(.tertiary).padding(.top, 18)
        }
        .padding(.horizontal, 18).padding(.top, 54).padding(.bottom, 22)
        .frame(width: 214).frame(maxHeight: .infinity)
        .background(darkMode ? Color(red: 0.08, green: 0.10, blue: 0.12) : Color(red: 0.93, green: 0.95, blue: 0.96))
        .overlay(alignment: .trailing) { Rectangle().fill(border).frame(width: 1) }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(selected == .diff ? "Text comparison" : selected == .uuid ? "UUID v7 generator" : "\(selected.rawValue) studio").font(.system(size: 29, weight: .semibold, design: .rounded))
                Text(selected.subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer()
            Label("OFFLINE", systemImage: "circle.fill").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.2)
                .foregroundStyle(accent).padding(.horizontal, 10).padding(.vertical, 7)
                .background(accent.opacity(0.08), in: Capsule())
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button { run() } label: {
                Label(primaryTitle, systemImage: selected == .diff ? "arrow.left.arrow.right" : "play.fill")
                    .font(.system(size: 12, weight: .semibold)).padding(.horizontal, 7).padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent).foregroundStyle(darkMode ? canvas : .white)
            .keyboardShortcut(.return, modifiers: .command).disabled(running)
            if selected == .base64 || selected == .json {
                Button(selected == .base64 ? "Decode" : "Minify") { run(alternate: true) }
                    .keyboardShortcut(.return, modifiers: [.command, .shift]).disabled(running)
            }
            Divider().frame(height: 20).padding(.horizontal, 3)
            switch selected {
            case .base64: Toggle("URL-safe", isOn: $urlSafe).toggleStyle(.checkbox)
            case .json: Toggle("Sort keys", isOn: $sortKeys).toggleStyle(.checkbox)
            case .yaml: Text("Comments are removed").foregroundStyle(.secondary)
            case .diff: Toggle("Ignore whitespace", isOn: $ignoreWhitespace).toggleStyle(.checkbox)
            case .uuid:
                Picker("Quantity", selection: $uuidCount) {
                    Text("1 UUID").tag(1)
                    Text("10 UUIDs").tag(10)
                    Text("100 UUIDs").tag(100)
                }.fixedSize().disabled(running)
            }
            Spacer(minLength: 4)
            if selected != .uuid { Button("Sample") { loadSample() }.disabled(running) }
            Button { wrap.toggle() } label: { Image(systemName: "text.word.spacing") }
                .help(wrap ? "Turn off line wrapping" : "Turn on line wrapping")
            Button {
                workspaces[selected] = Workspace()
            } label: { Image(systemName: "trash") }.help("Clear this workspace").disabled(running)
        }
        .font(.system(size: 11)).buttonStyle(.bordered)
    }

    private var primaryTitle: String {
        switch selected { case .base64: "Encode"; case .json, .yaml: "Format"; case .diff: "Compare"; case .uuid: "Generate" }
    }

    private func editor(title: String, text: Binding<String>, editable: Bool, placeholder: String, diff: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Circle().fill(editable ? Color.primary.opacity(0.3) : accent).frame(width: 5, height: 5)
                Text(title).font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(1.5).foregroundStyle(.secondary)
                Spacer()
                if editable {
                    Button { text.wrappedValue = NSPasteboard.general.string(forType: .string) ?? "" } label: { Image(systemName: "doc.on.clipboard") }.help("Paste")
                    Button { openFile(into: text) } label: { Image(systemName: "folder") }.help("Open UTF-8 file")
                }
                Button { copy(text.wrappedValue) } label: { Image(systemName: "doc.on.doc") }.help("Copy \(title.lowercased())")
                    .disabled(text.wrappedValue.isEmpty)
                Button { saveFile(text.wrappedValue) } label: { Image(systemName: "square.and.arrow.down") }.help("Save \(title.lowercased())")
                    .disabled(text.wrappedValue.isEmpty)
            }
            .buttonStyle(.plain).foregroundStyle(.secondary).padding(.horizontal, 14).frame(height: 42)
            Rectangle().fill(border).frame(height: 1)
            ZStack(alignment: .topLeading) {
                CodeEditor(text: text, editable: editable, wrap: wrap, highlightDiff: diff, darkMode: darkMode)
                if text.wrappedValue.isEmpty {
                    Text(placeholder).font(.system(size: 12, design: .monospaced)).foregroundStyle(.tertiary).padding(.top, 14).padding(.leading, 15).allowsHitTesting(false)
                }
            }
            Rectangle().fill(border).frame(height: 1)
            HStack {
                Text("\(text.wrappedValue.isEmpty ? 0 : text.wrappedValue.components(separatedBy: "\n").count) lines")
                Spacer()
                Text("\(text.wrappedValue.utf8.count.formatted()) bytes · UTF-8")
            }.font(.system(size: 9, design: .monospaced)).foregroundStyle(.tertiary).padding(.horizontal, 14).frame(height: 28)
        }
        .background(darkMode ? Color(red: 0.075, green: 0.092, blue: 0.115) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay { RoundedRectangle(cornerRadius: 11).strokeBorder(border, lineWidth: 1) }
        .frame(minWidth: 230)
        .padding(2)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if running { ProgressView().controlSize(.mini) }
            else { Image(systemName: current.error == nil ? "checkmark.circle" : "exclamationmark.circle").foregroundStyle(current.error == nil ? accent : .orange) }
            Text(running ? "Processing locally…" : current.status).lineLimit(1)
            Spacer()
            if selected != .diff && selected != .uuid {
                Button("Use output as input ↑") {
                    workspaces[selected, default: Workspace()].input = current.output
                    workspaces[selected, default: Workspace()].status = "Output moved to input"
                }.buttonStyle(.plain).disabled(current.output.isEmpty || running)
            }
            Text("⌘ ↵ to \(primaryTitle.lowercased())").foregroundStyle(.tertiary).padding(.leading, 12)
        }.font(.system(size: 10)).foregroundStyle(.secondary)
    }

    private func loadSample() {
        workspaces[selected] = Workspace(input: selected.sample)
        if selected == .diff { workspaces[selected]?.comparison = "Hello, developer!\nEverything runs locally.\nReady to ship.\nNo browser needed.\n" }
    }

    private func run(alternate: Bool = false) {
        guard !running else { return }
        let tool = selected
        let snapshot = current
        let safe = urlSafe, sorted = sortKeys, whitespace = ignoreWhitespace, count = uuidCount
        running = true
        workspaces[tool, default: Workspace()].error = nil
        Task { @MainActor in
            let result: Result<String, Error> = await Task.detached {
                Result {
                    switch tool {
                    case .base64: return alternate ? try Transformer.decodeBase64(snapshot.input, urlSafe: safe) : Transformer.encodeBase64(snapshot.input, urlSafe: safe)
                    case .json: return try Transformer.json(snapshot.input, compact: alternate, sortKeys: sorted)
                    case .yaml: return try Transformer.yaml(snapshot.input)
                    case .diff: return try Transformer.diff(snapshot.input, snapshot.comparison, ignoreWhitespace: whitespace)
                    case .uuid: return try (0..<count).map { _ in try Transformer.uuidV7() }.joined(separator: "\n")
                    }
                }
            }.value
            switch result {
            case .success(let output):
                workspaces[tool, default: Workspace()].output = output
                let edited = (workspaces[tool]?.input ?? "") != snapshot.input || (workspaces[tool]?.comparison ?? "") != snapshot.comparison
                workspaces[tool, default: Workspace()].status = tool == .uuid ? "Generated \(count) UUID\(count == 1 ? "" : "s") · on your Mac" : edited ? "Input changed · run again to refresh" : (tool == .diff && output == "No differences found." ? "Texts match" : "Done · processed on your Mac")
            case .failure(let error):
                workspaces[tool, default: Workspace()].output = ""
                workspaces[tool, default: Workspace()].error = error.localizedDescription
                workspaces[tool, default: Workspace()].status = "Check your input"
            }
            running = false
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        workspaces[selected, default: Workspace()].status = "Copied to clipboard"
    }

    private func openFile(into text: Binding<String>) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { text.wrappedValue = try String(contentsOf: url, encoding: .utf8) }
        catch { workspaces[selected, default: Workspace()].error = "Could not open UTF-8 text: \(error.localizedDescription)" }
    }

    private func saveFile(_ text: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = selected == .json ? "output.json" : selected == .yaml ? "output.yaml" : selected == .diff ? "changes.diff" : selected == .uuid ? "uuids.txt" : "output.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            workspaces[selected, default: Workspace()].status = "Saved \(url.lastPathComponent)"
        } catch { workspaces[selected, default: Workspace()].error = error.localizedDescription }
    }
}

struct CodeEditor: NSViewRepresentable {
    @Binding var text: String
    var editable: Bool
    var wrap: Bool
    var highlightDiff: Bool
    var darkMode: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.autohidesScrollers = true
        let editor = NSTextView()
        editor.isRichText = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.isContinuousSpellCheckingEnabled = false
        editor.isGrammarCheckingEnabled = false
        editor.isAutomaticLinkDetectionEnabled = false
        editor.isAutomaticDataDetectionEnabled = false
        editor.allowsUndo = true
        editor.drawsBackground = false
        editor.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        editor.textContainerInset = NSSize(width: 10, height: 12)
        editor.isVerticallyResizable = true
        editor.minSize = NSSize(width: 0, height: 0)
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.delegate = context.coordinator
        scroll.documentView = editor
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let editor = scroll.documentView as? NSTextView else { return }
        context.coordinator.parent = self
        let appearance = NSAppearance(named: darkMode ? .darkAqua : .aqua)
        scroll.appearance = appearance
        editor.appearance = appearance
        let textColor = NSColor(white: darkMode ? 0.83 : 0.16, alpha: 1)
        editor.textColor = textColor
        editor.insertionPointColor = darkMode ? .systemMint : NSColor(red: 0.02, green: 0.40, blue: 0.31, alpha: 1)
        editor.isEditable = editable
        if editor.string != text { editor.string = text }
        scroll.hasHorizontalScroller = !wrap
        editor.isHorizontallyResizable = !wrap
        editor.autoresizingMask = wrap ? [.width] : []
        editor.textContainer?.widthTracksTextView = wrap
        editor.textContainer?.containerSize = NSSize(width: wrap ? max(scroll.contentSize.width, 1) : CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        if wrap { editor.setFrameSize(NSSize(width: scroll.contentSize.width, height: max(editor.frame.height, scroll.contentSize.height))) }
        if highlightDiff, let storage = editor.textStorage {
            storage.beginEditing()
            storage.addAttribute(.foregroundColor, value: textColor, range: NSRange(location: 0, length: storage.length))
            var offset = 0
            for line in text.components(separatedBy: "\n") {
                let length = (line as NSString).length
                let green = darkMode ? NSColor.systemGreen : NSColor(red: 0.05, green: 0.40, blue: 0.18, alpha: 1)
                let red = darkMode ? NSColor.systemRed : NSColor(red: 0.72, green: 0.12, blue: 0.16, alpha: 1)
                let teal = darkMode ? NSColor.systemTeal : NSColor(red: 0.02, green: 0.36, blue: 0.49, alpha: 1)
                let color: NSColor? = line.hasPrefix("+") ? green : line.hasPrefix("-") ? red : line.hasPrefix("@@") ? teal : nil
                if let color { storage.addAttribute(.foregroundColor, value: color, range: NSRange(location: offset, length: length)) }
                offset += length + 1
            }
            storage.endEditing()
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditor
        init(_ parent: CodeEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            parent.text = editor.string
        }
    }
}
