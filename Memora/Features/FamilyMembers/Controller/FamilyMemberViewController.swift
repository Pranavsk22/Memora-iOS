//
//  FamilyMemberViewController.swift
//  Memora
//
//  Created by user@3 on 10/11/25.
//

import UIKit

class FamilyMemberViewController: UIViewController {
    override func loadView() {
        // Prevent automatic XIB loading
        view = UIView()
    }
    // Prevent storyboard/XIB leftover IBOutlet crash
    override func setValue(_ value: Any?, forUndefinedKey key: String) {
        print("Ignored undefined key: \(key)")
    }
    
    var group: UserGroup?
    
    // MARK: - Data Properties
    private var members: [GroupMember] = []
    private var memories: [GroupMemory] = []
    private var isLoading = false
    private var errorMessage: String?
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private var postsHeightConstraint: NSLayoutConstraint?
    private let membersCollectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
    private let postsCollectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
    private let membersHeaderButton = UIButton(type: .system)
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = group?.name ?? "Family"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
        
        setupUI()
        setupCollections()
        
        // Load data if we have a group
        if let group = group {
            loadGroupData()
        } else {
            showError(message: "No group information available")
        }
    }
    
    // Dynamic height update for postsCollectionView and profile button styling
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        postsCollectionView.layoutIfNeeded()

        if let layout = postsCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let width = contentView.bounds.width - 32
            if width > 0 {
                layout.itemSize = CGSize(width: width, height: 300)
                layout.invalidateLayout()
            }
        }

        let height = postsCollectionView.collectionViewLayout.collectionViewContentSize.height
        postsHeightConstraint?.constant = max(height, 1)
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false

        contentView.translatesAutoresizingMaskIntoConstraints = false

        membersCollectionView.translatesAutoresizingMaskIntoConstraints = false
        postsCollectionView.translatesAutoresizingMaskIntoConstraints = false

        membersCollectionView.isScrollEnabled = true
        postsCollectionView.isScrollEnabled = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(membersHeaderButton)
        contentView.addSubview(membersCollectionView)
        contentView.addSubview(postsCollectionView)

        membersHeaderButton.translatesAutoresizingMaskIntoConstraints = false
        membersHeaderButton.setTitle("Family Members  >", for: .normal)
        membersHeaderButton.setTitleColor(.label, for: .normal)
        membersHeaderButton.titleLabel?.font = .systemFont(ofSize: 22, weight: .bold)
        membersHeaderButton.contentHorizontalAlignment = .left
        membersHeaderButton.addTarget(self, action: #selector(FamilyMemberPressed(_:)), for: .touchUpInside)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            membersHeaderButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            membersHeaderButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            membersHeaderButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            membersHeaderButton.heightAnchor.constraint(equalToConstant: 30),

            membersCollectionView.topAnchor.constraint(equalTo: membersHeaderButton.bottomAnchor, constant: 16),
            membersCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            membersCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            membersCollectionView.heightAnchor.constraint(equalToConstant: 180),

            postsCollectionView.topAnchor.constraint(equalTo: membersCollectionView.bottomAnchor, constant: 24),
            postsCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            postsCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            postsCollectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])

        postsHeightConstraint = postsCollectionView.heightAnchor.constraint(equalToConstant: 300)
        postsHeightConstraint?.isActive = true
    }
    
    private func setupCollections() {
        // Members Collection
        membersCollectionView.register(
            FamilyMemberCollectionViewCell.self,
            forCellWithReuseIdentifier: "FamilyMemberCell"
        )
        membersCollectionView.delegate = self
        membersCollectionView.dataSource = self
        membersCollectionView.backgroundColor = .clear
        membersCollectionView.showsHorizontalScrollIndicator = false

        if let layout = membersCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .horizontal
            layout.itemSize = CGSize(width: 120, height: 160)
            layout.minimumLineSpacing = 16
            layout.sectionInset = UIEdgeInsets(
                top: 0,
                left: 16,
                bottom: 0,
                right: 16
            )
        }

        // Posts Collection
        postsCollectionView.register(
            FamilyMemoriesCollectionViewCell.self,
            forCellWithReuseIdentifier: "FamilyMemoriesCell"
        )
        postsCollectionView.delegate = self
        postsCollectionView.dataSource = self
        postsCollectionView.backgroundColor = .clear
        postsCollectionView.showsVerticalScrollIndicator = false
        postsCollectionView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 32, right: 0)
        // postsCollectionView.alwaysBounceVertical = true   // REMOVE

        if let layout = postsCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .vertical
            layout.minimumLineSpacing = 24
            layout.sectionInset = UIEdgeInsets(
                top: 0,
                left: 16,
                bottom: 16,
                right: 16
            )
        }
    }
    
    // MARK: - Data Loading
    private func loadGroupData() {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Show loading states
        
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
            }
        } catch {
            print("Error loading members: \(error)")
            DispatchQueue.main.async {
                // Handle error UI if desired
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
                self.postsCollectionView.layoutIfNeeded()
                let height = self.postsCollectionView.collectionViewLayout.collectionViewContentSize.height
                self.postsHeightConstraint?.constant = max(height, 1)
            }
        } catch {
            print("Error loading memories: \(error)")
            DispatchQueue.main.async {
                // Handle error UI if desired
            }
        }
    }
    
    private func updateUI() {
        // Reload collection views
        membersCollectionView.reloadData()
        postsCollectionView.reloadData()
        postsCollectionView.layoutIfNeeded()
        let height = postsCollectionView.collectionViewLayout.collectionViewContentSize.height
        postsHeightConstraint?.constant = max(height, 1)
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
    @objc func FamilyMemberPressed(_ sender: UIButton) {
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
    
    @objc func FamilyMemberChevronPressed(_ sender: UIButton) {
        FamilyMemberPressed(sender)
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
            imageURL: nil
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
    
    func collectionView(_ collectionView: UICollectionView,
                        didHighlightItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath) {
            UIView.animate(withDuration: 0.15) {
                cell.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        didUnhighlightItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath) {
            UIView.animate(withDuration: 0.15) {
                cell.transform = .identity
            }
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

