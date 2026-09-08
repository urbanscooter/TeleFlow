import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public final class TeleFlowAntiDeleteService {
    public static let shared = TeleFlowAntiDeleteService()

    public static let deletionMarkerText: String = "Удалено"
    private static let deletedMessagesKey = "TeleFlow_DeletedMessageIds_v1"

    private let queue = Queue()
    private var deletedMessageIds: Set<String> = []
    private var isEnabled: Bool = true

    private init() {
        self.loadStoredDeletedIds()
    }

    public func updateSettings(isEnabled: Bool) {
        self.queue.async {
            self.isEnabled = isEnabled
        }
    }

    public func isMessageDeletedLocally(messageId: MessageId) -> Bool {
        let key = self.storageKey(for: messageId)
        var result = false
        self.queue.sync {
            result = self.deletedMessageIds.contains(key)
        }
        return result
    }

    public func handleIncomingMessageDeletions(account: Account, messageIds: [MessageId]) {
        guard !messageIds.isEmpty else { return }

        self.queue.async {
            guard self.isEnabled else { return }

            _ = (account.postbox.transaction { transaction -> Void in
                for messageId in messageIds {
                    if transaction.getMessage(messageId) != nil {
                        self.markMessageAsDeleted(messageId: messageId)
                    }
                }
            }).start(next: { _ in })
        }
    }

    private func markMessageAsDeleted(messageId: MessageId) {
        let key = self.storageKey(for: messageId)
        if self.deletedMessageIds.contains(key) {
            return
        }

        self.deletedMessageIds.insert(key)
        self.persistDeletedIds()
    }

    private func storageKey(for messageId: MessageId) -> String {
        return "\(messageId.peerId.toInt64())_\(messageId.namespace)_\(messageId.id)"
    }

    private func loadStoredDeletedIds() {
        if let stored = UserDefaults.standard.array(forKey: Self.deletedMessagesKey) as? [String] {
            self.deletedMessageIds = Set(stored)
        }
    }

    private func persistDeletedIds() {
        let arrayToStore = Array(self.deletedMessageIds.suffix(2000))
        UserDefaults.standard.set(arrayToStore, forKey: Self.deletedMessagesKey)
    }
}

public func messageContainsTeleFlowDeletionMarker(_ text: String) -> Bool {
    return text.contains(TeleFlowAntiDeleteService.deletionMarkerText)
}
