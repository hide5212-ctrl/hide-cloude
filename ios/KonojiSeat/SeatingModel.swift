import Foundation
import Observation

/// コの字の三辺それぞれの席数。
struct SeatConfig: Codable, Equatable {
    var top: Int = 4
    var left: Int = 5
    var right: Int = 5

    var total: Int { top + left + right }
}

/// 席がコの字のどの辺の何番目かを表す。
struct SeatSide: Equatable {
    var label: String
    var position: Int

    var text: String { "\(label)\(position)" }
}

enum DisplayMode: String, Codable, CaseIterable, Identifiable {
    case map, list
    var id: String { rawValue }
    var title: String { self == .map ? "見取り図" : "席順" }
}

@Observable
final class SeatingModel {

    // 参加者の初期値は空。使う人が自分の名簿を入れるところから始める
    var names: [String] = []
    var config = SeatConfig()
    /// 名前 → 席番号（0 始まり）。ここに入っている人は抽選から外れ、その席に座り続ける。
    var pins: [String: Int] = [:]
    var assignment: [String?] = []
    var drawnAt: Date?
    var mode: DisplayMode = .map

    var isDrawing = false
    /// 触覚フィードバックを鳴らすためのカウンタ。
    var feedbackTick = 0

    // MARK: - 席の並び
    // 入口側の左から時計回り: 左辺（手前→奥）→ 上辺（左→右）→ 右辺（奥→手前）

    func side(of index: Int) -> SeatSide {
        if index < config.left {
            return SeatSide(label: "左辺", position: config.left - index)
        }
        if index < config.left + config.top {
            return SeatSide(label: "上辺", position: index - config.left + 1)
        }
        return SeatSide(label: "右辺", position: index - config.left - config.top + 1)
    }

    func seatNumber(_ index: Int) -> String {
        String(format: "%02d", index + 1)
    }

    func seatLabel(_ index: Int) -> String {
        "席\(seatNumber(index))（\(side(of: index).text)）"
    }

    var leftIndices: [Int] { Array((0..<config.left).reversed()) }   // 奥（上座寄り）が上
    var topIndices: [Int] { Array(config.left..<(config.left + config.top)) }
    var rightIndices: [Int] { Array((config.left + config.top)..<config.total) }

    func name(at index: Int) -> String? {
        guard assignment.indices.contains(index) else { return nil }
        return assignment[index]
    }

    func isPinned(seat index: Int) -> Bool {
        guard let name = name(at: index) else { return false }
        return pins[name] == index
    }

    func isPinnedSeat(_ index: Int) -> Bool {
        pins.values.contains(index)
    }

    // MARK: - 状態の整合

    func normalize() {
        if assignment.count != config.total {
            assignment = Array(repeating: nil, count: config.total)
            drawnAt = nil
        }
        var cleaned: [String: Int] = [:]
        var takenSeats = Set<Int>()
        for (name, seat) in pins.sorted(by: { $0.value < $1.value }) {
            guard names.contains(name), seat >= 0, seat < config.total else { continue }
            guard !takenSeats.contains(seat) else { continue }
            takenSeats.insert(seat)
            cleaned[name] = seat
        }
        pins = cleaned
    }

    var duplicatedNames: [String] {
        var seen = Set<String>()
        var dup: [String] = []
        for name in names where !seen.insert(name).inserted && !dup.contains(name) {
            dup.append(name)
        }
        return dup
    }

    /// 抽選できない理由。nil なら抽選できる。
    var validationMessage: String? {
        if names.isEmpty { return "参加者の名前を入力すると抽選できます。" }
        if config.total == 0 { return "席が0です。上辺・左辺・右辺の数を設定してください。" }
        if names.count > config.total {
            return "参加者\(names.count)名に対して席が\(config.total)しかありません。席数を増やしてください。"
        }
        let dup = duplicatedNames
        if !dup.isEmpty {
            return "同じ名前があります（\(dup.joined(separator: "、"))）。区別できる表記にしてください。"
        }
        return nil
    }

    var emptySeatCount: Int {
        max(0, config.total - assignment.compactMap { $0 }.count)
    }

    // MARK: - 抽選

    private func computeAssignment() -> [String?] {
        var result = [String?](repeating: nil, count: config.total)
        var used = Set<String>()
        for (name, seat) in pins {
            result[seat] = name
            used.insert(name)
        }
        var rest = names.filter { !used.contains($0) }.shuffled()
        for index in result.indices where result[index] == nil {
            if rest.isEmpty { break }
            result[index] = rest.removeFirst()
        }
        return result
    }

    @MainActor
    func draw(animated: Bool) async {
        normalize()
        guard validationMessage == nil, !isDrawing else { return }

        let final = computeAssignment()
        guard animated else {
            assignment = final
            drawnAt = Date()
            feedbackTick += 1
            save()
            return
        }

        isDrawing = true
        let freeSeats = (0..<config.total).filter { !isPinnedSeat($0) }

        // 名前を高速で入れ替えて「抽選中」を見せる
        for _ in 0..<14 {
            for seat in freeSeats { assignment[seat] = names.randomElement() }
            try? await Task.sleep(for: .milliseconds(62))
        }
        // 手前の席から順に確定させていく
        for seat in freeSeats {
            assignment[seat] = final[seat]
            try? await Task.sleep(for: .milliseconds(48))
        }

        assignment = final
        drawnAt = Date()
        isDrawing = false
        feedbackTick += 1
        save()
    }

    // MARK: - 固定

    /// 席をタップしたときの固定 / 解除。戻り値は画面に出す案内文。
    @discardableResult
    func togglePin(seat index: Int) -> String {
        guard let name = name(at: index) else {
            return "空席は固定できません。先に抽選してください。"
        }
        if pins[name] == index {
            pins[name] = nil
            feedbackTick += 1
            save()
            return "\(name) さんの固定を解除しました。"
        }
        // その席に別の人が固定されていたら、そちらの固定を外して入れ替える
        for (other, seat) in pins where seat == index { pins[other] = nil }
        pins[name] = index
        feedbackTick += 1
        save()
        return "\(name) さんを \(seatLabel(index)) に固定しました。次の抽選でもこの席のままです。"
    }

    /// 固定席を設定パネルから指定したとき、その席の中身と入れ替える。
    func pin(name: String, to seat: Int) {
        guard names.contains(name), seat >= 0, seat < config.total else { return }
        for (other, taken) in pins where taken == seat { pins[other] = nil }
        pins[name] = seat

        if assignment.count == config.total, assignment[seat] != name {
            let displaced = assignment[seat]
            if let current = assignment.firstIndex(where: { $0 == name }) {
                assignment[current] = displaced
            }
            assignment[seat] = name
        }
        save()
    }

    func removePin(name: String) {
        pins[name] = nil
        save()
    }

    /// 席だけ空にする。参加者リストはそのまま残すので、すぐ抽選し直せる。
    func clearSeats() {
        pins = [:]
        assignment = Array(repeating: nil, count: config.total)
        drawnAt = nil
        save()
    }

    /// 参加者リストごと空にする。席の配置（上辺・左辺・右辺の数）は残す。
    func clearAll() {
        names = []
        clearSeats()
    }

    // MARK: - 書き出し

    var shareText: String {
        var lines = ["座席表（コの字型 / \(config.total)席）"]
        if let drawnAt {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd HH:mm"
            lines.append("抽選 " + fmt.string(from: drawnAt))
        } else {
            lines.append("未抽選")
        }
        lines.append("")

        var lastSide = ""
        for index in 0..<config.total {
            let meta = side(of: index)
            if meta.label != lastSide {
                lines.append("[\(meta.label)]")
                lastSide = meta.label
            }
            let who = name(at: index) ?? "空席"
            lines.append("  \(seatNumber(index))  \(who)" + (isPinned(seat: index) ? "（固定）" : ""))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - 保存

    private struct Snapshot: Codable {
        var names: [String]
        var config: SeatConfig
        var pins: [String: Int]
        var assignment: [String?]
        var drawnAt: Date?
        var mode: DisplayMode
    }

    private static let storeKey = "konoji-seat-v1"

    func save() {
        let snapshot = Snapshot(names: names, config: config, pins: pins,
                                assignment: assignment, drawnAt: drawnAt, mode: mode)
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.storeKey)
        }
    }

    static func load() -> SeatingModel {
        let model = SeatingModel()
        if let data = UserDefaults.standard.data(forKey: storeKey),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            model.names = snapshot.names
            model.config = snapshot.config
            model.pins = snapshot.pins
            model.assignment = snapshot.assignment
            model.drawnAt = snapshot.drawnAt
            model.mode = snapshot.mode
        }
        model.normalize()
        return model
    }
}
