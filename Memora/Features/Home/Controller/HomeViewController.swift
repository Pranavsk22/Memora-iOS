import UIKit

class HomeViewController: UIViewController, UIGestureRecognizerDelegate {

    @IBOutlet weak var promptsCollectionView: UICollectionView!
    @IBOutlet weak var categoriesCollectionView: UICollectionView!
    @IBOutlet weak var exploreCollectionView: UICollectionView!
    @IBOutlet weak var exploreHeightConstraint: NSLayoutConstraint!

    private let prompts = PromptData.samplePrompts
    private let categories = CategoryData.sample
    private var explorePrompts: [DetailedPrompt] = DetailedPromptData.samplePrompts.shuffled()

    private let exploreItemHeight: CGFloat = 394
    private let exploreLineSpacing: CGFloat = 35
    private let exploreHorizontalInset: CGFloat = 16

    override func viewDidLoad() {
        super.viewDidLoad()
        setupPromptsCollectionView()
        setupCategoriesCollectionView()
        setupExploreCollectionView()
        updateExploreHeight()
        setupNavBar()

        // Ensure interactive pop gesture is enabled and delegate is set so swipe-to-go-back works
        navigationController?.interactivePopGestureRecognizer?.delegate = self
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Keep large titles enabled while Home is visible
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
    }

    private func setupNavBar() {

        // Enable large title
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.title = "Home"

        // --- Make Home large title 34 heavy ---
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 34, weight: .heavy),
            .foregroundColor: UIColor.label
        ]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance

        // --- Avatar View (right bar button) ---
        let size: CGFloat = 36
        let avatarContainer = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        avatarContainer.translatesAutoresizingMaskIntoConstraints = false

        let imgView = UIImageView(frame: avatarContainer.bounds)
        imgView.translatesAutoresizingMaskIntoConstraints = false
        // Use session avatar (falls back to "photo" asset if not present)
        imgView.image = UIImage(named: Session.shared.currentUser.avatarName ?? "photo")
        imgView.contentMode = .scaleAspectFill
        imgView.layer.cornerRadius = size / 2
        imgView.clipsToBounds = true

        avatarContainer.addSubview(imgView)

        NSLayoutConstraint.activate([
            imgView.leadingAnchor.constraint(equalTo: avatarContainer.leadingAnchor),
            imgView.trailingAnchor.constraint(equalTo: avatarContainer.trailingAnchor),
            imgView.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
            imgView.bottomAnchor.constraint(equalTo: avatarContainer.bottomAnchor)
        ])

        // Button wrapper so it behaves like a bar button
        let button = UIButton(type: .custom)
        button.frame = avatarContainer.bounds
        button.addSubview(avatarContainer)
        button.addTarget(self, action: #selector(profileTapped), for: .touchUpInside)

        // Set fixed size constraints for the container
        avatarContainer.widthAnchor.constraint(equalToConstant: size).isActive = true
        avatarContainer.heightAnchor.constraint(equalToConstant: size).isActive = true

        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: button)

        // Force layout update to help alignment in large-title mode
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.navigationController?.navigationBar.setNeedsLayout()
            self.navigationController?.navigationBar.layoutIfNeeded()
        }
    }

    @objc private func profileTapped() {
        // no-op placeholder; keep minimal as requested
        print("Profile tapped")
    }

    private func setupPromptsCollectionView() {
        let nib = UINib(nibName: "PromptCollectionViewCell", bundle: nil)
        promptsCollectionView.register(nib, forCellWithReuseIdentifier: "PromptCell")
        promptsCollectionView.dataSource = self
        promptsCollectionView.delegate = self
        promptsCollectionView.showsHorizontalScrollIndicator = false
        promptsCollectionView.backgroundColor = .clear

        if let layout = promptsCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .horizontal
            layout.estimatedItemSize = .zero
        }
    }

    private func setupCategoriesCollectionView() {
        let nib = UINib(nibName: "CategoryCollectionViewCell", bundle: nil)
        categoriesCollectionView.register(nib, forCellWithReuseIdentifier: "CategoryCell")
        categoriesCollectionView.dataSource = self
        categoriesCollectionView.delegate = self
        categoriesCollectionView.showsHorizontalScrollIndicator = false
        categoriesCollectionView.backgroundColor = .clear

        if let layout = categoriesCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
            layout.scrollDirection = .horizontal
        }
    }

    private func setupExploreCollectionView() {
        let nib = UINib(nibName: "ExploreMoreCollectionViewCell", bundle: nil)
        exploreCollectionView.register(nib, forCellWithReuseIdentifier: ExploreMoreCollectionViewCell.reuseId)
        exploreCollectionView.dataSource = self
        exploreCollectionView.delegate = self
        exploreCollectionView.backgroundColor = .clear
        exploreCollectionView.isScrollEnabled = false

        if let layout = exploreCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .vertical
            layout.minimumLineSpacing = exploreLineSpacing
            layout.sectionInset = UIEdgeInsets(top: 0, left: exploreHorizontalInset, bottom: 0, right: exploreHorizontalInset)
            layout.itemSize = CGSize(width: view.bounds.width - (exploreHorizontalInset * 2), height: exploreItemHeight)
        }

        if exploreHeightConstraint == nil {
            exploreCollectionView.translatesAutoresizingMaskIntoConstraints = false
            let h = exploreCollectionView.heightAnchor.constraint(equalToConstant: 0)
            h.isActive = true
            exploreHeightConstraint = h
        }
    }

    private func updateExploreHeight() {
        let count = explorePrompts.count
        let totalItemsHeight = CGFloat(count) * exploreItemHeight
        let totalSpacing = CGFloat(max(0, count - 1)) * exploreLineSpacing
        exploreHeightConstraint?.constant = totalItemsHeight + totalSpacing
        exploreCollectionView.reloadData()
    }

    // UIGestureRecognizerDelegate - allow interactive pop only when view controllers > 1
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return (navigationController?.viewControllers.count ?? 0) > 1
    }
}

// MARK: - UICollectionViewDataSource
extension HomeViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == categoriesCollectionView {
            return categories.count
        } else if collectionView == exploreCollectionView {
            return explorePrompts.count
        } else {
            return prompts.count
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == categoriesCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CategoryCell", for: indexPath)
            guard let categoryCell = cell as? CategoryCollectionViewCell else { return cell }
            let category = categories[indexPath.item]
            categoryCell.configure(iconSystemName: category.iconSystemName, text: category.title)
            return categoryCell

        } else if collectionView == exploreCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ExploreMoreCollectionViewCell.reuseId, for: indexPath)
            guard let exploreCell = cell as? ExploreMoreCollectionViewCell else { return cell }
            exploreCell.configure(with: explorePrompts[indexPath.item])
            return exploreCell

        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PromptCell", for: indexPath)
            guard let promptCell = cell as? PromptCollectionViewCell else { return cell }
            let prompt = prompts[indexPath.item]
            promptCell.configure(icon: UIImage(named: prompt.iconName), text: prompt.text)
            return promptCell
        }
    }
}

// MARK: - UICollectionViewDelegate
extension HomeViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        // Always prefer PUSH when available
        if let nav = self.navigationController {

            // PROMPTS
            if collectionView == promptsCollectionView {
                let p = prompts[indexPath.item]
                let promptModel = Prompt(iconName: p.iconName, text: p.text, category: p.category ?? "")
                let vc = PromptDetailViewControllerSimple(prompt: promptModel)
                // prevent the pushed VC from requesting a large-title nav bar
                vc.navigationItem.largeTitleDisplayMode = .never
                // hide tab bar when pushed
                vc.hidesBottomBarWhenPushed = true
                // Use standard push with animated:true so interactive pop works
                nav.pushViewController(vc, animated: true)
                return
            }

            // CATEGORIES
            if collectionView == categoriesCollectionView {
                let category = categories[indexPath.item]
                let vc = CategoryDetailsViewController(category: category)
                vc.navigationItem.largeTitleDisplayMode = .never
                vc.hidesBottomBarWhenPushed = true
                nav.pushViewController(vc, animated: true)
                return
            }

            // EXPLORE MORE
            if collectionView == exploreCollectionView {
                let selectedPrompt = explorePrompts[indexPath.item]
                let promptModel = Prompt(
                    iconName: selectedPrompt.imageURL ?? "",
                    text: selectedPrompt.text,
                    category: selectedPrompt.categorySlug ?? ""
                )
                let vc = PromptDetailViewControllerSimple(prompt: promptModel)
                vc.navigationItem.largeTitleDisplayMode = .never
                vc.hidesBottomBarWhenPushed = true
                nav.pushViewController(vc, animated: true)
                return
            }

        } else {
            // fallback to presenting modally when no navigation controller is available
            // for modal presentation the tab bar isn't shown, but we still wrap in nav to keep consistency
            if collectionView == promptsCollectionView {
                let p = prompts[indexPath.item]
                let promptModel = Prompt(iconName: p.iconName, text: p.text, category: p.category ?? "")
                let vc = PromptDetailViewControllerSimple(prompt: promptModel)
                let wrapped = UINavigationController(rootViewController: vc)
                wrapped.modalPresentationStyle = .fullScreen
                present(wrapped, animated: true)
                return
            }

            if collectionView == categoriesCollectionView {
                let category = categories[indexPath.item]
                let vc = CategoryDetailsViewController(category: category)
                let wrapped = UINavigationController(rootViewController: vc)
                wrapped.modalPresentationStyle = .fullScreen
                present(wrapped, animated: true)
                return
            }

            if collectionView == exploreCollectionView {
                let selectedPrompt = explorePrompts[indexPath.item]
                let promptModel = Prompt(
                    iconName: selectedPrompt.imageURL ?? "",
                    text: selectedPrompt.text,
                    category: selectedPrompt.categorySlug ?? ""
                )
                let vc = PromptDetailViewControllerSimple(prompt: promptModel)
                let wrapped = UINavigationController(rootViewController: vc)
                wrapped.modalPresentationStyle = .fullScreen
                present(wrapped, animated: true)
                return
            }
        }
    }
}
