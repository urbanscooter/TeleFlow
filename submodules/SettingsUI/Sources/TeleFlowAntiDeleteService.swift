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
    private let trashNodeName = "tfTrashNode"

    private let queue = Queue()
    private var refreshTimer: SwiftSignalKit.Timer?

    private init() {
        // Регистрация атрибута в Postbox (правильный синтаксис с label 'f:')
        declareEncodable(TeleFlowDeletedAttribute.self, f: { decoder in
            return TeleFlowDeletedAttribute(decoder: decoder)
        })

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

    // MARK: - Settings reading

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

    // MARK: - Compatibility (для контроллера)

    public func updateSettings(isEnabled: Bool) {
        // Настройки читаются из UserDefaults каждый раз — тут ничего не нужно.
        self.refreshUI()
    }

    // MARK: - Delete hook (Шаг 1 — вызывается ПЕРЕД transaction.removeMessage)

    public func handleIncomingMessageDeletions(account: Account, messageIds: [MessageId]) {
        guard !messageIds.isEmpty, self.isAntiDeleteEnabled else { return }
        let _ = (account.postbox.transaction { transaction -> Void in
            for messageId in messageIds {
                guard let message = transaction.getMessage(messageId) else { continue }
                if message.attributes.contains(where: { $0 is TeleFlowDeletedAttribute }) { continue }
                var attrs = message.attributes
                attrs.append(TeleFlowDeletedAttribute(
                    deletedAt: Int32(Date().timeIntervalSince1970),
                    originalAuthorName: nil
                ))
                transaction.updateMessage(messageId, update: { current in
                    var u = current
                    u.attributes = attrs
                    return u
                })
            }
        }).start(next: { [weak self] (_: Void) in
            Queue.mainQueue().async {
                self?.refreshUI()
            }
        })
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
            let deleted = enabled && self.bubbleTeleFlowDeleted(bubble)
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

    private func bubbleTeleFlowDeleted(_ bubble: ASDisplayNode) -> Bool {
        guard let itemAny = bubble.value(forKey: "item") else { return false }
        guard let messageAny = (itemAny as AnyObject).value(forKey: "message") else { return false }
        guard let message = messageAny as? Message else { return false }
        return message.attributes.contains(where: { $0 is TeleFlowDeletedAttribute })
    }

    private func apply(bubble: ASDisplayNode, deleted: Bool) {
        let newAlpha: CGFloat = (deleted && self.isGrayOutEnabled)
            ? CGFloat(self.deletedOpacity)
            : 1.0
        if abs(bubble.alpha - newAlpha) > 0.001 {
            bubble.alpha = newAlpha
        }

        var trash: ASImageNode? = bubble.subnodes?.first(where: { $0.name == self.trashNodeName }) as? ASImageNode
        if trash == nil {
            let node = ASImageNode()
            node.name = self.trashNodeName
            node.displaysAsynchronously = false
            node.isUserInteractionEnabled = false
            node.image = UIImage(systemName: "trash")?.withTintColor(.gray, renderingMode: .alwaysOriginal)
            bubble.addSubnode(node)
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
