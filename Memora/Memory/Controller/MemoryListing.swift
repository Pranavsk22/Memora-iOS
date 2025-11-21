import UIKit
import AVFoundation

final class MemoryListing: UIViewController {

    // MARK: - XIB Outlets (connect in your XIB)
    @IBOutlet weak var tableView: UITableView!

    // MARK: - Floating Search Bar (programmatic)
    private let searchField = UITextField()
    private let searchContainer = UIView()
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))

    // MARK: - Layout constants
    private let horizontalMargin: CGFloat = 16
    private let cardSpacing: CGFloat = 26
    private let searchHeight: CGFloat = 50

    // MARK: - Public
    public var categoryTitle: String?

    /// Optional filter to restrict results to certain visibility(s).
    /// e.g. set to `[.private]` to show only private memories, `[.everyone]` to show only shared,
    /// or leave `nil` to show both `.private` & `.everyone`.
    public var visibilityFilter: [MemoryVisibility]? = nil

    // MARK: - Data
    private var allMemories: [Memory] = []
    private var filtered: [Memory] = []

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        title = categoryTitle ?? "Category"
        view.backgroundColor = .systemBackground

        setupSearchUI()
        setupTableView()
        enableKeyboardDismiss()

        // load initial data
        loadMemoriesSorted()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutSearchInsets()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.isHidden = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        tabBarController?.tabBar.isHidden = false
    }

    // MARK: - Search UI
    private func setupSearchUI() {
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.layer.cornerRadius = searchHeight / 2
        searchContainer.layer.cornerCurve = .continuous
        searchContainer.clipsToBounds = false
        view.addSubview(searchContainer)

        searchContainer.layer.shadowColor = UIColor.black.cgColor
        searchContainer.layer.shadowOpacity = 0.12
        searchContainer.layer.shadowRadius = 14
        searchContainer.layer.shadowOffset = CGSize(width: 0, height: 6)

        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.clipsToBounds = true
        blurView.layer.cornerRadius = searchHeight / 2
        blurView.layer.cornerCurve = .continuous
        searchContainer.addSubview(blurView)

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.backgroundColor = .clear
        searchField.font = .systemFont(ofSize: 16)
        searchField.textColor = .label
        searchField.clearButtonMode = .whileEditing
        searchField.attributedPlaceholder = NSAttributedString(
            string: "Search",
            attributes: [.foregroundColor: UIColor.secondaryLabel.withAlphaComponent(0.7)]
        )
        searchField.addTarget(self, action: #selector(onSearchChanged), for: .editingChanged)
        searchField.delegate = self

        let leftIcon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        leftIcon.tintColor = .secondaryLabel.withAlphaComponent(0.85)
        leftIcon.contentMode = .center
        leftIcon.frame = CGRect(x: 0, y: 0, width: 36, height: searchHeight)
        searchField.leftView = leftIcon
        searchField.leftViewMode = .always

        let mic = UIImageView(image: UIImage(systemName: "mic.fill"))
        mic.tintColor = .secondaryLabel.withAlphaComponent(0.85)
        mic.contentMode = .center
        mic.frame = CGRect(x: 0, y: 0, width: 36, height: searchHeight)
        searchField.rightView = mic
        searchField.rightViewMode = .always

        blurView.contentView.addSubview(searchField)

        NSLayoutConstraint.activate([
            searchContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: horizontalMargin),
            searchContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -horizontalMargin),
            searchContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            searchContainer.heightAnchor.constraint(equalToConstant: searchHeight),

            blurView.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor),
            blurView.topAnchor.constraint(equalTo: searchContainer.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: searchContainer.bottomAnchor),

            searchField.leadingAnchor.constraint(equalTo: blurView.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: blurView.trailingAnchor, constant: -12),
            searchField.centerYAnchor.constraint(equalTo: blurView.centerYAnchor),
            searchField.heightAnchor.constraint(equalTo: blurView.heightAnchor)
        ])
    }

    private func layoutSearchInsets() {
        let offset = view.safeAreaInsets.top + 8 + searchHeight + 16
        tableView.contentInset.top = offset
        tableView.scrollIndicatorInsets.top = offset
    }

    // MARK: - Table setup
    private func setupTableView() {
        guard tableView != nil else {
            assertionFailure("tableView outlet not connected for MemoryListing")
            return
        }

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
        tableView.contentInset.bottom = view.safeAreaInsets.bottom + 24
    }

    // MARK: - Loading data (non-scheduled, newest first)
    private func normalized(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func loadMemoriesSorted() {
        // category filter optional — if nil or empty treat as "all categories"

        DispatchQueue.global(qos: .userInitiated).async {
            let all = MemoryStore.shared.allMemories()

            let list = all.filter { mem -> Bool in
                // exclude scheduled
                if mem.visibility == .scheduled { return false }

                // visibility filter if provided
                if let visFilter = self.visibilityFilter {
                    if !visFilter.contains(mem.visibility) { return false }
                }

              

                return true
            }
            .sorted { $0.createdAt > $1.createdAt } // newest first

            DispatchQueue.main.async {
                self.allMemories = list
                self.filtered = list
                self.tableView.reloadData()
            }
        }
    }

    // MARK: - Search handling
    @objc private func onSearchChanged() {
        let q = normalized(searchField.text ?? "")
        if q.isEmpty {
            filtered = allMemories
        } else {
            filtered = allMemories.filter {
                $0.title.lowercased().contains(q) ||
                ($0.body ?? "").lowercased().contains(q)
            }
        }
        tableView.reloadData()
    }

    // MARK: - Keyboard dismissal
    private func enableKeyboardDismiss() {
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
}

// MARK: - UITableViewDataSource
extension MemoryListing: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { filtered.count }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let mem = filtered[indexPath.section]
        guard let cell = tableView.dequeueReusableCell(withIdentifier: CategoryCardTableViewCell.reuseId, for: indexPath) as? CategoryCardTableViewCell else {
            return UITableViewCell()
        }
        cell.selectionStyle = .none
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.configure(with: mem)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension MemoryListing: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { cardSpacing }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let v = UIView(); v.backgroundColor = .clear; return v
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.selectionStyle = .none
        cell.preservesSuperviewLayoutMargins = false
        cell.directionalLayoutMargins = NSDirectionalEdgeInsets(top: cardSpacing/2,
                                                                leading: horizontalMargin,
                                                                bottom: cardSpacing/2,
                                                                trailing: horizontalMargin)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let mem = filtered[indexPath.section]
        let vc = MemoryDetailViewController(memory: mem)
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - UITextFieldDelegate
extension MemoryListing: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
