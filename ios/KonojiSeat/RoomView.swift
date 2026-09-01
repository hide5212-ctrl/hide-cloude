import SwiftUI

/// 席カード1枚ぶんの寸法。iPhone と iPad で差し替える。
struct RoomMetrics {
    var sideSeat: CGSize
    var topSeat: CGSize
    var deskThickness: CGFloat
    var gap: CGFloat
    var nameSize: CGFloat

    static let compact = RoomMetrics(sideSeat: CGSize(width: 104, height: 58),
                                     topSeat: CGSize(width: 86, height: 66),
                                     deskThickness: 24, gap: 8, nameSize: 15)

    static let regular = RoomMetrics(sideSeat: CGSize(width: 132, height: 70),
                                     topSeat: CGSize(width: 118, height: 78),
                                     deskThickness: 34, gap: 10, nameSize: 17)
}

/// コの字の見取り図。机を実際にコの字に描き、その外側に席を並べる。
struct RoomView: View {
    var model: SeatingModel
    var metrics: RoomMetrics
    var onTapSeat: (Int) -> Void

    private var sideColumnWidth: CGFloat { metrics.sideSeat.width + 12 }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 0) {
                kamizaBadge
                    .padding(.bottom, 10)

                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        spacer
                        HStack(spacing: metrics.gap) {
                            ForEach(model.topIndices, id: \.self) { seat(at: $0, size: metrics.topSeat) }
                        }
                        .padding(.bottom, 12)
                        .gridCellColumns(3)
                        spacer
                    }

                    GridRow {
                        spacer
                        deskTop
                            .frame(height: metrics.deskThickness)
                            .gridCellColumns(3)
                        spacer
                    }

                    GridRow {
                        VStack(spacing: metrics.gap) {
                            ForEach(model.leftIndices, id: \.self) { seat(at: $0, size: metrics.sideSeat) }
                        }
                        .padding(.trailing, 12)

                        deskSide(rounded: .leading)
                            .frame(width: metrics.deskThickness)

                        centerSpace

                        deskSide(rounded: .trailing)
                            .frame(width: metrics.deskThickness)

                        VStack(spacing: metrics.gap) {
                            ForEach(model.rightIndices, id: \.self) { seat(at: $0, size: metrics.sideSeat) }
                        }
                        .padding(.leading, 12)
                    }
                }

                frontBar
                    .padding(.top, 14)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
        }
    }

    private var spacer: some View {
        Color.clear.frame(width: sideColumnWidth, height: 1)
    }

    private var kamizaBadge: some View {
        Text("上座")
            .font(Typeface.mincho(12))
            .tracking(6)
            .foregroundStyle(Palette.accent)
            .padding(.leading, 6)
            .padding(.horizontal, 14)
            .padding(.vertical, 3)
            .background(Palette.accentSoft, in: Capsule())
    }

    private var deskTop: some View {
        UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 0,
                               bottomTrailingRadius: 0, topTrailingRadius: 10)
            .fill(Palette.desk)
            .overlay(alignment: .leading) {
                Text("上辺")
                    .font(.system(size: 10, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Palette.muted)
                    .padding(.leading, 10)
            }
    }

    private func deskSide(rounded edge: HorizontalEdge) -> some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: edge == .leading ? 10 : 0,
            bottomTrailingRadius: edge == .trailing ? 10 : 0,
            topTrailingRadius: 0
        )
        .fill(Palette.desk)
        .frame(maxHeight: .infinity)
    }

    private var centerSpace: some View {
        VStack(spacing: 5) {
            Text("中央スペース")
                .font(Typeface.mincho(13))
                .tracking(5)
            Text(drawnAtText)
                .font(.system(size: 11, design: .monospaced))
                .monospacedDigit()
        }
        .foregroundStyle(Palette.muted)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: 120, minHeight: 140)
        .padding(12)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Palette.line2, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .padding(12)
        }
    }

    private var frontBar: some View {
        VStack(spacing: 7) {
            Rectangle().fill(Palette.line2).frame(height: 2)
            Text("スクリーン ／ 入口")
                .font(.system(size: 11, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Palette.muted)
        }
    }

    private var drawnAtText: String {
        guard let drawnAt = model.drawnAt else { return "未抽選" }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        return "抽選 " + fmt.string(from: drawnAt)
    }

    private func seat(at index: Int, size: CGSize) -> some View {
        SeatCard(number: model.seatNumber(index),
                 name: model.name(at: index),
                 pinned: model.isPinned(seat: index),
                 size: size,
                 nameSize: metrics.nameSize)
            .onTapGesture { onTapSeat(index) }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("\(model.seatLabel(index))、\(model.name(at: index) ?? "空席")"
                                     + (model.isPinned(seat: index) ? "、固定" : "")))
            .accessibilityAddTraits(.isButton)
    }
}

struct SeatCard: View {
    var number: String
    var name: String?
    var pinned: Bool
    var size: CGSize
    var nameSize: CGFloat

    var body: some View {
        VStack(spacing: 2) {
            Text(number)
                .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                .monospacedDigit()
                .tracking(1)
                .foregroundStyle(pinned ? Palette.pin : Palette.muted)
            Text(name ?? "空席")
                .font(.system(size: nameSize, weight: name == nil ? .regular : .bold))
                .foregroundStyle(name == nil ? Palette.muted : Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: size.width, height: size.height)
        .background(name == nil ? Color.clear : (pinned ? Palette.pinSoft : Palette.surface2),
                    in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(pinned ? Palette.pin : Palette.line2,
                              style: StrokeStyle(lineWidth: pinned ? 1.5 : 1,
                                                 dash: name == nil ? [4, 4] : []))
        }
        .overlay(alignment: .topTrailing) {
            if pinned {
                Text("固定")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Palette.surface)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 1)
                    .background(Palette.pin, in: Capsule())
                    .offset(x: 6, y: -8)
            }
        }
        .animation(.easeOut(duration: 0.18), value: name)
        .animation(.easeOut(duration: 0.18), value: pinned)
    }
}
