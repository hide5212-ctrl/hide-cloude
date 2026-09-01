import SwiftUI

struct ContentView: View {
    @State private var model = SeatingModel.load()
    @State private var showSettings = false
    @State private var notice: String?
    @State private var noticeIsError = false

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// iPhone の縦画面ではコの字の図が収まらないので、席順の一覧を既定にする。
    private var isCompact: Bool { sizeClass == .compact }
    private var metrics: RoomMetrics { isCompact ? .compact : .regular }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                statsBar
                modePicker
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                Group {
                    if model.mode == .map {
                        RoomView(model: model, metrics: metrics, onTapSeat: tapSeat)
                    } else {
                        RosterView(model: model, onTapSeat: tapSeat)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Palette.bg)
            .navigationTitle("コの字席くじ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: model.shareText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(model.drawnAt == nil)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("設定")
                }
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .sheet(isPresented: $showSettings) {
                SettingsSheet(model: model)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: model.feedbackTick)
            .onAppear {
                // 起動直後は端末に合わせた表示から始める
                if model.drawnAt == nil {
                    model.mode = isCompact ? .list : .map
                }
                model.normalize()
            }
        }
        .tint(Palette.accent)
    }

    // MARK: - 部品

    private var statsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                stat("\(model.config.total)", "席", Palette.ink)
                stat("\(model.names.count)", "参加者", Palette.ink)
                stat("\(model.pins.count)", "固定", Palette.pin)
                stat("\(model.emptySeatCount)", "空席", Palette.muted)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 10)
    }

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(Palette.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.line))
    }

    private var modePicker: some View {
        Picker("表示", selection: Binding(
            get: { model.mode },
            set: { model.mode = $0; model.save() }
        )) {
            ForEach(DisplayMode.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if let notice {
                Text(notice)
                    .font(.system(size: 13))
                    .foregroundStyle(noticeIsError ? Palette.pin : Palette.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(noticeIsError ? Palette.pinSoft : Palette.accentSoft,
                                in: RoundedRectangle(cornerRadius: 9))
                    .transition(.opacity)
            }

            Button {
                Task { await runDraw() }
            } label: {
                Text(model.isDrawing ? "抽選中…" : "抽選する")
                    .font(.system(size: 17, weight: .bold))
                    .tracking(4)
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.isDrawing || model.validationMessage != nil)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.bar)
        .animation(.easeOut(duration: 0.2), value: notice)
    }

    // MARK: - 操作

    private func runDraw() async {
        await model.draw(animated: !reduceMotion)
        if let problem = model.validationMessage {
            show(problem, isError: true)
        } else {
            show("抽選しました。席をタップすると固定できます。")
        }
    }

    private func tapSeat(_ index: Int) {
        guard !model.isDrawing else { return }
        let message = model.togglePin(seat: index)
        show(message, isError: model.name(at: index) == nil)
    }

    private func show(_ message: String, isError: Bool = false) {
        notice = message
        noticeIsError = isError
    }
}

#Preview {
    ContentView()
}
