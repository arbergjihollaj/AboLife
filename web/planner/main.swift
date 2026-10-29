import Foundation

// Uses the exact planning engine compiled into the Mac app. No duplicate scheduling rules.
struct Input: Decodable { var calendar: CalendarWorkspace; var now: Date? }
struct Output: Encodable { var calendar: CalendarWorkspace; var issues: [String]; var unplaced: [String: String] }
do {
    let input = try JSONDecoder().decode(Input.self, from: FileHandle.standardInput.readDataToEndOfFile())
    var calendar = input.calendar
    let result = StudyPlannerEngine.plan(calendar, now: input.now ?? Date())
    calendar.topics = result.topics; calendar.sessions = result.sessions
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    FileHandle.standardOutput.write(try encoder.encode(Output(calendar: calendar, issues: result.issues.map(\.message), unplaced: result.unplaced)))
} catch {
    FileHandle.standardError.write(Data("Planung fehlgeschlagen: \(error.localizedDescription)\n".utf8))
    exit(1)
}
