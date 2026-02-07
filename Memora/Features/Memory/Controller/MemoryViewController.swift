import UIKit
import SwiftUI
import UserNotifications

final class MemoryViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var recentsCollectionView: UICollectionView!
    @IBOutlet weak var recentsLabel: UILabel!
    @IBOutlet weak var premiumCardView: UIView!
    @IBOutlet weak var categoriesCollectionView: UICollectionView!
    @IBOutlet weak var privateCollectionView: UICollectionView!
    @IBOutlet weak var sharedCollectionView: UICollectionView!
    

    // MARK: - Config
    private let recentCellReuseId = "RecentCell"
    private let memoryCellReuseId = MemoryCollectionViewCell.reuseIdentifier
    private let categoryCellReuseId = "CategoryCell"
    private let capsuleCellReuseId = "CapsuleCell"

    // MARK: - Data
    private var memories: [SupabaseMemory] = []
    private var scheduledMemories: [ScheduledMemory] = []
    private var countdownTimer: Timer?

    private var recentMemories: [SupabaseMemory] {
        Array(memories.sorted { $0.createdAt > $1.createdAt }.prefix(3))
    }

    private var privateMemories: [SupabaseMemory] {
        memories
            .filter { $0.visibility == "private" }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var sharedMemories: [SupabaseMemory] {
        memories
            .filter { $0.visibility == "shared" || $0.visibility == "group" }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    private var scheduledVisibilityMemories: [SupabaseMemory] {
        memories
            .filter { $0.visibility == "scheduled" }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private let viewModel = MemoryViewModel(recentsLimit: 6)

    // MARK: - Categories
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
        
        print("=== DEBUG: MemoryViewController Outlets ===")

        setupNavigationBar()
        setupPremiumCardTap()

        // Configure collection views
        setupCollectionView(recentsCollectionView, isRecent: true)
        setupCollectionView(categoriesCollectionView, isRecent: false, isCategory: true)
        setupCollectionView(privateCollectionView, isRecent: false)
        setupCollectionView(sharedCollectionView, isRecent: false)
        

        // Add long-press gesture recognizers
        let privateLong = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        privateLong.minimumPressDuration = 0.45
        privateCollectionView.addGestureRecognizer(privateLong)

        let sharedLong = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        sharedLong.minimumPressDuration = 0.45
        sharedCollectionView.addGestureRecognizer(sharedLong)

        recentsLabel.text = "Recents"

        // Seed and reload
        MemorySeedLoader.seedFromBundleJSON(named: "memories_seed", downloadRemoteImages: true) { _ in
            self.reloadFromStore()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(memoriesUpdated(_:)), name: .memoriesUpdated, object: nil)

        // initial load
        reloadFromStore()
        

        // Request notification permissions
        requestNotificationPermissions()
        
        
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
        
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.prefersLargeTitles = false
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        countdownTimer?.invalidate()
    }

    // MARK: - Setup
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

        // DEBUG: Check what nib files exist
        print("=== DEBUG: Setting up collection view ===")

        // Register cells
        if isRecent {
            if Bundle.main.path(forResource: "RecentCollectionViewCell", ofType: "nib") != nil {
                cv.register(UINib(nibName: "RecentCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: recentCellReuseId)
            }
        } else if isCategory {
            if Bundle.main.path(forResource: "MemoryCategoryCollectionViewCell", ofType: "nib") != nil {
                cv.register(UINib(nibName: "MemoryCategoryCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: categoryCellReuseId)
            }
        } else {
            if Bundle.main.path(forResource: "MemoryCollectionViewCell", ofType: "nib") != nil {
                cv.register(UINib(nibName: "MemoryCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: memoryCellReuseId)
            }
        }
    }

    
    private func setupNoScheduledViewUI(_ container: UIView) {
        container.subviews.forEach { $0.removeFromSuperview() }
        
        // Create icon
        let icon = UIImageView(image: UIImage(systemName: "gift"))
        icon.tintColor = UIColor(hex: "#5AC8FA")
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(icon)
        
        // Create title label
        let titleLabel = UILabel()
        titleLabel.text = "No Memory Capsules"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        // Create description label
        let descLabel = UILabel()
        descLabel.text = "Schedule memories to open later and create a nostalgic surprise!"
        descLabel.font = UIFont.systemFont(ofSize: 14)
        descLabel.textColor = .secondaryLabel
        descLabel.textAlignment = .center
        descLabel.numberOfLines = 0
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(descLabel)
        
        // Create schedule button
        let scheduleButton = UIButton(type: .system)
        scheduleButton.setTitle("Schedule a Memory", for: .normal)
        scheduleButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        scheduleButton.setTitleColor(.white, for: .normal)
        scheduleButton.backgroundColor = UIColor(hex: "#5AC8FA")
        scheduleButton.layer.cornerRadius = 12
        scheduleButton.addTarget(self, action: #selector(showScheduleMemory), for: .touchUpInside)
        scheduleButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scheduleButton)
        
        // Constraints
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            icon.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            icon.widthAnchor.constraint(equalToConstant: 60),
            icon.heightAnchor.constraint(equalToConstant: 60),
            
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20),
            
            descLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 40),
            descLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -40),
            
            scheduleButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            scheduleButton.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 20),
            scheduleButton.widthAnchor.constraint(equalToConstant: 200),
            scheduleButton.heightAnchor.constraint(equalToConstant: 44),
            scheduleButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20)
        ])
    }


    // Add this property to track if we've already tried to create the collection view
    private var hasAttemptedToCreateCollectionView = false

    // MARK: - Data Loading
    private func reloadFromStore() {
        Task {
            do {
                let all = try await SupabaseManager.shared.getUserMemories()
                
                DispatchQueue.main.async {
                    self.memories = all
                    
                    // Debug logging
                    print("\n🔍 DEBUG: ALL MEMORIES")
                    for memory in all {
                        print("📝 '\(memory.title)' - Visibility: \(memory.visibility)")
                    }
                    
                    print("\n📊 COUNTS:")
                    print("Total: \(all.count)")
                    print("Scheduled: \(self.scheduledVisibilityMemories.count)")
                    print("Private: \(self.privateMemories.count)")
                    print("Shared: \(self.sharedMemories.count)")
                    
                    // Reload all collection views
                    self.recentsCollectionView.reloadData()
                    self.categoriesCollectionView.reloadData()
                    self.privateCollectionView.reloadData()
                    self.sharedCollectionView.reloadData()
                    self.recentsLabel.isHidden = self.recentMemories.isEmpty
                }
            } catch {
                print("❌ Error fetching memories: \(error)")
                DispatchQueue.main.async {
                    self.memories = []
                    self.recentsCollectionView.reloadData()
                    self.privateCollectionView.reloadData()
                    self.sharedCollectionView.reloadData()
                }
            }
        }
    }
    
    @objc private func memoriesUpdated(_ n: Notification) {
        reloadFromStore()
    }
    
    private func checkForReadyMemories() {
        let readyMemories = scheduledMemories.filter { $0.isReadyToOpen }
        for memory in readyMemories {
            self.scheduleReadyNotification(for: memory)
        }
    }
    
    @objc private func showScheduleMemory() {
        let alert = UIAlertController(
            title: "Schedule Memory",
            message: "Go to create a new memory and select 'Schedule' option to create a memory capsule.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Notifications
    private func requestNotificationPermissions() {
        let center = UNUserNotificationCenter.current()
        
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification permissions: \(error)")
            }
            
            if granted {
                print("Notification permissions granted")
            }
        }
    }
    
    private func scheduleReadyNotification(for memory: ScheduledMemory) {
        let center = UNUserNotificationCenter.current()
        
        center.removePendingNotificationRequests(withIdentifiers: ["capsule_ready_\(memory.id.uuidString)"])
        
        let content = UNMutableNotificationContent()
        content.title = "Memory Capsule Ready! 🎁"
        content.body = "Your memory '\(memory.title)' is ready to open!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "capsule_ready_\(memory.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    // MARK: - Notification Handling
    func openMemoryFromNotification(memoryId: UUID) {
        Task {
            do {
                // Try to load the scheduled memory from Supabase
                let scheduledMemory = try await SupabaseManager.shared.getScheduledMemory(by: memoryId)
                
                DispatchQueue.main.async {
                    if scheduledMemory.isReadyToOpen {
                        // Create a fake SupabaseMemory to pass to navigateToDetail
                        let supabaseMemory = SupabaseMemory(
                            id: scheduledMemory.id,
                            userId: scheduledMemory.userId,
                            title: scheduledMemory.title,
                            year: scheduledMemory.year,
                            category: scheduledMemory.category,
                            visibility: "scheduled",
                            releaseAt: scheduledMemory.releaseAt,
                            createdAt: scheduledMemory.createdAt,
                            updatedAt: scheduledMemory.createdAt,
                            memoryMedia: []
                        )
                        
                        // Convert to Memory and navigate
                        let imageAttachments: [MemoryAttachment] = []
                        let localMemory = Memory(
                            id: scheduledMemory.id.uuidString,
                            ownerId: scheduledMemory.userId.uuidString,
                            title: scheduledMemory.title,
                            body: nil,
                            category: scheduledMemory.category,
                            attachments: imageAttachments,
                            visibility: .scheduled,
                            scheduledFor: scheduledMemory.releaseAt,
                            createdAt: scheduledMemory.createdAt
                        )
                        
                        let detailVC = MemoryDetailViewController(memory: localMemory)
                        detailVC.navigationItem.largeTitleDisplayMode = .never
                        detailVC.hidesBottomBarWhenPushed = true
                        
                        if let nav = self.navigationController {
                            nav.pushViewController(detailVC, animated: true)
                        }
                    } else {
                        // Show alert if not ready yet
                        self.showAlert(
                            title: "Not Ready Yet",
                            message: "This memory capsule isn't ready to open yet. It unlocks on \(scheduledMemory.releaseAt.formatted(date: .abbreviated, time: .shortened))."
                        )
                    }
                }
            } catch {
                // If not a scheduled memory, try to find it in local memories
                DispatchQueue.main.async {
                    if let memory = self.memories.first(where: { $0.id == memoryId }) {
                        self.navigateToDetail(for: memory)
                    } else {
                        // Try to fetch from server
                        Task {
                            do {
                                let memory = try await SupabaseManager.shared.getMemory(by: memoryId)
                                self.navigateToDetail(for: memory)
                            } catch {
                                self.showAlert(
                                    title: "Memory Not Found",
                                    message: "Could not find the memory. It may have been deleted or you don't have permission to view it."
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private func fetchAndOpenMemory(memoryId: UUID) {
        Task {
            do {
                let memory = try await SupabaseManager.shared.getMemory(by: memoryId)
                DispatchQueue.main.async {
                    self.navigateToDetail(for: memory)
                }
            } catch {
                DispatchQueue.main.async {
                    self.showAlert(
                        title: "Memory Not Found",
                        message: "Could not find the memory. It may have been deleted or you don't have permission to view it."
                    )
                }
            }
        }
    }

    // MARK: - Navigation
    private func navigateToDetail(for mem: SupabaseMemory) {
        let imageAttachments = mem.memoryMedia?
            .filter { $0.mediaType == "photo" }
            .map { media in
                MemoryAttachment(
                    id: media.id.uuidString,
                    kind: .image,
                    filename: media.mediaUrl,
                    createdAt: media.createdAt
                )
            } ?? []
        
        let audioAttachments = mem.memoryMedia?
            .filter { $0.mediaType == "audio" }
            .map { media in
                MemoryAttachment(
                    id: media.id.uuidString,
                    kind: .audio,
                    filename: media.mediaUrl,
                    createdAt: media.createdAt
                )
            } ?? []
        
        let allAttachments = imageAttachments + audioAttachments
        let body = mem.memoryMedia?.first { $0.mediaType == "text" }?.textContent
        
        let localMemory = Memory(
            id: mem.id.uuidString,
            ownerId: mem.userId.uuidString,
            title: mem.title,
            body: body,
            category: mem.category,
            attachments: allAttachments,
            visibility: MemoryVisibility.fromDatabaseString(mem.visibility),
            scheduledFor: mem.releaseAt,
            createdAt: mem.createdAt
        )
        
        let detailVC = MemoryDetailViewController(memory: localMemory)
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

    @objc private func handleLongPress(_ gr: UILongPressGestureRecognizer) {
        // implement long-press behavior if needed
    }

    // MARK: - Actions
    @IBAction func categoriesButtonTapped(_ sender: UIButton) {
        let vc = MemoryCategoriesViewController(nibName: "MemoryCategoriesViewController", bundle: nil)
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
        listing.categoryTitle = "Private Memories"
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

    // MARK: - Premium
    private func setupPremiumCardTap() {
        premiumCardView.isUserInteractionEnabled = true
        premiumCardView.accessibilityTraits = .button
        premiumCardView.accessibilityLabel = "Premium subscription"

        let tap = UITapGestureRecognizer(target: self, action: #selector(premiumCardTapped))
        premiumCardView.addGestureRecognizer(tap)
    }
    
    @objc private func premiumCardTapped() {
        let vc = PremiumSubscriptionViewController()
        vc.modalPresentationStyle = .pageSheet

        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.selectedDetentIdentifier = .large
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
        }

        present(vc, animated: true)
    }
    
    // MARK: - Helper Methods
    private func showToast(message: String) {
        let toastLabel = UILabel()
        toastLabel.text = message
        toastLabel.textColor = .white
        toastLabel.textAlignment = .center
        toastLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        toastLabel.backgroundColor = UIColor(hex: "#5AC8FA").withAlphaComponent(0.9)
        toastLabel.layer.cornerRadius = 8
        toastLabel.clipsToBounds = true
        toastLabel.alpha = 0
        
        view.addSubview(toastLabel)
        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            toastLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            toastLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 300),
            toastLabel.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        UIView.animate(withDuration: 0.3) {
            toastLabel.alpha = 1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            UIView.animate(withDuration: 0.3) {
                toastLabel.alpha = 0
            } completion: { _ in
                toastLabel.removeFromSuperview()
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UICollectionViewDataSource & Delegate
extension MemoryViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == recentsCollectionView { return recentMemories.count }
        if collectionView == categoriesCollectionView { return categories.count }
        if collectionView == privateCollectionView { return privateMemories.count }
        if collectionView == sharedCollectionView { return sharedMemories.count }
        //if collectionView == scheduledCollectionView { return scheduledVisibilityMemories.count }
        return 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        
        // Recents
        if collectionView == recentsCollectionView {
            let mem = recentMemories[indexPath.item]
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: recentCellReuseId, for: indexPath)
            if let rc = cell as? RecentCollectionViewCell {
                let imageUrl = mem.memoryMedia?.first(where: { $0.mediaType == "photo" })?.mediaUrl
                rc.configure(with: mem, imageURLString: imageUrl)
            }
            return cell
        }

        // Categories
        if collectionView == categoriesCollectionView {
            let category = categories[indexPath.item]
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: categoryCellReuseId, for: indexPath)
            if let cc = cell as? MemoryCategoryCollectionViewCell {
                cc.configure(withTitle: category.title)
            } else {
                if let iv = cell.contentView.viewWithTag(10) as? UIImageView {
                    iv.image = UIImage(systemName: "photo")
                }
            }
            return cell
        }

        // Private / Shared
        let mem: SupabaseMemory = (collectionView == privateCollectionView) ? privateMemories[indexPath.item] : sharedMemories[indexPath.item]

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: memoryCellReuseId, for: indexPath)
        if let mc = cell as? MemoryCollectionViewCell {
            mc.configure(with: mem)
            mc.delegate = self
        } else {
            if let imgView = cell.contentView.viewWithTag(10) as? UIImageView {
                imgView.image = UIImage(systemName: "photo")
                if let imageMedia = mem.memoryMedia?.first(where: { $0.mediaType == "photo" }) {
                    let imageUrl = imageMedia.mediaUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let url = URL(string: imageUrl) {
                        ImageLoader.shared.load(from: url) { image in
                            DispatchQueue.main.async { imgView.image = image ?? UIImage(systemName: "photo") }
                        }
                    }
                }
            }
        }

        return cell
    }
 
    private func handleCapsuleTap(memory: SupabaseMemory) {
        // Check if ready
        let isReady = (memory.releaseAt ?? Date()) <= Date()
        
        if isReady {
            // 1. Trigger Haptic Feedback
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            
            // 2. Present Gift Box Animation
            let animationVC = GiftBoxOverlayViewController(memoryTitle: memory.title) { [weak self] in
                // 3. Navigate after animation finishes
                self?.navigateToDetail(for: memory)
            }
            
            self.present(animationVC, animated: true)
            
        } else {
            // Locked State Animation (Shake the cell?)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            
            // Show Timer Alert
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            
            let alert = UIAlertController(
                title: "Still Locked 🔒",
                message: "This memory is sealed until:\n\(formatter.string(from: memory.releaseAt ?? Date()))",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(alert, animated: true)
        }
    }

    // Add this helper method to convert SupabaseMemory to ScheduledMemory
    private func convertToScheduledMemory(_ supabaseMemory: SupabaseMemory) -> ScheduledMemory {
        return ScheduledMemory(
            id: supabaseMemory.id,
            title: supabaseMemory.title,
            year: supabaseMemory.year,
            category: supabaseMemory.category,
            releaseAt: supabaseMemory.releaseAt ?? Date(),
            createdAt: supabaseMemory.createdAt,
            userId: supabaseMemory.userId,
            previewImageUrl: supabaseMemory.memoryMedia?.first { $0.mediaType == "photo" }?.mediaUrl,
            isReadyToOpen: (supabaseMemory.releaseAt ?? Date()) <= Date()
        )
    }

    // Cell sizes
    // In MemoryViewController.swift

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == recentsCollectionView { return CGSize(width: 299, height: 166) }
        if collectionView == categoriesCollectionView { return CGSize(width: 105, height: 99) }
        
        // THIS IS THE UPDATE YOU WANT:
        //if collectionView == scheduledCollectionView { return CGSize(width: 170, height: 210) }
        
        return CGSize(width: 105, height: 99)
    }

    // Selection
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Scheduled capsules

        
        // Categories
        if collectionView == categoriesCollectionView {
            guard indexPath.item < categories.count else { return }
            let category = categories[indexPath.item]
            
            let vc = CategoryDetailViewController(nibName: "CategoryDetailViewController", bundle: nil)
            vc.categoryTitle = category.title
            vc.navigationItem.largeTitleDisplayMode = .never
            vc.hidesBottomBarWhenPushed = true

            navigationController?.pushViewController(vc, animated: true)
            return
        }

        // Other memories
        let mem: SupabaseMemory
        if collectionView == recentsCollectionView {
            mem = recentMemories[indexPath.item]
        } else if collectionView == privateCollectionView {
            mem = privateMemories[indexPath.item]
        } else {
            mem = sharedMemories[indexPath.item]
        }
        
        navigateToDetail(for: mem)
    }
}

// MARK: - MemoryCollectionViewCellDelegate
extension MemoryViewController: MemoryCollectionViewCellDelegate {
    func memoryCollectionViewCellDidTap(_ cell: MemoryCollectionViewCell) {
        if let ip = recentsCollectionView.indexPath(for: cell) {
            navigateToDetail(for: recentMemories[ip.item])
        } else if let ip = privateCollectionView.indexPath(for: cell) {
            navigateToDetail(for: privateMemories[ip.item])
        } else if let ip = sharedCollectionView.indexPath(for: cell) {
            navigateToDetail(for: sharedMemories[ip.item])
        }
    }
}

// MARK: - UIColor Extension
extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
