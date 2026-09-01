import SwiftUI

/// 席順の一覧。コの字の図は横に広く iPhone の縦画面には収まらないので、
/// 狭い画面ではこちらを既定の表示にしている。
struct RosterView: View {
    var model: SeatingModel
    var onTapSeat: (Int) -> Void

    /// 辺ごとのまとまり。左辺 → 上辺 → 右辺 の順に並ぶ。
    private struct SideSection: Identifiable {
        var id: String { side }
        var side: String
        var indices: [Int]
    }

    private var sections: [SideSection] {
        var result: [SideSection] = []
        for index in 0..<model.config.total {
            let label = model.side(of: index).label
            if result.last?.side == label {
                result[result.count - 1].indices.append(index)
            } else {
                result.append(SideSection(side: label, indices: [index]))
            }
        }
        return result
    }

    var body: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.indices, id: \.self) { index in
                        row(index)
                    }
                } header: {
                    Text(section.side)
                        .font(.system(size: 11, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(Palette.muted)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.bg)
    }

    private func row(_ index: Int) -> some View {
        let name = model.name(at: index)
        let pinned = model.isPinned(seat: index)

        return Button {
            onTapSeat(index)
        } label: {
            HStack(spacing: 12) {
                Text(model.seatNumber(index))
                    .font(.system(size: 13, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(pinned ? Palette.pin : Palette.muted)
                    .frame(width: 26, alignment: .leading)

                Text(model.side(of: index).text)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                    .frame(width: 46, alignment: .leading)

                Text(name ?? "空席")
                    .font(.system(size: 17, weight: name == nil ? .regular : .bold))
                    .foregroundStyle(name == nil ? Palette.muted : Palette.ink)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if pinned {
                    Text("固定")
                        .font(.system(size: 10.5, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Palette.surface)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 2)
                        .background(Palette.pin, in: Capsule())
                }
            }
            .frame(minHeight: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(pinned ? Palette.pinSoft : Palette.surface)
        .animation(.easeOut(duration: 0.18), value: name)
    }
}
