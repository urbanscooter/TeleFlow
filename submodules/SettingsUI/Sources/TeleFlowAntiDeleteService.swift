import Foundation
import UIKit
import Postbox
import TelegramCore
import AsyncDisplayKit
import Display
import SwiftSignalKit

public final class TeleFlowAntiDeleteService {
    public static let shared = TeleFlowAntiDeleteService()
    public static let deletionMarkerText: String = "Удалено"
    public static let accountReadyNotification = Notification.Name("TeleFlowAntiDeleteService.accountReady")

    private static let suiteName = "group.ph.telegra.TeleFlow"
    private static let deletedIdsKey = "TeleFlow_DeletedMessageIds_v3"

    private let queue = Queue()
    private var refreshTimer: SwiftSignalKit.Timer?
    private var deletedMessageKeys: Set<String> = []
    private var trashNodes: [ObjectIdentifier: ASImageNode] = [:]

    private init() {
        self.loadDeletedIds()

        self.refreshTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in
            self?.refreshUI()
        }, queue: .mainQueue())
        self.refreshTimer?.start()

        NotificationCenter.default.addObserver(
            forName: Notification.Name("TeleFlowSettingsDidChange"),
            object: nil,
            queue: .main,
            using: { [weak self] _ in
                self?.refreshUI()
            }
        )
    }

    // MARK: - Settings

    private var isAntiDeleteEnabled: Bool {
        return UserDefaults(suiteName: Self.suiteName)?.bool(forKey: "isAntiDeleteEnabled") ?? false
    }

    private var isGrayOutEnabled: Bool {
        if UserDefaults(suiteName: Self.suiteName)?.object(forKey: "isGrayOutDeletedEnabled") == nil { return true }
        return UserDefaults(suiteName: Self.suiteName)?.bool(forKey: "isGrayOutDeletedEnabled") ?? true
    }

    private var isShowTrashEnabled: Bool {
        if UserDefaults(suiteName: Self.suiteName)?.object(forKey: "isShowTrashIconEnabled") == nil { return true }
        return UserDefaults(suiteName: Self.suiteName)?.bool(forKey: "isShowTrashIconEnabled") ?? true
    }

    private var deletedOpacity: Double {
        if UserDefaults(suiteName: Self.suiteName)?.object(forKey: "deletedOpacity") == nil { return 0.55 }
        let v = UserDefaults(suiteName: Self.suiteName)?.double(forKey: "deletedOpacity") ?? 0.55
        return min(1.0, max(0.1, v))
    }

    // MARK: - Deletion marker

    private func key(for id: MessageId) -> String {
        return "\(id.peerId.toInt64())_\(id.namespace)_\(id.id)"
    }

    public func isMessageMarkedDeleted(_ id: MessageId) -> Bool {
        var result = false
        self.queue.sync { result = self.deletedMessageKeys.contains(self.key(for: id)) }
        return result
    }

    private func loadDeletedIds() {
        if let arr = UserDefaults(suiteName: Self.suiteName)?.array(forKey: Self.deletedIdsKey) as? [String] {
            self.deletedMessageKeys = Set(arr)
        }
    }

    private func persistDeletedIds() {
        let arr = Array(self.deletedMessageKeys.suffix(5000))
        UserDefaults(suiteName: Self.suiteName)?.set(arr, forKey: Self.deletedIdsKey)
    }

    // MARK: - Delete hook (вызывается из патченного пайплайна)

    /// Если анти-удаление включено — сообщение НЕ удаляем, только помечаем.
    /// Если выключено — удаляем штатно.
    public func handleIncomingMessageDeletions(account: Account, messageIds: [MessageId]) {
        guard !messageIds.isEmpty else { return }

        if self.isAntiDeleteEnabled {
            self.queue.async {
                for id in messageIds {
                    self.deletedMessageKeys.insert(self.key(for: id))
                }
                self.persistDeletedIds()
            }
            Queue.mainQueue().async { self.refreshUI() }
        } else {
            let _ = (account.postbox.transaction { transaction -> Void in
                for id in messageIds {
                    transaction.removeMessage(id)
                }
            }).start()
        }
    }

    public func updateSettings(isEnabled: Bool) {
        Queue.mainQueue().async { self.refreshUI() }
    }

    public func notifyAccountReady(account: Account) {
        NotificationCenter.default.post(
            name: TeleFlowAntiDeleteService.accountReadyNotification,
            object: nil,
            userInfo: ["account": account]
        )
    }

    // MARK: - UI refresh

    private func refreshUI() {
        let enabled = self.isAntiDeleteEnabled
        self.walkBubbles { [weak self] (bubble: ASDisplayNode) in
            guard let self else { return }
            let deleted = enabled && self.bubbleIsDeleted(bubble)
            self.apply(bubble: bubble, deleted: deleted)
        }
    }

    private func walkBubbles(_ action: @escaping (ASDisplayNode) -> Void) {
        for window in UIApplication.shared.windows {
            self.walkView(window, action)
        }
    }

    private func walkView(_ view: UIView, _ action: @escaping (ASDisplayNode) -> Void) {
        if let node = view.asyncdisplaykit_node {
            let className = String(describing: type(of: node))
            if className.contains("ChatMessageBubbleItemNode") {
                action(node)
            }
        }
        for sub in view.subviews {
            self.walkView(sub, action)
        }
    }

    private func bubbleIsDeleted(_ bubble: ASDisplayNode) -> Bool {
        guard let messageId = self.bubbleMessageId(bubble) else { return false }
        return self.isMessageMarkedDeleted(messageId)
    }

    private func bubbleMessageId(_ bubble: ASDisplayNode) -> MessageId? {
        guard let itemAny = bubble.value(forKey: "item") else { return nil }
        guard let messageAny = (itemAny as AnyObject).value(forKey: "message") else { return nil }
        guard let idAny = (messageAny as AnyObject).value(forKey: "id") else { return nil }
        return idAny as? MessageId
    }

    private func apply(bubble: ASDisplayNode, deleted: Bool) {
        let newAlpha: CGFloat = (deleted && self.isGrayOutEnabled)
            ? CGFloat(self.deletedOpacity)
            : 1.0
        if abs(bubble.alpha - newAlpha) > 0.001 {
            bubble.alpha = newAlpha
        }

        let oid = ObjectIdentifier(bubble)
        var trash = self.trashNodes[oid]
        if trash == nil {
            let node = ASImageNode()
            node.displaysAsynchronously = false
            node.isUserInteractionEnabled = false
            node.image = UIImage(systemName: "trash")?.withTintColor(.gray, renderingMode: .alwaysOriginal)
            bubble.addSubnode(node)
            self.trashNodes[oid] = node
            trash = node
        }
        guard let trashNode = trash else { return }

        let shouldShow = deleted && self.isShowTrashEnabled
        trashNode.isHidden = !shouldShow
        if shouldShow {
            let size = CGSize(width: 12, height: 12)
            let b = bubble.bounds
            trashNode.frame = CGRect(
                x: b.width - size.width - 6,
                y: b.height - size.height - 4,
                width: size.width,
                height: size.height
            )
        }
    }
}
