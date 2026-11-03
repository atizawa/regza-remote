#if os(iOS)
import RegzaCore
import SwiftUI

/// キーを 1 つ送るボタン
struct KeyButton: View {
    @Environment(RemoteViewModel.self) private var model
    let key: RegzaKey
    var title: String?
    var tint: Color?
    var showsIcon = true

    var body: some View {
        Button {
            model.send(key)
        } label: {
            Group {
                if showsIcon, let image = key.systemImage {
                    Image(systemName: image)
                        .font(.title3.weight(.semibold))
                } else {
                    Text(title ?? key.label)
                        .font(.subheadline.weight(.semibold))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(RemoteButtonStyle(tint: tint))
        .accessibilityLabel(key.label)
    }
}

struct RemoteButtonStyle: ButtonStyle {
    var tint: Color?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(tint == nil ? Color.primary : Color.white)
            .padding(.horizontal, 6)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.fill.tertiary))
            }
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.spring(duration: 0.15), value: configuration.isPressed)
    }
}

/// 音量・チャンネルの縦長ボタン
struct RockerControl: View {
    @Environment(RemoteViewModel.self) private var model
    let title: String
    let up: RegzaKey
    let down: RegzaKey
    var upImage = "plus"
    var downImage = "minus"

    var body: some View {
        VStack(spacing: 0) {
            rockerButton(up, image: upImage)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
            rockerButton(down, image: downImage)
        }
        .background(.fill.tertiary, in: Capsule())
    }

    private func rockerButton(_ key: RegzaKey, image: String) -> some View {
        Button {
            model.send(key)
        } label: {
            Image(systemName: image)
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 64)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(key.label)
    }
}

/// 十字キーと決定
struct DirectionPad: View {
    @Environment(RemoteViewModel.self) private var model

    var body: some View {
        ZStack {
            Circle().fill(.fill.tertiary)
            VStack {
                arrow(.up)
                Spacer()
                arrow(.down)
            }
            HStack {
                arrow(.left)
                Spacer()
                arrow(.right)
            }
            Button {
                model.send(.enter)
            } label: {
                Text("決定")
                    .font(.headline)
                    .frame(width: 76, height: 76)
                    .background(.fill.secondary, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 210, height: 210)
    }

    private func arrow(_ key: RegzaKey) -> some View {
        Button {
            model.send(key)
        } label: {
            Image(systemName: key.systemImage ?? "circle")
                .font(.title2.weight(.bold))
                .frame(width: 64, height: 64)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(key.label)
    }
}

/// セクション見出し付きのまとまり
struct RemoteSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
    }
}
#endif
