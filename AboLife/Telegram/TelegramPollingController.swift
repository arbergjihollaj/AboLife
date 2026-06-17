import Foundation

enum TelegramPollingState: Equatable {
    case notConfigured
    case ready
    case running
    case stopped
    case error(String)

    var label: String {
        switch self {
        case .notConfigured:
            return "Telegram nicht konfiguriert"
        case .ready:
            return "Telegram bereit"
        case .running:
            return "Telegram läuft"
        case .stopped:
            return "Telegram gestoppt"
        case .error:
            return "Telegram Fehler"
        }
    }
}

struct NoopTelegramUpdateClient: TelegramUpdateFetching {
    func getUpdates(offset: Int?, timeout: Int) async throws -> [TelegramUpdate] {
        []
    }

    func answerCallbackQuery(id: String) async throws {}
}

final class NoopTelegramBotClient: TelegramBotClient {
    func send(_ response: TelegramResponse) async throws {}
}

@MainActor
final class TelegramPollingController: ObservableObject {
    @Published private(set) var state: TelegramPollingState
    @Published private(set) var detailMessage: String
    @Published private(set) var lastUpdateId: Int?
    @Published private(set) var lastErrorMessage: String?

    private let configuration: TelegramBotConfiguration
    private let updateClient: TelegramUpdateFetching
    private let botService: TelegramBotService
    private var pollingTask: Task<Void, Never>?
    private var offset: Int?
    private let pollTimeoutSeconds: Int
    private let idleDelayNanoseconds: UInt64
    private let errorDelayNanoseconds: UInt64
    private let automaticallyPollsOnStart: Bool

    init(
        configuration: TelegramBotConfiguration,
        updateClient: TelegramUpdateFetching,
        botService: TelegramBotService,
        pollTimeoutSeconds: Int = 25,
        idleDelayNanoseconds: UInt64 = 300_000_000,
        errorDelayNanoseconds: UInt64 = 2_000_000_000,
        automaticallyPollsOnStart: Bool = true
    ) {
        self.configuration = configuration
        self.updateClient = updateClient
        self.botService = botService
        self.pollTimeoutSeconds = pollTimeoutSeconds
        self.idleDelayNanoseconds = idleDelayNanoseconds
        self.errorDelayNanoseconds = errorDelayNanoseconds
        self.automaticallyPollsOnStart = automaticallyPollsOnStart
        self.state = configuration.isEnabled ? .ready : .notConfigured
        self.detailMessage = configuration.isEnabled
            ? Self.allowedChatDetail(configuration.allowedChatId)
            : "Setze ABOLIFE_TELEGRAM_BOT_TOKEN lokal, um Telegram zu aktivieren."
    }

    deinit {
        pollingTask?.cancel()
    }

    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    var canStart: Bool {
        configuration.isEnabled && configuration.allowedChatId != nil && !isRunning
    }

    func start() {
        guard configuration.isEnabled else {
            state = .notConfigured
            detailMessage = "Telegram ist ohne lokalen Token deaktiviert."
            return
        }
        guard configuration.allowedChatId != nil else {
            state = .ready
            detailMessage = "Setze ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID lokal, bevor Telegram starten kann."
            return
        }
        guard !isRunning else { return }
        guard pollingTask == nil else { return }

        state = .running
        detailMessage = "Long Polling läuft."
        lastErrorMessage = nil
        if automaticallyPollsOnStart {
            pollingTask = Task { [weak self] in
                await self?.pollLoop()
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        if configuration.isEnabled {
            state = .stopped
            detailMessage = "Telegram wurde gestoppt."
        } else {
            state = .notConfigured
            detailMessage = "Telegram ist ohne lokalen Token deaktiviert."
        }
    }

    func processOnceForTests() async {
        await processOnePoll()
    }

    private func pollLoop() async {
        while !Task.isCancelled {
            await processOnePoll()
            if !Task.isCancelled {
                try? await Task.sleep(nanoseconds: idleDelayNanoseconds)
            }
        }
    }

    private func processOnePoll() async {
        do {
            let updates = try await updateClient.getUpdates(offset: offset, timeout: pollTimeoutSeconds)
            for update in updates {
                guard isAllowed(update) else {
                    lastUpdateId = update.updateId
                    offset = update.updateId + 1
                    lastErrorMessage = "Update von nicht erlaubtem Telegram-Chat ignoriert."
                    continue
                }

                if let callbackId = update.callback?.callbackQueryId {
                    try? await updateClient.answerCallbackQuery(id: callbackId)
                }
                _ = await botService.handle(update)
                lastUpdateId = update.updateId
                offset = update.updateId + 1
            }
            if isRunning {
                detailMessage = updates.isEmpty ? "Keine neuen Telegram-Updates." : "Telegram-Updates verarbeitet."
            }
        } catch is CancellationError {
            stop()
        } catch {
            let message = Self.userMessage(for: error)
            state = .error(message)
            detailMessage = message
            lastErrorMessage = message
            if !Task.isCancelled {
                try? await Task.sleep(nanoseconds: errorDelayNanoseconds)
                if !Task.isCancelled {
                    state = .running
                }
            }
        }
    }

    private func isAllowed(_ update: TelegramUpdate) -> Bool {
        guard let allowedChatId = configuration.allowedChatId else { return false }
        let chatId = update.message?.chatId ?? update.callback?.chatId
        return chatId == allowedChatId
    }

    private static func userMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }
        return "Telegram ist gerade nicht erreichbar."
    }

    private static func allowedChatDetail(_ allowedChatId: Int64?) -> String {
        if allowedChatId == nil {
            return "Token gefunden. Setze ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID, damit nur dein Chat akzeptiert wird."
        }
        return "Token und erlaubter Chat sind lokal konfiguriert."
    }
}

@MainActor
final class TelegramAppCoordinator: ObservableObject {
    static let autoStartKey = "telegramAutoStartEnabled"

    @Published private(set) var state: TelegramPollingState
    @Published private(set) var detailMessage: String
    @Published private(set) var lastUpdateId: Int?
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var reminderLogCount: Int
    @Published var autoStartEnabled: Bool {
        didSet {
            userDefaults.set(autoStartEnabled, forKey: Self.autoStartKey)
            if oldValue != autoStartEnabled {
                updateConfigurationMessage()
            }
        }
    }

    private let userDefaults: UserDefaults
    private let configurationProvider: () -> TelegramBotConfiguration
    private let makeController: (TelegramBotConfiguration, AppDatabase?) -> TelegramPollingController?
    private let makeScheduler: (TelegramBotConfiguration, AppDatabase?) -> TelegramReminderScheduler?
    private var configuration: TelegramBotConfiguration
    private var database: AppDatabase?
    private var controller: TelegramPollingController?
    private var scheduler: TelegramReminderScheduler?
    private var observationTask: Task<Void, Never>?
    private var didEvaluateAutoStart = false

    init(
        database: AppDatabase? = nil,
        userDefaults: UserDefaults = .standard,
        configurationProvider: @escaping () -> TelegramBotConfiguration = { TelegramBotConfiguration.load() },
        makeController: ((TelegramBotConfiguration, AppDatabase?) -> TelegramPollingController?)? = nil,
        makeScheduler: ((TelegramBotConfiguration, AppDatabase?) -> TelegramReminderScheduler?)? = nil
    ) {
        self.userDefaults = userDefaults
        self.configurationProvider = configurationProvider
        self.makeController = makeController ?? Self.makeLiveController
        self.makeScheduler = makeScheduler ?? Self.makeLiveScheduler
        self.configuration = configurationProvider()
        self.database = database
        self.autoStartEnabled = userDefaults.bool(forKey: Self.autoStartKey)
        self.state = configuration.isEnabled ? .ready : .notConfigured
        self.detailMessage = configuration.isEnabled
            ? TelegramPollingController.allowedChatStatusMessage(configuration.allowedChatId)
            : "Setze ABOLIFE_TELEGRAM_BOT_TOKEN lokal, um Telegram zu aktivieren."
        self.lastUpdateId = nil
        self.lastErrorMessage = nil
        self.reminderLogCount = 0

        configure(database: database)
    }

    deinit {
        observationTask?.cancel()
    }

    func configure(database: AppDatabase?) {
        guard controller == nil else { return }

        self.database = database
        configuration = configurationProvider()
        observationTask?.cancel()
        controller = makeController(configuration, database)
        scheduler = makeScheduler(configuration, database)

        guard let controller else {
            state = .notConfigured
            detailMessage = database == nil ? "Telegram braucht die lokale Datenbank." : "Telegram ist ohne lokalen Token deaktiviert."
            lastUpdateId = nil
            lastErrorMessage = nil
            reminderLogCount = 0
            updateConfigurationMessage()
            return
        }

        sync()
        updateConfigurationMessage()
        observationTask = Task { [weak self, weak controller] in
            while !Task.isCancelled {
                guard let self, let controller else { return }
                self.state = controller.state
                self.detailMessage = controller.detailMessage
                self.lastUpdateId = controller.lastUpdateId
                self.lastErrorMessage = controller.lastErrorMessage
                self.reminderLogCount = self.scheduler?.sentLogs.count ?? 0
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
    }

    var canStart: Bool {
        configuration.isEnabled && configuration.allowedChatId != nil && controller?.canStart == true
    }

    var isRunning: Bool {
        controller?.isRunning == true
    }

    var hasAllowedChat: Bool {
        configuration.allowedChatId != nil
    }

    var hasToken: Bool {
        configuration.isEnabled
    }

    func start() {
        guard configuration.isEnabled else {
            state = .notConfigured
            detailMessage = "Telegram ist ohne lokalen Token deaktiviert."
            return
        }
        guard configuration.allowedChatId != nil else {
            state = .ready
            detailMessage = "Setze ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID lokal, bevor Telegram starten kann."
            return
        }
        controller?.start()
        scheduler?.start()
        sync()
    }

    func stop() {
        controller?.stop()
        scheduler?.stop()
        sync()
    }

    func applyAutoStartIfNeeded() {
        guard !didEvaluateAutoStart else { return }
        didEvaluateAutoStart = true

        guard autoStartEnabled else {
            updateConfigurationMessage()
            return
        }
        guard configuration.isEnabled else {
            state = .notConfigured
            detailMessage = "Auto-Start aktiviert, aber Token fehlt."
            return
        }
        guard configuration.allowedChatId != nil else {
            state = .ready
            detailMessage = "Auto-Start aktiviert, aber erlaubte Chat-ID fehlt."
            return
        }

        start()
    }

    func stopForAppQuit() {
        stop()
    }

    private func sync() {
        guard let controller else { return }
        state = controller.state
        detailMessage = controller.detailMessage
        lastUpdateId = controller.lastUpdateId
        lastErrorMessage = controller.lastErrorMessage
        reminderLogCount = scheduler?.sentLogs.count ?? 0
    }

    private func updateConfigurationMessage() {
        guard !isRunning else { return }

        if autoStartEnabled {
            if !configuration.isEnabled {
                state = .notConfigured
                detailMessage = "Auto-Start aktiviert, aber Token fehlt."
            } else if configuration.allowedChatId == nil {
                state = .ready
                detailMessage = "Auto-Start aktiviert, aber erlaubte Chat-ID fehlt."
            } else if case .error = state {
                return
            } else {
                state = controller?.state ?? .ready
                detailMessage = "Auto-Start bereit."
            }
            return
        }

        if !configuration.isEnabled {
            state = .notConfigured
            detailMessage = "Setze ABOLIFE_TELEGRAM_BOT_TOKEN lokal, um Telegram zu aktivieren."
        } else if configuration.allowedChatId == nil {
            state = .ready
            detailMessage = "Token gefunden. Setze ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID, damit nur dein Chat akzeptiert wird."
        } else if case .stopped = state {
            detailMessage = "Telegram wurde gestoppt."
        } else if case .error = state {
            return
        } else {
            state = controller?.state ?? .ready
            detailMessage = "Telegram bereit. Auto-Start ist aus."
        }
    }

    private static func makeLiveController(
        configuration: TelegramBotConfiguration,
        database: AppDatabase?
    ) -> TelegramPollingController? {
        guard let database else { return nil }

        let updateClient: TelegramUpdateFetching
        let responseClient: TelegramBotClient
        let barcodeFoodScanService: TelegramBarcodeFoodScanService?
        if configuration.isEnabled, let liveClient = try? TelegramLiveClient(configuration: configuration) {
            updateClient = liveClient
            responseClient = liveClient
            barcodeFoodScanService = TelegramBarcodeFoodScanService(
                fileClient: liveClient,
                scanner: BarcodeScannerService(),
                lookupService: FoodProductLookupService()
            )
        } else {
            updateClient = NoopTelegramUpdateClient()
            responseClient = NoopTelegramBotClient()
            barcodeFoodScanService = nil
        }

        let dialogManager = ExternalInputDialogManager(
            service: ExternalInputService(database: database)
        )
        let reminderService = ReminderService(database: database)
        let botService = TelegramBotService(
            configuration: configuration,
            dialogManager: dialogManager,
            client: responseClient,
            documentClient: responseClient as? TelegramDocumentClient,
            barcodeFoodScanService: barcodeFoodScanService,
            snapshotExportService: HtmlSnapshotExportService(database: database),
            reminderService: reminderService
        )
        return TelegramPollingController(
            configuration: configuration,
            updateClient: updateClient,
            botService: botService
        )
    }

    private static func makeLiveScheduler(
        configuration: TelegramBotConfiguration,
        database: AppDatabase?
    ) -> TelegramReminderScheduler? {
        guard let database else { return nil }

        let client: TelegramBotClient
        if configuration.isEnabled, let liveClient = try? TelegramLiveClient(configuration: configuration) {
            client = liveClient
        } else {
            client = NoopTelegramBotClient()
        }

        return TelegramReminderScheduler(
            configuration: configuration,
            client: client,
            dailySummaryService: DailySummaryService(database: database),
            reminderService: ReminderService(database: database)
        )
    }
}

private extension TelegramPollingController {
    static func allowedChatStatusMessage(_ allowedChatId: Int64?) -> String {
        allowedChatDetail(allowedChatId)
    }
}
