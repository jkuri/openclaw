import SwiftUI
import Textual

public enum ChatMarkdownVariant: String, CaseIterable, Sendable {
    case standard
    case compact
}

@MainActor
struct ChatMarkdownRenderer: View {
    enum Context {
        case user
        case assistant
    }

    let text: String
    let context: Context
    let variant: ChatMarkdownVariant
    let font: Font
    let textColor: Color
    var codeBlockBorderColor: Color = Color.primary.opacity(0.06)
    var codeBlockBorderWidth: CGFloat = 1

    var body: some View {
        let processed = ChatMarkdownPreprocessor.preprocess(markdown: self.text)
        VStack(alignment: .leading, spacing: 10) {
            ForEach(CodeBlockParser.parse(markdown: processed.cleaned)) { segment in
                switch segment.kind {
                case .text:
                    StructuredText(markdown: segment.raw)
                        .modifier(ChatMarkdownStyle(
                            variant: self.variant,
                            context: self.context,
                            font: self.font,
                            textColor: self.textColor))
                case let .code(lang, content):
                    ChatCodeBlockView(
                        code: content,
                        lang: lang,
                        raw: segment.raw,
                        variant: self.variant,
                        context: self.context,
                        font: self.font,
                        textColor: self.textColor,
                        borderColor: self.codeBlockBorderColor,
                        borderWidth: self.codeBlockBorderWidth)
                }
            }

            if !processed.images.isEmpty {
                InlineImageList(images: processed.images)
            }
        }
    }
}

@MainActor
struct ChatCodeBlockView: View {
    let code: String
    let lang: String?
    let raw: String
    let variant: ChatMarkdownVariant
    let context: ChatMarkdownRenderer.Context
    let font: Font
    let textColor: Color
    let borderColor: Color
    let borderWidth: CGFloat

    @State private var copied = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            StructuredText(markdown: self.raw)
                .modifier(ChatMarkdownStyle(
                    variant: self.variant,
                    context: self.context,
                    font: self.font,
                    textColor: self.textColor))
                .padding(.top, 2) // Slight adjustment for the button
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(self.borderColor, lineWidth: self.borderWidth))

            Button {
                self.copyToClipboard()
            } label: {
                Image(systemName: self.copied ? "checkmark" : "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .padding(4)
            .help("Copy code")
        }
    }

    private func copyToClipboard() {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(self.code, forType: .string)
        #else
        UIPasteboard.general.string = self.code
        #endif

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            self.copied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                self.copied = false
            }
        }
    }
}

private struct ChatMarkdownStyle: ViewModifier {
    let variant: ChatMarkdownVariant
    let context: ChatMarkdownRenderer.Context
    let font: Font
    let textColor: Color

    func body(content: Content) -> some View {
        Group {
            if self.variant == .compact {
                content.textual.structuredTextStyle(.default)
            } else {
                content.textual.structuredTextStyle(.gitHub)
            }
        }
        .font(self.font)
        .foregroundStyle(self.textColor)
        .textual.inlineStyle(self.inlineStyle)
        .textual.textSelection(.enabled)
    }

    private var inlineStyle: InlineStyle {
        let linkColor: Color = self.context == .user ? self.textColor : .accentColor
        let codeScale: CGFloat = self.variant == .compact ? 0.85 : 0.9
        return InlineStyle()
            .code(.monospaced, .fontScale(codeScale))
            .link(.foregroundColor(linkColor))
    }
}

@MainActor
private struct InlineImageList: View {
    let images: [ChatMarkdownPreprocessor.InlineImage]

    var body: some View {
        ForEach(images, id: \.id) { item in
            if let img = item.image {
                OpenClawPlatformImageFactory.image(img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            } else {
                Text(item.label.isEmpty ? "Image" : item.label)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
