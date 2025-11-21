import UIKit

final class MemoryCategoriesViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    private enum Category: CaseIterable {
        case recipies, childhood, travel, lifeLesson, love

        var title: String {
            switch self {
            case .recipies: return "Recipies"
            case .childhood: return "Childhood"
            case .travel: return "Travel"
            case .lifeLesson: return "Life Lesson"
            case .love: return "Love"
            }
        }

        var assetName: String {
            switch self {
            case .recipies: return "cat_recipes"
            case .childhood: return "cat_childhood"
            case .travel: return "cat_travel"
            case .lifeLesson: return "cat_lifelesson"
            case .love: return "cat_love"
            }
        }

        var normalizedKey: String {
            return title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        static var aliases: [String: Category] {
            return [
                "recipies": .recipies,
                "childhood": .childhood,
                "children": .childhood,
                "travel": .travel,
                "travels": .travel,
                "life lesson": .lifeLesson,
                "lifelesson": .lifeLesson,
                "life lessons": .lifeLesson,
                "life-lesson": .lifeLesson,
                "love": .love,
                "relationship": .love
            ]
        }
    }

    private let categories = Category.allCases
    private var countsByCategory: [Category: Int] = [:]

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Categories"
        setupTable()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // ❌ Removed manual tab bar hiding (breaks hidesBottomBarWhenPushed)
        computeCountsFromStore()
        tableView.reloadData()
    }

    private func setupTable() {
        let nib = UINib(nibName: "MemoryCategoryTableViewCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: MemoryCategoryTableViewCell.reuseId)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear

        tableView.separatorStyle = .singleLine
        tableView.separatorColor = UIColor(white: 0.85, alpha: 1)
        tableView.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 24, right: 0)
        tableView.tableHeaderView = UIView(frame: .init(x: 0, y: 0, width: 0, height: 0.1))
        tableView.tableFooterView = UIView(frame: .init(x: 0, y: 0, width: 0, height: 16))
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 90, bottom: 0, right: 16)
        tableView.layoutMargins = UIEdgeInsets(top: 0, left: 90, bottom: 0, right: 16)
        tableView.showsVerticalScrollIndicator = false

        tableView.estimatedRowHeight = 100
        tableView.rowHeight = UITableView.automaticDimension
    }

    private func computeCountsFromStore() {
        countsByCategory = [:]
        Category.allCases.forEach { countsByCategory[$0] = 0 }

        let all = MemoryStore.shared.allMemories()
        var unknownKeys: [String: Int] = [:]

        for mem in all {
            guard let raw = mem.category?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { continue }
            let key = raw.lowercased()

            if let cat = Category.aliases[key] {
                countsByCategory[cat, default: 0] += 1
                continue
            }

            if key.contains("recipies") { countsByCategory[.recipies, default: 0] += 1; continue }
            if key.contains("child")    { countsByCategory[.childhood, default: 0] += 1; continue }
            if key.contains("travel") || key.contains("trip") || key.contains("vacation") {
                countsByCategory[.travel, default: 0] += 1; continue
            }
            if key.contains("life") && (key.contains("lesson") || key.contains("learn")) {
                countsByCategory[.lifeLesson, default: 0] += 1; continue
            }
            if key.contains("love") || key.contains("relationship") {
                countsByCategory[.love, default: 0] += 1; continue
            }

            unknownKeys[raw, default: 0] += 1
        }
    }
}

// MARK: - UITableViewDataSource
extension MemoryCategoriesViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        categories.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: MemoryCategoryTableViewCell.reuseId,
            for: indexPath
        ) as? MemoryCategoryTableViewCell else {
            return UITableViewCell()
        }

        let cat = categories[indexPath.row]
        let count = countsByCategory[cat] ?? 0
        cell.configure(iconName: cat.assetName, title: cat.title, count: count)

        cell.backgroundColor = .clear
        cell.selectionStyle = .none

        return cell
    }
}

// MARK: - UITableViewDelegate
extension MemoryCategoriesViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 100 }

    func tableView(_ tableView: UITableView,
                   willDisplay cell: UITableViewCell,
                   forRowAt indexPath: IndexPath) {

        let inset = UIEdgeInsets(top: 0, left: 90, bottom: 0, right: 16)
        cell.separatorInset = inset
        cell.layoutMargins = inset
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        tableView.deselectRow(at: indexPath, animated: true)

        let cat = categories[indexPath.row]
        let detailVC = CategoryDetailViewController(
            nibName: "CategoryDetailViewController",
            bundle: nil
        )
        detailVC.categoryTitle = cat.title
        detailVC.hidesBottomBarWhenPushed = true

        // Custom animation
        let transition = CATransition()
        transition.duration = 0.30
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        transition.type = .push
        transition.subtype = .fromRight

        navigationController?.view.layer.add(transition, forKey: nil)
        navigationController?.pushViewController(detailVC, animated: false)
    }
}
