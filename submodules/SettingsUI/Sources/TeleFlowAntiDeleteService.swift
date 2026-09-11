import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public final class TeleFlowAntiDeleteService {
    public static let shared = TeleFlowAntiDeleteService()

    public static let deletionMarkerText: String = "Удалено"

    public static let accountReadyNotification =
        Notification.Name("TeleFlowAntiDeleteService.accountReady")

    private static let deletedIdsKey = "TeleFlow_DeletedMessageIds_v2"
    private static let snapshotsKey = "TeleFlow_DeletedSnapshots_v1"

    private let queue = Queue()
    private var deletedMessageIds: Set<String> = []
    private var snapshots: [String: TeleFlowDeletedSnapshot] = [:]
    private var isEnabled: Bool = TeleFlowSettings.shared.isAntiDeleteEnabled
    private var settingsDisposable: Disposable?

    private init() {
        self.loadFromDisk()
        self.settingsDisposable = TeleFlowSettings.shared.observeChanges { [weak self] in
            self?.queue.async {
                self?.isEnabled = TeleFlowSettings.shared.isAntiDeleteEnabled
            }
        }
    }

    // MARK: - Public

    public func updateSettings(isEnabled: Bool) {
        self.queue.async {
            self.isEnabled = isEnabled
        }
    }

    public func isMessageDeletedLocally(messageId: MessageId) -> Bool {
        let key = self.storageKey(for: messageId)
        var result = false
        self.queue.sync { result = self.deletedMessageIds.contains(key) }
        return result
    }

    public func snapshot(messageId: MessageId) -> TeleFlowDeletedSnapshot? {
        let key = self.storageKey(for: messageId)
        var result: TeleFlowDeletedSnapshot?
        self.queue.sync { result = self.snapshots[key] }
        return result
    }

    /// Вызывается из delete-пайплайна ПЕРЕД фактическим удалением.
    public func handleIncomingMessageDeletions(account: Account, messageIds: [MessageId]) {
        guard !messageIds.isEmpty else { return }

        self.queue.async {
            guard self.isEnabled else {
                _ = (account.postbox.transaction { tx in
                    for id in messageIds { tx.removeMessage(id) }
                }).start()
                return
            }

            _ = (account.postbox.transaction { transaction -> Void in
                for messageId in messageIds {
                    guard let message = transaction.getMessage(messageId) else { continue }

                    if message.attributes.contains(where: { $0 is TeleFlowDeletedAttribute }) {
                        continue
                    }

                    let authorName: String? = {
                        if let peer = message.author as? TelegramUser {
                            let parts = [peer.firstName, peer.lastName].compactMap { $0 }.filter { !$0.isEmpty }
                            return parts.isEmpty ? nil : parts.joined(separator: " ")
                        }
                        return nil
                    }()

                    let mediaKind: String? = {
                        for m in message.media {
                            if m is TelegramMediaImage { return "photo" }
                            if m is TelegramMediaFile { return "file" }
                        }
                        return nil
                    }()

                    let snap = TeleFlowDeletedSnapshot(
                        peerId: messageId.peerId.toInt64(),
                        namespace: messageId.namespace,
                        messageId: messageId.id,
                        timestamp: message.timestamp,
                        text: message.text,
                        authorId: message.author?.id.toInt64(),
                        authorName: authorName,
                        deletedAt: Int32(Date().timeIntervalSince1970),
                        mediaKind: mediaKind
                    )

                    let attr = TeleFlowDeletedAttribute(
                        deletedAt: snap.deletedAt,
                        originalAuthorName: authorName
                    )

                    var attrs = message.attributes
                    attrs.append(attr)

                    transaction.updateMessage(messageId, update: { current in
                        var updated = current
                        updated.attributes = attrs
                        return updated
                    })

                    self.markMessageAsDeleted(messageId: messageId, snapshot: snap)
                }
            }).start()
        }
    }

    public func notifyAccountReady(account: Account) {
        NotificationCenter.default.post(
            name: TeleFlowAntiDeleteService.accountReadyNotification,
            object: nil,
            userInfo: ["account": account]
        )
    }

    // MARK: - Private

    private func markMessageAsDeleted(messageId: MessageId, snapshot: TeleFlowDeletedSnapshot) {
        let key = self.storageKey(for: messageId)
        if self.deletedMessageIds.contains(key) { return }
        self.deletedMessageIds.insert(key)
        self.snapshots[key] = snapshot
        self.persistToDisk()
    }

    private func storageKey(for messageId: MessageId) -> String {
        return "\(messageId.peerId.toInt64())_\(messageId.namespace)_\(messageId.id)"
    }

    private func loadFromDisk() {
        if let stored = UserDefaults.standard.array(forKey: Self.deletedIdsKey) as? [String] {
            self.deletedMessageIds = Set(stored)
        }
        if let data = UserDefaults.standard.data(forKey: Self.snapshotsKey),
           let decoded = try? JSONDecoder().decode([String: TeleFlowDeletedSnapshot].self, from: data) {
            self.snapshots = decoded
        }
    }

    private func persistToDisk() {
        let idsArray = Array(self.deletedMessageIds.suffix(3000))
        UserDefaults.standard.set(idsArray, forKey: Self.deletedIdsKey)

        if self.snapshots.count > 3000 {
            let keepKeys = Set(self.deletedMessageIds.suffix(3000))
            self.snapshots = self.snapshots.filter { keepKeys.contains($0.key) }
        }
        if let data = try? JSONEncoder().encode(self.snapshots) {
            UserDefaults.standard.set(data, forKey: Self.snapshotsKey)
        }
    }
}

// MARK: - Snapshot

public struct TeleFlowDeletedSnapshot: Codable {
    public let peerId: Int64
    public let namespace: Int32
    public let messageId: Int32
    public let timestamp: Int32
    public let text: String
    public let authorId: Int64?
    public let authorName: String?
    public let deletedAt: Int32
    public let mediaKind: String?
}

public func messageContainsTeleFlowDeletionMarker(_ text: String) -> Bool {
    return text.contains(TeleFlowAntiDeleteService.deletionMarkerText)
}
