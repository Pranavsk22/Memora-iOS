import UIKit
import AVFoundation

final class CategoryDetailViewController: UIViewController {

    // MARK: - XIB Outlets
    @IBOutlet weak var tableView: UITableView!

    // MARK: - Floating Search Bar
    private let searchField = UITextField()
    private var searchContainer = UIView()
    private var blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    
    private var searchGlass: UIVisualEffectView?

    // MARK: - Layout Constants
    private let horizontalMargin: CGFloat = 16
    private let cardSpacing: CGFloat = 20
    private let searchHeight: CGFloat = 50

    // MARK: - Category
    public var categoryTitle: String?

    // MARK: - Data
    private var allMemories: [Memory] = []
    private var filtered: [Memory] = []

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        title = categoryTitle ?? "Category"

        setupSearchField()
        setupTableView()
        loadMemoriesSorted()

        enableKeyboardDismiss()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutSearchField()
    }


    // MARK: - Floating Search Bar
    private func setupSearchField() {
        // === SEARCH CONTAINER (shadow + rounded) ===
        searchContainer = UIView()
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.layer.cornerRadius = searchHeight / 2
        searchContainer.layer.cornerCurve = .continuous
        searchContainer.clipsToBounds = false   // shadow must NOT be clipped
        view.addSubview(searchContainer)

        // Shadow (beautiful soft iOS style)
        searchContainer.layer.shadowColor = UIColor.black.cgColor
        searchContainer.layer.shadowOpacity = 0.12
        searchContainer.layer.shadowRadius = 14
        searchContainer.layer.shadowOffset = CGSize(width: 0, height: 6)

        // === BLUR BACKGROUND ===
        blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.clipsToBounds = true
        blurView.layer.cornerRadius = searchHeight / 2
        blurView.layer.cornerCurve = .continuous
        searchContainer.addSubview(blurView)

        // === TEXT FIELD ===
        searchField.backgroundColor = .clear
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.font = .systemFont(ofSize: 16)
        searchField.textColor = .label
        searchField.clearButtonMode = .whileEditing

        searchField.attributedPlaceholder = NSAttributedString(
            string: "Search",
            attributes: [.foregroundColor: UIColor.secondaryLabel.withAlphaComponent(0.7)]
        )

        // Left icon
        let leftIcon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        leftIcon.tintColor = .secondaryLabel.withAlphaComponent(0.85)
        leftIcon.contentMode = .center
        leftIcon.frame = CGRect(x: 0, y: 0, width: 36, height: searchHeight)
        searchField.leftView = leftIcon
        searchField.leftViewMode = .always

        // Right mic
        let mic = UIImageView(image: UIImage(systemName: "mic.fill"))
        mic.tintColor = .secondaryLabel.withAlphaComponent(0.85)
        mic.contentMode = .center
        mic.frame = CGRect(x: 0, y: 0, width: 36, height: searchHeight)
        searchField.rightView = mic
        searchField.rightViewMode = .always

        // Add text field inside blur
        blurView.contentView.addSubview(searchField)

        // === AUTO LAYOUT ===
        NSLayoutConstraint.activate([
            // Container (outer padding)
            searchContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: horizontalMargin),
            searchContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -horizontalMargin),
            searchContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            searchContainer.heightAnchor.constraint(equalToConstant: searchHeight),

            // Blur fills container
            blurView.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor),
            blurView.topAnchor.constraint(equalTo: searchContainer.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: searchContainer.bottomAnchor),

            // TextField inside blur with **REAL iOS padding**
            searchField.leadingAnchor.constraint(equalTo: blurView.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: blurView.trailingAnchor, constant: -12),
            searchField.centerYAnchor.constraint(equalTo: blurView.centerYAnchor),
            searchField.heightAnchor.constraint(equalTo: blurView.heightAnchor)
        ])
    }

    private func layoutSearchField() {
        // Table starts below search bar
        let offset = (view.safeAreaInsets.top + 8 + searchHeight + 16)
        tableView.contentInset.top = offset
        tableView.scrollIndicatorInsets.top = offset
    }


    // MARK: - TableView Setup
    private func setupTableView() {

        // IMPORTANT: ensure XIB constraints DO NOT pin top to safe area.
        tableView.contentInsetAdjustmentBehavior = .never

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false

        tableView.dataSource = self
        tableView.delegate = self

        let nib = UINib(nibName: "CategoryCardTableViewCell", bundle: .main)
        tableView.register(nib, forCellReuseIdentifier: CategoryCardTableViewCell.reuseId)

        tableView.estimatedRowHeight = 350
        tableView.rowHeight = UITableView.automaticDimension

        tableView.contentInset.bottom = 24
    }


    // MARK: - Load Memories (Sorted)
    private func normalized(_ s: String) -> String {
        s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadMemoriesSorted() {
        guard let cat = categoryTitle else { return }
        let wanted = normalized(cat)

        DispatchQueue.global(qos: .userInitiated).async {

            let all = MemoryStore.shared.allMemories()

            let filteredList = all.filter {
                guard let c = $0.category else { return false }
                return self.normalized(c) == wanted
            }
            .sorted { $0.createdAt > $1.createdAt }   // ⬅️ SORT NEWEST FIRST

            DispatchQueue.main.async {
                self.allMemories = filteredList
                self.filtered = filteredList
                self.tableView.reloadData()
            }
        }
    }


    // MARK: - Search
    @objc private func onSearchChanged() {
        let q = normalized(searchField.text ?? "")

        filtered =
            q.isEmpty
            ? allMemories
            : allMemories.filter {
                $0.title.lowercased().contains(q)
                || ($0.body ?? "").lowercased().contains(q)
            }

        tableView.reloadData()
    }


    // MARK: - Keyboard Dismiss
    private func enableKeyboardDismiss() {
        let tap = UITapGestureRecognizer(target: self.view,
                                         action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
}

// MARK: - TableView DataSource
extension CategoryDetailViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return filtered.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let mem = filtered[indexPath.section]

        let cell = tableView.dequeueReusableCell(
            withIdentifier: CategoryCardTableViewCell.reuseId,
            for: indexPath
        ) as! CategoryCardTableViewCell

        cell.selectionStyle = .none
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.configure(with: mem)

        return cell
    }
}


// MARK: - TableView Delegate
extension CategoryDetailViewController: UITableViewDelegate {

    // 16pt left/right padding
    func tableView(_ tableView: UITableView,
                   insetForRowAt indexPath: IndexPath) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0,
                            left: horizontalMargin,
                            bottom: 0,
                            right: horizontalMargin)
    }

    // 26pt between cards
    func tableView(_ tableView: UITableView,
                   heightForFooterInSection section: Int) -> CGFloat {
        return cardSpacing
    }

    func tableView(_ tableView: UITableView,
                   viewForFooterInSection section: Int) -> UIView? {
        let v = UIView()
        v.backgroundColor = .clear
        return v
    }

    func tableView(_ tableView: UITableView,
                   didSelectRowAt indexPath: IndexPath) {

        let mem = filtered[indexPath.section]
        let vc = MemoryDetailViewController(memory: mem)
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: true)
    }
}
