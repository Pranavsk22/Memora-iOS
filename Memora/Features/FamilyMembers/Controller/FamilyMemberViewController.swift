//
//  FamilyMemberViewController.swift
//  Memora
//
//  Created by user@3 on 10/11/25.
//

import UIKit

class FamilyMemberViewController: UIViewController {
    
    var group: UserGroup?
    
    // MARK: - Data Properties
    private var members: [GroupMember] = []
    private var memories: [GroupMemory] = []
    private var isLoading = false
    private var errorMessage: String?
    
    // MARK: - UI Components
    @IBOutlet weak var membersCollectionView: UICollectionView!
    @IBOutlet weak var postsCollectionView: UICollectionView!
    @IBOutlet weak var profileButton: UIButton!
    @IBOutlet weak var groupNameLabel: UILabel!
    @IBOutlet weak var membersLoadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var memoriesLoadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var membersEmptyLabel: UILabel!
    @IBOutlet weak var memoriesEmptyLabel: UILabel!
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupCollections()
        
        // Load data if we have a group
        if let group = group {
            loadGroupData()
        } else {
            showError(message: "No group information available")
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Profile button circular styling
        let radius = min(profileButton.bounds.width, profileButton.bounds.height) / 2
        profileButton.layer.cornerRadius = radius
        profileButton.clipsToBounds = true
        profileButton.imageView?.contentMode = .scaleAspectFill
        profileButton.contentHorizontalAlignment = .fill
        profileButton.contentVerticalAlignment = .fill
        profileButton.layer.borderWidth = 1
        profileButton.layer.borderColor = UIColor.black.withAlphaComponent(0.12).cgColor
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIColor(
            red: 242/255,
            green: 242/255,
            blue: 247/255,
            alpha: 1
        )
        
        // Set group name if available
        groupNameLabel.text = group?.name ?? "My Family"
        
        // Configure loading indicators
        membersLoadingIndicator.hidesWhenStopped = true
        memoriesLoadingIndicator.hidesWhenStopped = true
        
        // Configure empty state labels
        membersEmptyLabel.isHidden = true
        membersEmptyLabel.text = "No members in this group"
        membersEmptyLabel.textColor = .systemGray
        
        memoriesEmptyLabel.isHidden = true
        memoriesEmptyLabel.text = "No memories shared in this group"
        memoriesEmptyLabel.textColor = .systemGray
    }
    
    private func setupCollections() {
        // Members Collection
        let memberNib = UINib(
            nibName: "FamilyMemberCollectionViewCell",
            bundle: nil
        )
        membersCollectionView.register(
            memberNib,
            forCellWithReuseIdentifier: "FamilyMemberCell"
        )
        membersCollectionView.delegate = self
        membersCollectionView.dataSource = self
        membersCollectionView.backgroundColor = .clear
        
        if let layout = membersCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .horizontal
            layout.itemSize = CGSize(width: 150, height: 190)
            layout.minimumLineSpacing = 16
            layout.sectionInset = UIEdgeInsets(
                top: 0,
                left: 16,
                bottom: 0,
                right: 16
            )
        }
        
        // Posts Collection
        let memoryNib = UINib(
            nibName: "FamilyMemoriesCollectionViewCell",
            bundle: nil
        )
        postsCollectionView.register(
            memoryNib,
            forCellWithReuseIdentifier: "FamilyMemoriesCell"
        )
        postsCollectionView.delegate = self
        postsCollectionView.dataSource = self
        postsCollectionView.backgroundColor = .clear
        postsCollectionView.showsVerticalScrollIndicator = false
        
        if let layout = postsCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .vertical
            layout.minimumLineSpacing = 35
            layout.sectionInset = UIEdgeInsets(
                top: 0,
                left: 16,
                bottom: 16,
                right: 16
            )
            layout.itemSize = CGSize(
                width: view.bounds.width - 32,
                height: 394
            )
        }
    }
    
    // MARK: - Data Loading
    private func loadGroupData() {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Show loading states
        membersLoadingIndicator.startAnimating()
        memoriesLoadingIndicator.startAnimating()
        membersEmptyLabel.isHidden = true
        memoriesEmptyLabel.isHidden = true
        
        // Load members and memories in parallel
        Task {
            await withTaskGroup(of: Void.self) { taskGroup in
                taskGroup.addTask { [weak self] in
                    await self?.loadMembers()
                }
                
                taskGroup.addTask { [weak self] in
                    await self?.loadMemories()
                }
            }
            
            DispatchQueue.main.async {
                self.isLoading = false
                self.updateUI()
            }
        }
    }
    
    private func loadMembers() async {
        guard let group = group else { return }
        
        do {
            let fetchedMembers = try await SupabaseManager.shared.getGroupMembers(groupId: group.id)
            
            DispatchQueue.main.async {
                self.members = fetchedMembers
                self.membersCollectionView.reloadData()
                self.membersLoadingIndicator.stopAnimating()
                self.membersEmptyLabel.isHidden = !self.members.isEmpty
            }
        } catch {
            print("Error loading members: \(error)")
            DispatchQueue.main.async {
                self.membersLoadingIndicator.stopAnimating()
                self.membersEmptyLabel.isHidden = false
                self.membersEmptyLabel.text = "Error loading members"
            }
        }
    }
    
    private func loadMemories() async {
        guard let group = group else { return }
        
        do {
            let fetchedMemories = try await SupabaseManager.shared.getGroupMemories(groupId: group.id)
            
            DispatchQueue.main.async {
                self.memories = fetchedMemories
                self.postsCollectionView.reloadData()
                self.memoriesLoadingIndicator.stopAnimating()
                self.memoriesEmptyLabel.isHidden = !self.memories.isEmpty
            }
        } catch {
            print("Error loading memories: \(error)")
            DispatchQueue.main.async {
                self.memoriesLoadingIndicator.stopAnimating()
                self.memoriesEmptyLabel.isHidden = false
                self.memoriesEmptyLabel.text = "Error loading memories"
            }
        }
    }
    
    private func updateUI() {
        // Update empty states
        membersEmptyLabel.isHidden = !members.isEmpty
        memoriesEmptyLabel.isHidden = !memories.isEmpty
        
        // Reload collection views
        membersCollectionView.reloadData()
        postsCollectionView.reloadData()
    }
    
    private func showError(message: String) {
        errorMessage = message
        
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }
    
    // MARK: - Refresh
    @objc private func refreshData() {
        loadGroupData()
    }
    
    // MARK: - Navigation actions
    @IBAction func FamilyMemberPressed(_ sender: UIButton) {
        let familyList = FamilyMemberListViewController(
            nibName: "FamilyMemberListViewController",
            bundle: nil
        )
        familyList.group = group
        navigationController?.pushViewController(
            familyList,
            animated: true
        )
    }
    
    @IBAction func FamilyMemberChevronPressed(_ sender: UIButton) {
        FamilyMemberPressed(sender)
    }
    
    @IBAction func profileButtonPressed(_ sender: UIButton) {
        let vc = AccountModalViewController()
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.selectedDetentIdentifier = .large
        }
        
        present(nav, animated: true)
    }
}

// MARK: - CollectionView DataSource & Delegate
extension FamilyMemberViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        return collectionView == membersCollectionView
            ? members.count
            : memories.count
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        
        if collectionView == membersCollectionView {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "FamilyMemberCell",
                for: indexPath
            ) as! FamilyMemberCollectionViewCell
            
            let member = members[indexPath.item]
            
            // Configure with member data
            // Note: You'll need to add a method to load profile images
            // For now, using placeholder
            cell.configure(
                name: member.name,
                image: UIImage(systemName: "person.circle.fill")?.withTintColor(.systemGray, renderingMode: .alwaysOriginal)
            )
            
            // Add admin badge if needed
            if member.isAdmin {
                // You can add an admin badge overlay here
            }
            
            return cell
        }
        
        // Memory cell
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "FamilyMemoriesCell",
            for: indexPath
        ) as! FamilyMemoriesCollectionViewCell
        
        let memory = memories[indexPath.item]
        
        // Configure with memory data
        cell.configure(
            prompt: memory.title,
            author: memory.userName ?? "Unknown",
            image: nil  // Placeholder - you'll need to load actual images
        )
        
        // Optional: Add content preview
        if let content = memory.content, !content.isEmpty {
            // You could add a subtitle or adjust the prompt label
        }
        
        return cell
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        if collectionView == membersCollectionView {
            let member = members[indexPath.item]
            print("Tapped Member: \(member.name)")
            // You could show member details here if needed
        } else {
            let memory = memories[indexPath.item]
            print("Tapped Memory: \(memory.title)")
            
            // 🚨 CRITICAL FIX: Actually navigate to detail view
            showMemoryDetail(memory: memory)
        }
    }

    // Add this method to show memory detail
    private func showMemoryDetail(memory: GroupMemory) {
        // Fetch media items for this memory
        Task {
            do {
                let mediaItems = try await fetchMediaForMemory(memoryId: memory.id)
                
                DispatchQueue.main.async {
                    print("DEBUG: Passing \(mediaItems.count) media items to detail view")
                    for item in mediaItems {
                        print("  - Type: \(item.mediaType), Content: \(item.textContent ?? "nil")")
                    }
                    
                    let detailVC = GroupMemoryViewController(memory: memory, mediaItems: mediaItems)
                    self.navigationController?.pushViewController(detailVC, animated: true)
                }
            } catch {
                print("Failed to fetch media: \(error)")
                DispatchQueue.main.async {
                    // Show detail view without media if fetch fails
                    let detailVC = GroupMemoryViewController(memory: memory, mediaItems: [])
                    self.navigationController?.pushViewController(detailVC, animated: true)
                }
            }
        }
    }

    // Add this helper method
    private func fetchMediaForMemory(memoryId: String) async throws -> [SupabaseMemoryMedia] {
        let response = try await SupabaseManager.shared.client
            .from("memory_media")
            .select("*")
            .eq("memory_id", value: memoryId)
            .order("sort_order", ascending: true)
            .execute()
        
        return try SupabaseManager.shared.jsonDecoder.decode([SupabaseMemoryMedia].self, from: response.data)
    }
}

// MARK: - UI Updates
extension FamilyMemberViewController {
    private func showLoadingState() {
        membersLoadingIndicator.startAnimating()
        memoriesLoadingIndicator.startAnimating()
        membersEmptyLabel.isHidden = true
        memoriesEmptyLabel.isHidden = true
    }
    
    private func hideLoadingState() {
        membersLoadingIndicator.stopAnimating()
        memoriesLoadingIndicator.stopAnimating()
    }
}
