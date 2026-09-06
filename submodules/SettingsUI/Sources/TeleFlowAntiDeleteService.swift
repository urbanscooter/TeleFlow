import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore
import AccountContext

/// Сервис анти-удаления сообщений.
///
/// Когда `TeleFlowSettings.shared.isAntiDeleteEnabled == true`, данный модуль перехватывает
/// события удаления сообщений и отменяет локальное удаление объекта из Postbox-хранилища.
/// Статус удаления отслеживается через UserDefaults (Set<String>), без кастомного атрибута.
public final class TeleFlowAntiDeleteService {

    /// Shared-инстанс.
    public static let shared = TeleFlowAntiDeleteService()

    /// Notification.Name для уведомления о попытке удаления сообщений.
    /// Постылается из _internal_deleteMessagesInteractively в TelegramCore.
    public static let messagesWillBeDeletedNotification = Notification.Name("TeleFlowMessagesWillBeDeleted")

    /// Имя UserDefaults-ключа для хранения pending-messageIds на удаление.
    private let pendingDeleteKey = "TeleFlow_pendingDeleteMessageIds"

    /// Notification.Name уведомления о готовности account.
    /// Постылается из AppDelegate когда AccountContext доступен.
    public static let accountReadyNotification = Notification.Name("TeleFlowAccountReady")

    private var accountContext: AccountContext?
    private var deletionObserver: NSObjectProtocol?
    private var accountReadyObserver: NSObjectProtocol?
    private let queue = Queue()

    private init() {
        // Подписываемся на уведомление о готовности AccountContext.
        self.accountReadyObserver = NotificationCenter.default.addObserver(
            forName: Self.accountReadyNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            if let context = notification.userInfo?["context"] as? AccountContext {
                self?.accountContext = context
                self?.processPendingDeletions()
            }
        }
        startObservingDeletions()
    }

    deinit {
        if let observer = deletionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = accountReadyObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Регистрирует AccountContext для работы с postbox.
    /// Вызывать из AppDelegate после инициализации контекста.
    public func registerAccountContext(_ context: AccountContext) {
        self.accountContext = context
        processPendingDeletions()
    }

    /// Подписывается на уведомления о попытке удаления и сохраняет pending-IDs.
    private func startObservingDeletions() {
        guard deletionObserver == nil else { return }
        deletionObserver = NotificationCenter.default.addObserver(
            forName: Self.messagesWillBeDeletedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard TeleFlowSettings.shared.isAntiDeleteEnabled else { return }
            guard let messageIds = notification.userInfo?["messageIds"] as? [MessageId] else { return }
            self?.enqueuePendingDeletions(messageIds)
        }
    }

    /// Сохраняет messageIds для отложенной обработки.
    private func enqueuePendingDeletions(_ messageIds: [MessageId]) {
        var pending = loadPendingItems()
        for id in messageIds {
            let item = SerializedMessageId(messageId: id)
            if !pending.contains(item) {
                pending.append(item)
            }
        }
        savePendingItems(pending)
        processPendingDeletions()
    }

    private func processPendingDeletions() {
        guard let context = accountContext, TeleFlowSettings.shared.isAntiDeleteEnabled else { return }

        let pending = loadPendingItems()
        guard !pending.isEmpty else { return }

        let messageIds = pending.map { $0.toMessageId() }
        guard !messageIds.isEmpty else {
            savePendingItems([])
            return
        }

        let account = context.account

        _ = account.postbox.transaction { transaction -> Void in
            for messageId in messageIds {
                if let message = transaction.getMessage(messageId) {
                    self.markMessageAsDeleted(messageId: messageId, transaction: transaction)
                }
            }
        }.start(completed: { [weak self] in
            self?.clearPendingItems()
        })
    }

    /// Помечает сообщение как удалённое — записываем ID в UserDefaults.
    /// Само сообщение НЕ мутируется; визуальный маркер (🗑) отрисовывается
    /// на уровне UI по ключу из `isMessageMarkedAsDeleted`.
    private func markMessageAsDeleted(messageId: MessageId, transaction: Transaction) {
        guard !isMessageMarkedAsDeleted(messageId) else { return }

        // Запоминаем в UserDefaults полный messageId (peerId + namespace + id).
        var deletedIds = loadDeletedIds()
        let key = deletedMessageKey(for: messageId)
        if !deletedIds.contains(key) {
            deletedIds.insert(key)
            saveDeletedIds(deletedIds)
        }
    }

    /// Ключ UserDefaults для отслеживания удалённых сообщений.
    private let deletedMessagesKey = "TeleFlow_deletedMessages"

    // MARK: - Хранение маркеров удалённых сообщений (Set<String>)

    /// Ключ для сериализации в виде строки "peerId_namespace_id".
    private func deletedMessageKey(for messageId: MessageId) -> String {
        return "\(messageId.peerId.toInt64())_\(messageId.namespace)_\(messageId.id)"
    }

    /// ID удалённых сообщений в виде Set<String>.
    private func loadDeletedIds() -> Set<String> {
        let data = TeleFlowSettings.shared.userDefaults.object(forKey: deletedMessagesKey) as? Data
        guard let data else { return [] }
        return (try? JSONDecoder().decode(Set<String>.self, from: data)) ?? []
    }

    private func saveDeletedIds(_ ids: Set<String>) {
        guard let data = try? JSONEncoder().encode(ids) else { return }
        TeleFlowSettings.shared.userDefaults.set(data, forKey: deletedMessagesKey)
    }

    // MARK: - Pending (для отложенной обработки)

    private func loadPendingItems() -> [SerializedMessageId] {
        let data = TeleFlowSettings.shared.userDefaults.object(forKey: pendingDeleteKey) as? Data
        guard let data else { return [] }
        return (try? JSONDecoder().decode([SerializedMessageId].self, from: data)) ?? []
    }

    private func savePendingItems(_ items: [SerializedMessageId]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        TeleFlowSettings.shared.userDefaults.set(data, forKey: pendingDeleteKey)
    }

    private func clearPendingItems() {
        savePendingItems([])
    }

    // MARK: - Проверка: было ли сообщение удалено

    /// Возвращает `true`, если сообщение с указанным ID было помечено как удалённое TeleFlow.
    public func isMessageMarkedAsDeleted(_ messageId: MessageId) -> Bool {
        let ids = loadDeletedIds()
        return ids.contains(deletedMessageKey(for: messageId))
    }

    /// Возвращает строку-маркер 🗑 для отображения рядом со временем отправки.
    public func deletionMarkerIcon() -> String {
        return "🗑"
    }

    /// Возвращает текст-маркер `[TeleFlow: Удалено]`.
    public func deletionMarkerText() -> String {
        return "[TeleFlow: Удалено]"
    }

    // MARK: - Отключение режима

    /// Очищает все сохранённые маркеры удалённых сообщений (полный сброс).
    public func clearAllDeletedMarkers() {
        saveDeletedIds([])
    }
}

// MARK: - Сериализуемая обёртка для MessageId

/// Codable-обёртка `MessageId` для долговременного хранения в UserDefaults.
/// Сохраняет полную структуру (peerId + namespace + id), чтобы
/// `transaction.getMessage(messageId)` находил нужный объект в Postbox.
public struct SerializedMessageId: Codable, Equatable, Hashable {
    public let peerId: Int64
    public let namespace: Int32
    public let id: Int32

    public init(messageId: MessageId) {
        self.peerId = messageId.peerId.toInt64()
        self.namespace = messageId.namespace
        self.id = messageId.id
    }

    public init(peerId: Int64, namespace: Int32, id: Int32) {
        self.peerId = peerId
        self.namespace = namespace
        self.id = id
    }

    public func toMessageId() -> MessageId {
        // MessageId.Namespace — typealias на Int32, поэтому никаких rawValue не нужно.
        let peer = PeerId(self.peerId)
        return MessageId(peerId: peer, namespace: self.namespace, id: self.id)
    }
}

// MARK: - Утилита для UI-отображения маркера

/// Проверяет, содержит ли текст сообщения маркер TeleFlow-удаления.
public func messageContainsTeleFlowDeletionMarker(_ text: String) -> Bool {
    return text.contains(TeleFlowAntiDeleteService.deletionMarkerText)
}
