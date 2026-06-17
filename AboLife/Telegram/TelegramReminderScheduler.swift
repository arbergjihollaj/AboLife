import Foundation

@MainActor
final class TelegramReminderScheduler: ObservableObject {
    @Published private(set) var sentLogs: [TelegramReminderLogEntry] = []
    @Published private(set) var lastErrorMessage: String?

    private let configuration: TelegramBotConfiguration
    private let client: TelegramBotClient
    private let dailySummaryService: DailySummaryService
    private let reminderService: ReminderService
    private let calendar: Calendar
    private let now: () -> Date
    private let tickNanoseconds: UInt64
    private var schedulerTask: Task<Void, Never>?
    private var sentKeys: Set<String> = []

    init(
        configuration: TelegramBotConfiguration,
        client: TelegramBotClient,
        dailySummaryService: DailySummaryService,
        reminderService: ReminderService,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init,
        tickNanoseconds: UInt64 = 60_000_000_000
    ) {
        self.configuration = configuration
        self.client = client
        self.dailySummaryService = dailySummaryService
        self.reminderService = reminderService
        self.calendar = calendar
        self.now = now
        self.tickNanoseconds = tickNanoseconds
    }

    deinit {
        schedulerTask?.cancel()
    }

    var isRunning: Bool {
        schedulerTask != nil
    }

    func start() {
        guard schedulerTask == nil else { return }
        guard configuration.isEnabled, configuration.allowedChatId != nil else { return }
        schedulerTask = Task { [weak self] in
            await self?.loop()
        }
    }

    func stop() {
        schedulerTask?.cancel()
        schedulerTask = nil
    }

    func processDueRemindersForTests(at date: Date) async {
        await processDueReminders(at: date)
    }

    private func loop() async {
        while !Task.isCancelled {
            await processDueReminders(at: now())
            if !Task.isCancelled {
                try? await Task.sleep(nanoseconds: tickNanoseconds)
            }
        }
    }

    private func processDueReminders(at date: Date) async {
        guard let chatId = configuration.allowedChatId else { return }
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)

        do {
            if hour == 9, minute == 0 {
                try await sendOnce(try dailySummaryService.morningSummary(for: date), chatId: chatId, date: date)
                if let reminder = try reminderService.morningHabitReminder(for: date) {
                    try await sendOnce(reminder, chatId: chatId, date: date)
                }
            }

            if hour == 17, minute == 0, let reminder = try reminderService.trainingReminder(for: date) {
                try await sendOnce(reminder, chatId: chatId, date: date)
            }

            if hour == 21, minute == 0, let reminder = try reminderService.eveningCheck(for: date) {
                try await sendOnce(reminder, chatId: chatId, date: date)
            }
        } catch {
            lastErrorMessage = (error as? LocalizedError)?.errorDescription ?? "Reminder konnte nicht gesendet werden."
        }
    }

    private func sendOnce(_ message: TelegramReminderMessage, chatId: Int64, date: Date) async throws {
        let key = "\(DateIntervals.dayKey(for: date, calendar: calendar)).\(message.kind.rawValue)"
        guard !sentKeys.contains(key) else { return }
        try await client.send(TelegramResponse(chatId: chatId, text: message.text, keyboard: message.keyboard))
        sentKeys.insert(key)
        sentLogs.insert(TelegramReminderLogEntry(kind: message.kind, sentAt: date, chatId: chatId, summary: message.text), at: 0)
        print("AboLife Telegram reminder sent: \(message.kind.rawValue)")
    }
}
