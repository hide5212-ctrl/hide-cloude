import SwiftUI

/// 参加者・席の配置・固定席をまとめて編集するシート。
struct SettingsSheet: View {
    @Bindable var model: SeatingModel
    @Environment(\.dismiss) private var dismiss

    @State private var namesText = ""
    @State private var newPinName = ""
    @State private var newPinSeat = -1

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $namesText)
                        .frame(minHeight: 220)
                        .font(.system(size: 16))
                        .onChange(of: namesText) { _, text in
                            model.names = text
                                .components(separatedBy: .newlines)
                                .map { $0.trimmingCharacters(in: .whitespaces) }
                                .filter { !$0.isEmpty }
                            model.normalize()
                            model.save()
                        }
                } header: {
                    Text("参加者（1行に1名）")
                } footer: {
                    if let message = model.validationMessage {
                        Text(message).foregroundStyle(Palette.pin)
                    } else {
                        Text("\(model.names.count)名／\(model.config.total)席")
                    }
                }

                Section("席の配置") {
                    stepper("上辺", value: $model.config.top)
                    stepper("左辺", value: $model.config.left)
                    stepper("右辺", value: $model.config.right)
                    LabeledContent("合計") {
                        Text("\(model.config.total) 席").monospacedDigit()
                    }
                }

                Section {
                    if model.pins.isEmpty {
                        Text("固定席はありません。")
                            .foregroundStyle(Palette.muted)
                    }
                    ForEach(pinnedNames, id: \.self) { name in
                        HStack {
                            Text(name).fontWeight(.semibold)
                            Spacer()
                            Text(model.pins[name].map { model.seatLabel($0) } ?? "")
                                .foregroundStyle(Palette.muted)
                                .font(.system(size: 14))
                        }
                        .swipeActions {
                            Button("解除", role: .destructive) { model.removePin(name: name) }
                        }
                    }
                    addPinRow
                } header: {
                    Text("固定席")
                } footer: {
                    Text("ここで指定した人は抽選から外れ、その席に座り続けます。席を直接タップしても固定できます。")
                }

                Section {
                    Button("初期設定に戻す", role: .destructive) {
                        model.reset()
                        namesText = model.names.joined(separator: "\n")
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
        .onAppear { namesText = model.names.joined(separator: "\n") }
        .onDisappear {
            model.normalize()
            model.save()
        }
    }

    /// 席番号の小さい順に並べた、固定されている人の名前。
    private var pinnedNames: [String] {
        model.pins.sorted { $0.value < $1.value }.map { $0.key }
    }

    private var addPinRow: some View {
        HStack {
            Picker("人", selection: $newPinName) {
                Text("— 人を選ぶ —").tag("")
                ForEach(model.names, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()

            Picker("席", selection: $newPinSeat) {
                Text("— 席 —").tag(-1)
                ForEach(Array(0..<model.config.total), id: \.self) { index in
                    Text("席\(model.seatNumber(index))").tag(index)
                }
            }
            .labelsHidden()

            Button("固定") {
                model.pin(name: newPinName, to: newPinSeat)
                newPinName = ""
                newPinSeat = -1
            }
            .buttonStyle(.borderedProminent)
            .disabled(newPinName.isEmpty || newPinSeat < 0)
        }
    }

    private func stepper(_ title: String, value: Binding<Int>) -> some View {
        Stepper(value: value, in: 0...12) {
            LabeledContent(title) {
                Text("\(value.wrappedValue)").monospacedDigit()
            }
        }
        .onChange(of: value.wrappedValue) { _, _ in
            model.normalize()
            model.save()
        }
    }
}
