import UIKit

final class MemoryViewController: UIViewController {

    // MARK: - IBOutlets (connect these in your XIB)
    @IBOutlet weak var recentsCollectionView: UICollectionView!
    @IBOutlet weak var recentsLabel: UILabel! // optional - for the "Recents" heading

    // New: categories collection view (connect in XIB)
    @IBOutlet weak var categoriesCollectionView: UICollectionView!

    @IBOutlet weak var privateCollectionView: UICollectionView!
    @IBOutlet weak var sharedCollectionView: UICollectionView!

    // MARK: - Config
    private let recentCellReuseId = "RecentCell"   // your RecentCollectionViewCell reuse id
    private let memoryCellReuseId = MemoryCollectionViewCell.reuseIdentifier
    private let categoryCellReuseId = "CategoryCell" // must match MemoryCategoryCollectionViewCell.xib reuseIdentifier

    // MARK: - Data
    private var memories: [Memory] = []

    private var recentMemories: [Memory] {
        Array(memories.sorted { $0.createdAt > $1.createdAt }.prefix(3))
    }

    // NOTE: Use the MemoryVisibility cases your app defines.
    private var privateMemories: [Memory] {
        memories
            .filter { $0.visibility == .private }   // uses enum equality for clarity
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var sharedMemories: [Memory] {
        memories
            .filter { $0.visibility == .everyone }  // public/shared
            .sorted { $0.createdAt > $1.createdAt }
    }

    private let viewModel = MemoryViewModel(recentsLimit: 6)

    // MARK: - Categories (fixed five)
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
    }

    private let categories: [Category] = Category.allCases

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupNavigationBar()

        // Set title and prefer large title for this VC (will be enabled in viewWillAppear)

        // Configure collection views
        setupCollectionView(recentsCollectionView, isRecent: true)
        setupCollectionView(categoriesCollectionView, isRecent: false, isCategory: true)
        setupCollectionView(privateCollectionView, isRecent: false)
        setupCollectionView(sharedCollectionView, isRecent: false)

        // Add long-press gesture recognizers for private & shared collection views (if used)
        let privateLong = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        privateLong.minimumPressDuration = 0.45
        privateCollectionView.addGestureRecognizer(privateLong)

        let sharedLong = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        sharedLong.minimumPressDuration = 0.45
        sharedCollectionView.addGestureRecognizer(sharedLong)

        recentsLabel.text = "Recents"

        // Seed and reload (optional debug)
        MemorySeedLoader.seedFromBundleJSON(named: "memories_seed", downloadRemoteImages: true) { _ in
            self.reloadFromStore()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(memoriesUpdated(_:)), name: .memoriesUpdated, object: nil)

        // initial load
        reloadFromStore()
    }

    private func setupNavigationBar() {
        self.title = "Memories"
        navigationController?.navigationBar.prefersLargeTitles = true

        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.largeTitleTextAttributes = [
                .font: UIFont.systemFont(ofSize: 34, weight: .heavy),
                .foregroundColor: UIColor.label
            ]
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
        }

//        // Search bar
//        let searchController = UISearchController(searchResultsController: nil)
//        self.navigationItem.searchController = searchController
//
//        // Avatar button
//        let rightButton = UIButton(type: .system)
//        rightButton.clipsToBounds = false
//        rightButton.tag = 1
//        let avatarName = Session.shared.currentUser.avatarName
//        var avatarImage = UIImage(named: avatarName ?? "")
//        if avatarImage == nil {
//            avatarImage = UIImage(systemName: "person.circle.fill")
//        }
//
//        let buttonSize: CGFloat = 40
//        let avatarSize: CGFloat = 38     // made bigger
//
//        rightButton.setImage(avatarImage?.withRenderingMode(.alwaysOriginal), for: .normal)
//        rightButton.imageView?.contentMode = .scaleAspectFill
//
//        // TRUE perfect circle
//        rightButton.imageView?.layer.cornerRadius = avatarSize / 2     // 19
//        rightButton.imageView?.layer.masksToBounds = true
//
//        // Fill the entire area
//        rightButton.imageEdgeInsets = .zero
//
//        guard let navBar = navigationController?.navigationBar else { return }
//        navBar.addSubview(rightButton)
//
//        rightButton.translatesAutoresizingMaskIntoConstraints = false
//        NSLayoutConstraint.activate([
//            rightButton.widthAnchor.constraint(equalToConstant: buttonSize),
//            rightButton.heightAnchor.constraint(equalToConstant: buttonSize),
//
//            rightButton.trailingAnchor.constraint(equalTo: navBar.layoutMarginsGuide.trailingAnchor, constant: -4),
//
//            rightButton.bottomAnchor.constraint(equalTo: navBar.bottomAnchor, constant: -6)
//        ])
    }
//
//    @objc private func profileTapped() {
//        print("Avatar tapped!")
//    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // enable large titles only while this VC is visible
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // turn off large titles before navigating away so destination VCs are normal
        navigationController?.navigationBar.prefersLargeTitles = false
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup
    /// If `isCategory` is true, we register the category cell nib and slightly different layout
    private func setupCollectionView(_ cv: UICollectionView?, isRecent: Bool, isCategory: Bool = false) {
        guard let cv = cv else { return }

        cv.dataSource = self
        cv.delegate = self
        cv.showsHorizontalScrollIndicator = false
        cv.backgroundColor = .clear
        cv.allowsSelection = true

        if let layout = cv.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .horizontal
            layout.minimumLineSpacing = isRecent ? 16 : 12
            layout.sectionInset = UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 18)
        }

        // Register cells (nib fallback)
        if isRecent {
            if Bundle.main.path(forResource: "RecentCollectionViewCell", ofType: "nib") != nil ||
               Bundle.main.path(forResource: "RecentCollectionViewCell", ofType: "xib") != nil {
                cv.register(UINib(nibName: "RecentCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: recentCellReuseId)
            }
        } else if isCategory {
            // Register the category cell
            if Bundle.main.path(forResource: "MemoryCategoryCollectionViewCell", ofType: "nib") != nil ||
               Bundle.main.path(forResource: "MemoryCategoryCollectionViewCell", ofType: "xib") != nil {
                cv.register(UINib(nibName: "MemoryCategoryCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: categoryCellReuseId)
            } else {
                // Fallback: if your XIB is named differently, try the generic name
                if Bundle.main.path(forResource: "MemoryCategoryCollectionViewCell", ofType: "xib") == nil {
                    // no-op — rely on Interface Builder registration if present
                }
            }
        } else {
            // MemoryCollectionViewCell XIB should exist and its reuse identifier must match memoryCellReuseId
            if Bundle.main.path(forResource: "MemoryCollectionViewCell", ofType: "nib") != nil ||
               Bundle.main.path(forResource: "MemoryCollectionViewCell", ofType: "xib") != nil {
                cv.register(UINib(nibName: "MemoryCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: memoryCellReuseId)
            }
        }
    }

    // MARK: - Data
    @objc private func memoriesUpdated(_ n: Notification) {
        reloadFromStore()
    }

    private func reloadFromStore() {
        DispatchQueue.global(qos: .userInitiated).async {
            let all = MemoryStore.shared.allMemories()
            DispatchQueue.main.async {
                self.memories = all
                self.recentsCollectionView.reloadData()
                self.categoriesCollectionView.reloadData()
                self.privateCollectionView.reloadData()
                self.sharedCollectionView.reloadData()

                self.recentsLabel.isHidden = self.recentMemories.isEmpty
            }
        }
    }

    // Navigate helper
    private func navigateToDetail(for mem: Memory) {
        let detailVC = MemoryDetailViewController(memory: mem)
        // ensure destination does not show large title
        detailVC.navigationItem.largeTitleDisplayMode = .never
        detailVC.hidesBottomBarWhenPushed = true
        if let nav = navigationController {
            nav.pushViewController(detailVC, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: detailVC)
            nav.modalPresentationStyle = .automatic
            present(nav, animated: true)
        }
    }

    // MARK: - (Example) Long-press handler placeholder (if you use it)
    @objc private func handleLongPress(_ gr: UILongPressGestureRecognizer) {
        // implement long-press behavior if needed (left as-is from your project)
    }

    // MARK: - Actions for category / listing navigation
    @IBAction func categoriesButtonTapped(_ sender: UIButton) {
        let vc = MemoryCategoriesViewController(nibName: "MemoryCategoriesViewController", bundle: nil)
        // ensure pushed VC doesn't use large title
        vc.navigationItem.largeTitleDisplayMode = .never
        vc.hidesBottomBarWhenPushed = true
        if let nav = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }

    @IBAction func showPrivateMemoriesTapped(_ sender: Any) {
        let listing = MemoryListing(nibName: "MemoryListing", bundle: nil)
        listing.navigationItem.largeTitleDisplayMode = .never
        listing.categoryTitle = "Private Memories"         // set category if you want filtering by category
        listing.visibilityFilter = [.private]
        listing.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(listing, animated: true)
    }

    @IBAction func showSharedMemoriesTapped(_ sender: Any) {
        let listing = MemoryListing(nibName: "MemoryListing", bundle: nil)
        listing.navigationItem.largeTitleDisplayMode = .never
        listing.categoryTitle = "Shared Memories"
        listing.visibilityFilter = [.everyone]
        listing.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(listing, animated: true)
    }

}

// MARK: - UICollectionViewDataSource & Delegate
extension MemoryViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == recentsCollectionView { return recentMemories.count }
        if collectionView == categoriesCollectionView { return categories.count }
        if collectionView == privateCollectionView { return privateMemories.count }
        return sharedMemories.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        // Recents
        if collectionView == recentsCollectionView {
            let mem = recentMemories[indexPath.item]
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: recentCellReuseId, for: indexPath)
            if let rc = cell as? RecentCollectionViewCell {
                let urlHint = viewModel.firstRemoteImageURLString(for: mem)
                rc.configure(with: mem, imageURLString: urlHint)
            }
            return cell
        }

        // Categories
        if collectionView == categoriesCollectionView {
            let category = categories[indexPath.item]
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: categoryCellReuseId, for: indexPath)
            if let cc = cell as? MemoryCategoryCollectionViewCell {
                // Note: MemoryCategoryCollectionViewCell.configure(with:) expects its Category enum;
                // we use title mapping here (the XIB cell's configure(withTitle:) is safe)
                cc.configure(withTitle: category.title)
            } else {
                // fallback: try to set a label or image view if your XIB differs
                if let iv = cell.contentView.viewWithTag(10) as? UIImageView {
                    iv.image = UIImage(systemName: "photo")
                }
            }
            return cell
        }

        // Private / Shared - MemoryCell
        let mem: Memory = (collectionView == privateCollectionView) ? privateMemories[indexPath.item] : sharedMemories[indexPath.item]

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: memoryCellReuseId, for: indexPath)
        if let mc = cell as? MemoryCollectionViewCell {
            mc.configure(with: mem)
            mc.delegate = self   // IMPORTANT: set delegate so cell taps are forwarded
        } else {
            // fallback to simple image tagging if not using XIB cell
            if let imgView = cell.contentView.viewWithTag(10) as? UIImageView {
                imgView.image = UIImage(systemName: "photo")
                if let att = mem.attachments.first(where: { $0.kind == .image }) {
                    let filename = att.filename.trimmingCharacters(in: .whitespacesAndNewlines)
                    if filename.lowercased().hasPrefix("http://") || filename.lowercased().hasPrefix("https://"), let url = URL(string: filename) {
                        ImageLoader.shared.load(from: url) { image in
                            DispatchQueue.main.async { imgView.image = image ?? UIImage(systemName: "photo") }
                        }
                    } else {
                        let localURL = MemoryStore.shared.urlForAttachment(filename: filename)
                        ImageLoader.shared.loadLocal(from: localURL) { image in
                            DispatchQueue.main.async { imgView.image = image ?? UIImage(systemName: "photo") }
                        }
                    }
                }
            }
        }

        return cell
    }

    // sizes
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == recentsCollectionView { return CGSize(width: 299, height: 166) }
        if collectionView == categoriesCollectionView { return CGSize(width: 105, height: 99) } // full-width category tiles (adjust as desired)
        return CGSize(width: 105, height: 99)
    }

    // Use collection selection to navigate as well (works even if cell's internal gesture exists)
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Categories selection
        if collectionView == categoriesCollectionView {
            // guard index safety
            guard indexPath.item >= 0 && indexPath.item < categories.count else { return }
            let category = categories[indexPath.item]
            let title = category.title
            print("Selected category: \(title)")

            // instantiate CategoryDetailViewController from XIB and set the category
            let vc = CategoryDetailViewController(nibName: "CategoryDetailViewController", bundle: nil)
            vc.categoryTitle = title
            vc.navigationItem.largeTitleDisplayMode = .never
            vc.hidesBottomBarWhenPushed = true

            // smooth push animation (same style used elsewhere)
            let t = CATransition()
            t.duration = 0.28
            t.type = .push
            t.subtype = .fromRight
            navigationController?.view.layer.add(t, forKey: kCATransition)

            navigationController?.pushViewController(vc, animated: false)
            return
        }

        let mem: Memory
        if collectionView == recentsCollectionView {
            mem = recentMemories[indexPath.item]
        } else if collectionView == privateCollectionView {
            mem = privateMemories[indexPath.item]
        } else {
            mem = sharedMemories[indexPath.item]
        }

        print("didSelectItemAt -> collection: \(collectionView == recentsCollectionView ? "recents" : collectionView == privateCollectionView ? "private" : "shared") index: \(indexPath.item)")
        print("Selected memory id: \(mem.id) title: \(mem.title) visibility: \(mem.visibility)")

        navigateToDetail(for: mem)
    }
}

// MARK: - MemoryCollectionViewCellDelegate
extension MemoryViewController: MemoryCollectionViewCellDelegate {
    func memoryCollectionViewCellDidTap(_ cell: MemoryCollectionViewCell) {
        // Find which collection view contains this cell
        if let ip = recentsCollectionView.indexPath(for: cell) {
            let mem = recentMemories[ip.item]
            print("didTap cell -> recents index: \(ip.item) id: \(mem.id)")
            navigateToDetail(for: mem); return
        }
        if let ip = privateCollectionView.indexPath(for: cell) {
            let mem = privateMemories[ip.item]
            print("didTap cell -> private index: \(ip.item) id: \(mem.id)")
            navigateToDetail(for: mem); return
        }
        if let ip = sharedCollectionView.indexPath(for: cell) {
            let mem = sharedMemories[ip.item]
            print("didTap cell -> shared index: \(ip.item) id: \(mem.id)")
            navigateToDetail(for: mem); return
        }

        print("memoryCollectionViewCellDidTap: couldn't determine indexPath")
    }
}
