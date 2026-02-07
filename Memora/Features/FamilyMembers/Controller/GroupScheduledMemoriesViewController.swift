// GroupScheduledMemoriesViewController.swift
import UIKit

class GroupScheduledMemoriesViewController: UIViewController {
    
    private let groupId: UUID
    private let groupName: String
    private var scheduledMemories: [ScheduledMemory] = []
    private var timer: Timer?
    
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 20
        layout.minimumInteritemSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 20, left: 16, bottom: 20, right: 16)
        layout.itemSize = CGSize(width: UIScreen.main.bounds.width - 32, height: 120)
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = UIColor(hex: "#F2F2F7")
        cv.showsVerticalScrollIndicator = false
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()
    
    private let emptyStateView: UIView = {
        let view = UIView()
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.color = UIColor(hex: "#5AC8FA")
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    init(groupId: UUID, groupName: String) {
        self.groupId = groupId
        self.groupName = groupName
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionView()
        loadScheduledMemories()
        startCountdownTimer()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        title = "Memory Capsules"
        navigationController?.navigationBar.prefersLargeTitles = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(hex: "#F2F2F7")
        
        // Navigation bar
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(hex: "#F2F2F7")
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        
        // Add UI components
        view.addSubview(collectionView)
        view.addSubview(loadingIndicator)
        view.addSubview(emptyStateView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.widthAnchor.constraint(equalToConstant: 300),
            emptyStateView.heightAnchor.constraint(equalToConstant: 300)
        ])
        
        setupEmptyStateView()
    }
    
    private func setupCollectionView() {
        collectionView.register(MemoryCapsuleCell.self, forCellWithReuseIdentifier: "CapsuleCell")
        collectionView.dataSource = self
        collectionView.delegate = self
    }
    
    private func setupEmptyStateView() {
        emptyStateView.subviews.forEach { $0.removeFromSuperview() }
        
        let icon = UIImageView(image: UIImage(systemName: "gift"))
        icon.tintColor = UIColor(hex: "#5AC8FA")
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.addSubview(icon)
        
        let titleLabel = UILabel()
        titleLabel.text = "No Memory Capsules"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.addSubview(titleLabel)
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = "No memory capsules have been scheduled for this group yet.\n\nBe the first to create a nostalgic surprise!"
        descriptionLabel.font = UIFont.systemFont(ofSize: 16)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.addSubview(descriptionLabel)
        
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            icon.topAnchor.constraint(equalTo: emptyStateView.topAnchor, constant: 20),
            icon.widthAnchor.constraint(equalToConstant: 80),
            icon.heightAnchor.constraint(equalToConstant: 80),
            
            titleLabel.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: emptyStateView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: emptyStateView.trailingAnchor, constant: -20),
            
            descriptionLabel.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            descriptionLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor, constant: 40),
            descriptionLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor, constant: -40),
            descriptionLabel.bottomAnchor.constraint(lessThanOrEqualTo: emptyStateView.bottomAnchor, constant: -20)
        ])
    }
    
    private func loadScheduledMemories() {
        loadingIndicator.startAnimating()
        
        Task {
            do {
                let memories = try await SupabaseManager.shared.getScheduledMemoriesForGroup(groupId: groupId)
                
                DispatchQueue.main.async {
                    self.scheduledMemories = memories
                    self.collectionView.reloadData()
                    self.loadingIndicator.stopAnimating()
                    self.updateEmptyState()
                }
            } catch {
                DispatchQueue.main.async {
                    self.loadingIndicator.stopAnimating()
                    self.showError(message: "Failed to load memory capsules: \(error.localizedDescription)")
                    self.updateEmptyState()
                }
            }
        }
    }
    
    private func updateEmptyState() {
        emptyStateView.isHidden = !scheduledMemories.isEmpty
    }
    
    private func startCountdownTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Update all visible cells
            for cell in self.collectionView.visibleCells {
                if let capsuleCell = cell as? MemoryCapsuleCell,
                   let indexPath = self.collectionView.indexPath(for: cell),
                   indexPath.item < self.scheduledMemories.count {
                    let memory = self.scheduledMemories[indexPath.item]
                    capsuleCell.configure(with: memory) { [weak self] in
                        self?.handleCapsuleTap(memory: memory)
                    }
                }
            }
            
            // Check for newly ready memories
            self.checkForReadyMemories()
        }
    }
    
    private func checkForReadyMemories() {
        let readyMemories = scheduledMemories.filter { $0.isReadyToOpen }
        for memory in readyMemories {
            print("🎁 Memory ready: \(memory.title)")
        }
    }
    
    private func showError(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func handleCapsuleTap(memory: ScheduledMemory) {
        if memory.isReadyToOpen {
            // Show your beautiful gift box animation
            let animationVC = GiftBoxOverlayViewController(memoryTitle: memory.title) { [weak self] in
                // After animation completes, open the memory
                self?.openAndMarkMemory(memory)
            }
            
            // Add haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            
            present(animationVC, animated: true)
        } else {
            // Fetch creator info
            Task {
                do {
                    let creatorInfo = try await SupabaseManager.shared.getMemoryCreatorInfo(memoryId: memory.id)
                    
                    DispatchQueue.main.async {
                        self.showLockedMemoryAlert(memory: memory, creatorName: creatorInfo.name)
                    }
                } catch {
                    DispatchQueue.main.async {
                        // Fallback to showing without creator name
                        self.showLockedMemoryAlert(memory: memory, creatorName: nil)
                    }
                }
            }
        }
    }
    
    private func showLockedMemoryAlert(memory: ScheduledMemory, creatorName: String?) {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        // Create the message with creator info
        var message = ""
        
        if let creatorName = creatorName {
            message += "👤 **Created by:** \(creatorName)\n\n"
        }
        
        message += "📅 **Unlocks on:** \(formatter.string(from: memory.releaseAt))\n\n"
        message += "⌛ Time remaining: \(self.timeRemainingString(from: memory.releaseAt))"
        
        let alert = UIAlertController(
            title: "🔒 Memory Capsule Locked",
            message: message,
            preferredStyle: .alert
        )
        
        // Style the message for better readability
        if let messageLabel = alert.view.subviews.first?.subviews.first?.subviews.first as? UILabel {
            messageLabel.textAlignment = .left
            messageLabel.numberOfLines = 0
        }
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func timeRemainingString(from date: Date) -> String {
        let now = Date()
        let diff = date.timeIntervalSince(now)
        
        if diff <= 0 {
            return "Ready to open!"
        }
        
        let days = Int(diff) / 86400
        let hours = Int(diff) / 3600 % 24
        let minutes = Int(diff) / 60 % 60
        let seconds = Int(diff) % 60
        
        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s"), \(hours) hour\(hours == 1 ? "" : "s")"
        } else if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s"), \(minutes) minute\(minutes == 1 ? "" : "s")"
        } else if minutes > 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s"), \(seconds) second\(seconds == 1 ? "" : "s")"
        } else {
            return "\(seconds) second\(seconds == 1 ? "" : "s")"
        }
    }
    
    private func openAndMarkMemory(_ memory: ScheduledMemory) {
        Task {
            do {
                // Mark memory as opened for this group
                try await SupabaseManager.shared.openGroupScheduledMemory(
                    memoryId: memory.id,
                    groupId: self.groupId
                )
                
                // Remove from local list
                if let index = self.scheduledMemories.firstIndex(where: { $0.id == memory.id }) {
                    DispatchQueue.main.async {
                        self.scheduledMemories.remove(at: index)
                        self.collectionView.deleteItems(at: [IndexPath(item: index, section: 0)])
                        self.updateEmptyState()
                    }
                }
                
                // Fetch and navigate to memory detail
                try await self.navigateToMemoryDetail(memoryId: memory.id)
                
            } catch {
                DispatchQueue.main.async {
                    self.showError(message: "Failed to open memory: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func navigateToMemoryDetail(memoryId: UUID) async throws {
        let memory = try await SupabaseManager.shared.getMemory(by: memoryId)
        
        DispatchQueue.main.async {
            // Convert to your local Memory model
            let localMemory = self.convertToLocalMemory(memory)
            
            // Navigate to memory detail (adapt this to your existing navigation)
            let detailVC = MemoryDetailViewController(memory: localMemory)
            detailVC.hidesBottomBarWhenPushed = true
            self.navigationController?.pushViewController(detailVC, animated: true)
        }
    }
    
    private func convertToLocalMemory(_ supabaseMemory: SupabaseMemory) -> Memory {
        // Convert SupabaseMemory to your local Memory model
        // This depends on your existing Memory model structure
        return Memory(
            id: supabaseMemory.id.uuidString,
            ownerId: supabaseMemory.userId.uuidString,
            title: supabaseMemory.title,
            body: nil,
            category: supabaseMemory.category,
            attachments: [],
            visibility: .private, // Now it's opened and private
            scheduledFor: nil,
            createdAt: supabaseMemory.createdAt
        )
    }
}

// MARK: - UICollectionView DataSource & Delegate
extension GroupScheduledMemoriesViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return scheduledMemories.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CapsuleCell", for: indexPath) as! MemoryCapsuleCell
        let memory = scheduledMemories[indexPath.item]
        cell.configure(with: memory) { [weak self] in
            self?.handleCapsuleTap(memory: memory)
        }
        return cell
    }
}
