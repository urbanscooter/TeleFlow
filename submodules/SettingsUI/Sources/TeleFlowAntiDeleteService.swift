import Foundation
import UIKit
import Postbox
import TelegramCore
import SwiftSignalKit

public final class TeleFlowAntiDeleteService {
    public static let shared = TeleFlowAntiDeleteService()
    public static let deletionMarkerText: String = "Удалено"
    public static let accountReadyNotification = Notification.Name("TeleFlowAntiDeleteService.accountReady")

    private let queue = Queue()
    private var isEnabled: Bool = TeleFlowSettings.shared.isAntiDeleteEnabled
    private var settingsDisposable: Disposable?
    private var refreshTimer: SwiftSignalKit.Timer?

    private init() {
        self.settingsDisposable = TeleFlowSettings.shared.observeChanges { [weak self] _ in
            self?.queue.async { self?.isEnabled = TeleFlowSettings.shared.isAntiDeleteEnabled }
            self?.refreshUI()
        }
        // периодическое обновление видимых баблов
        self.refreshTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in
            self?.refreshUI()
        }, queue: .mainQueue())
        self.refreshTimer?.start()
    }

    // MARK: - Settings

    public func updateSettings(isEnabled: Bool) {
        self.queue.async { self.isEnabled = isEnabled }
        self.refreshUI()
    }

    // MARK: - Delete hook

    /// Вызывается перед удалением. Помечает сообщение атрибутом, не удаляет.
    public func handleIncomingMessageDeletions(account: Account, messageIds: [MessageId]) {
        guard !messageIds.isEmpty else { return }
        self.queue.async {
            guard self.isEnabled else { return }
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
            }).start(next: { [weak self] _ in
                Queue.mainQueue().async { self?.refreshUI() }
            })
        }
    }

    public func notifyAccountReady(account: Account) {
        NotificationCenter.default.post(
            name: TeleFlowAntiDeleteService.accountReadyNotification,
            object: nil,
            userInfo: ["account": account]
        )
    }

    // MARK: - UI refresh (без правки баблов)

    private func refreshUI() {
        guard TeleFlowSettings.shared.isAntiDeleteEnabled else {
            // снять все надстройки, если выключили
            self.walkBubbles { bubble in self.apply(bubble: bubble, deleted: false) }
            return
        }
        self.walkBubbles { [weak self] bubble in
            guard let self else { return }
            let deleted = bubbleTeleFlowDeleted(bubble)
            self.apply(bubble: bubble, deleted: deleted)
        }
    }

    private func walkBubbles(_ action: @escaping (ASDisplayNode) -> Void) {
        let windows = UIApplication.shared.windows
        for window in windows {
            walkView(window, action)
        }
    }

    private func walkView(_ view: UIView, _ action: @escaping (ASDisplayNode) -> Void) {
        if let node = view.asyncdisplaykit_node {
            // фильтр по имени класса, чтобы не тянуть ChatMessageBubbleItemNode как тип
            let className = String(describing: type(of: node))
            if className.contains("ChatMessageBubbleItemNode") {
                action(node)
            }
        }
        for sub in view.subviews {
            walkView(sub, action)
        }
    }

    /// Проверяем атрибут через Postbox-транзакцию? Нет — данные уже в ноде. 
    /// Читаем через KVC, чтобы не зависеть от типа ChatMessageBubbleItemNode.
    private func bubbleTeleFlowDeleted(_ bubble: ASDisplayNode) -> Bool {
        // ChatMessageBubbleItemNode имеет свойство item: ChatMessageItem
        // ChatMessageItem.message: Message — читаем через KVC.
        guard let item = bubble.value(forKey: "item") else { return false }
        guard let message = (item as AnyObject).value(forKey: "message") else { return false }
        guard let msg = message as? Message else { return false }
        return msg.attributes.contains(where: { $0 is TeleFlowDeletedAttribute })
    }

    // MARK: - Apply

    private func apply(bubble: ASDisplayNode, deleted: Bool) {
        // 1) alpha
        let newAlpha: CGFloat
        if deleted && TeleFlowSettings.shared.isGrayOutDeletedEnabled {
            newAlpha = CGFloat(TeleFlowSettings.shared.deletedOpacity)
        } else {
            newAlpha = 1.0
        }
        if abs(bubble.alpha - newAlpha) > 0.001 {
            bubble.alpha = newAlpha
        }

        // 2) корзина
        let trashName = "tfTrashNode"
        var trash: ASImageNode? = bubble.subnodes?.first(where: { $0.name == trashName }) as? ASImageNode
        if trash == nil {
            let node = ASImageNode()
            node.name = trashName
            node.displaysAsynchronously = false
            node.isUserInteractionEnabled = false
            node.image = UIImage(systemName: "trash")?.withTintColor(.gray, renderingMode: .alwaysOriginal)
            bubble.addSubnode(node)
            trash = node
        }
        guard let trashNode = trash else { return }

        let shouldShow = deleted && TeleFlowSettings.shared.isShowTrashIconEnabled
        trashNode.isHidden = !shouldShow
        if shouldShow {
            let size = CGSize(width: 12, height: 12)
            // в правом нижнем углу бабла — рядом с временем по вертикали
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
