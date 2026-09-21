import UIKit

@objc public class TeleFlowSettingsScreen: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let items: [(title: String, subtitle: String, key: String)] = [
        ("Скрытие рекламы", "Убирает sponsored messages", "hideAds"),
        ("Скрытие историй", "Убирает stories сверху", "hideStories"),
        ("Антиудаление", "Сохраняет удалённые сообщения", "antiDelete"),
    ]

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "TeleFlow"
        self.view.backgroundColor = .systemGroupedBackground

        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: self.view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
        ])
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        let item = items[indexPath.row]
        cell.textLabel?.text = item.title
        cell.detailTextLabel?.text = item.subtitle
        cell.selectionStyle = .none

        let sw = UISwitch()
        sw.tag = indexPath.row
        let m = TeleFlowManager.shared
        switch item.key {
        case "hideAds": sw.isOn = m.hideAds
        case "hideStories": sw.isOn = m.hideStories
        case "antiDelete": sw.isOn = m.antiDelete
        default: break
        }
        sw.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)
        cell.accessoryView = sw
        return cell
    }

    @objc private func toggleChanged(_ sender: UISwitch) {
        let item = items[sender.tag]
        let m = TeleFlowManager.shared
        switch item.key {
        case "hideAds": m.hideAds = sender.isOn
        case "hideStories": m.hideStories = sender.isOn
        case "antiDelete": m.antiDelete = sender.isOn
        default: break
        }
        NSLog("[TeleFlow] %@ = %@", item.key, sender.isOn ? "ON" : "OFF")
    }
}
