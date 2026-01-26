//
//  GroupDetailViewController.swift
//  Memora
//
//  Created by user@3 on 10/01/26.
//


import UIKit

class GroupDetailViewController: UIViewController {
    
    private let group: UserGroup
    private var members: [GroupMember] = []
    private var memories: [GroupMemory] = []
    
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let refreshControl = UIRefreshControl()
    
    init(group: UserGroup) {
        self.group = group
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = group.name
        view.backgroundColor = .systemGroupedBackground
        
        setupNavigationBar()
        setupTableView()
        loadData()
    }
    
    private func setupNavigationBar() {
        // Add share button
        let shareButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"),
                                         style: .plain,
                                         target: self,
                                         action: #selector(shareGroupTapped))
        
        // Add settings button for admin
        if group.adminId == SupabaseManager.shared.getCurrentUserId() {
            let settingsButton = UIBarButtonItem(image: UIImage(systemName: "gearshape"),
                                                style: .plain,
                                                target: self,
                                                action: #selector(settingsTapped))
            navigationItem.rightBarButtonItems = [settingsButton, shareButton]
        } else {
            navigationItem.rightBarButtonItem = shareButton
        }
    }
    
    private func setupTableView() {
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(GroupMemberCell.self, forCellReuseIdentifier: "GroupMemberCell")
        tableView.register(GroupMemoryCell.self, forCellReuseIdentifier: "GroupMemoryCell")
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        
        // Add refresh control
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }
    
    private func loadData() {
        Task {
            do {
                async let membersTask = SupabaseManager.shared.getGroupMembers(groupId: group.id)
                // async let memoriesTask = SupabaseManager.shared.getGroupMemories(groupId: group.id)
                
                let fetchedMembers = try await membersTask
                // let fetchedMemories = try await memoriesTask
                
                DispatchQueue.main.async {
                    self.members = fetchedMembers
                    // self.memories = fetchedMemories
                    self.tableView.reloadData()
                    self.refreshControl.endRefreshing()
                }
            } catch {
                DispatchQueue.main.async {
                    self.refreshControl.endRefreshing()
                    self.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func refreshData() {
        loadData()
    }
    
    @objc private func shareGroupTapped() {
        let text = "Join my group '\(group.name)' on Memora!\n\nUse code: \(group.code)"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        present(activityVC, animated: true)
    }
    
    @objc private func settingsTapped() {
        let alert = UIAlertController(title: "Group Settings", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Manage Members", style: .default) { _ in
            self.showMembersManagement()
        })
        
        alert.addAction(UIAlertAction(title: "Change Group Name", style: .default) { _ in
            self.showRenameGroup()
        })
        
        alert.addAction(UIAlertAction(title: "Delete Group", style: .destructive) { _ in
            self.confirmDeleteGroup()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showMembersManagement() {
        let vc = GroupMembersManagementViewController(group: group, members: members)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func showRenameGroup() {
        let alert = UIAlertController(title: "Rename Group", message: nil, preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "New group name"
            textField.text = self.group.name
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Rename", style: .default) { _ in
            if let newName = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
               !newName.isEmpty {
                self.renameGroup(to: newName)
            }
        })
        
        present(alert, animated: true)
    }
    
    private func renameGroup(to newName: String) {
        // Implement rename functionality
        print("Rename group to: \(newName)")
    }
    
    private func confirmDeleteGroup() {
        let alert = UIAlertController(
            title: "Delete Group",
            message: "Are you sure you want to delete '\(group.name)'? All memories will be lost.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.deleteGroup()
        })
        
        present(alert, animated: true)
    }
    
    private func deleteGroup() {
        Task {
            do {
                try await SupabaseManager.shared.deleteGroup(groupId: group.id)
                
                DispatchQueue.main.async {
                    // Go back to groups list
                    self.navigationController?.popViewController(animated: true)
                    NotificationCenter.default.post(name: NSNotification.Name("GroupsListShouldRefresh"), object: nil)
                }
            } catch {
                DispatchQueue.main.async {
                    self.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableView DataSource & Delegate
extension GroupDetailViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2 // Members section, Memories section
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? min(members.count, 5) : memories.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "GroupMemberCell", for: indexPath) as! GroupMemberCell
            let member = members[indexPath.row]
            cell.configure(member: member)
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "GroupMemoryCell", for: indexPath) as! GroupMemoryCell
            let memory = memories[indexPath.row]
            cell.configure(memory: memory)
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Members" : "Shared Memories"
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.section == 0 ? 60 : 100
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 {
            // Show all members if tapped
            if members.count > 5 {
                showMembersManagement()
            }
        } else {
            // Show memory detail
            let memory = memories[indexPath.row]
            // Navigate to memory detail view
        }
    }
}

// MARK: - Custom Cells
class GroupMemberCell: UITableViewCell {
    
    private let nameLabel = UILabel()
    private let adminLabel = UILabel()
    private let profileImage = UIImageView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        profileImage.layer.cornerRadius = 20
        profileImage.clipsToBounds = true
        profileImage.backgroundColor = .systemGray5
        profileImage.image = UIImage(systemName: "person.circle.fill")
        profileImage.tintColor = .systemGray
        
        nameLabel.font = .systemFont(ofSize: 16, weight: .medium)
        
        adminLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        adminLabel.textColor = .systemBlue
        adminLabel.text = "Admin"
        adminLabel.isHidden = true
        
        contentView.addSubview(profileImage)
        contentView.addSubview(nameLabel)
        contentView.addSubview(adminLabel)
        
        profileImage.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        adminLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            profileImage.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            profileImage.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            profileImage.widthAnchor.constraint(equalToConstant: 40),
            profileImage.heightAnchor.constraint(equalToConstant: 40),
            
            nameLabel.leadingAnchor.constraint(equalTo: profileImage.trailingAnchor, constant: 12),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            adminLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            adminLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    func configure(member: GroupMember) {
        nameLabel.text = member.name
        adminLabel.isHidden = !member.isAdmin
    }
}

class GroupMemoryCell: UITableViewCell {
    
    private let titleLabel = UILabel()
    private let authorLabel = UILabel()
    private let dateLabel = UILabel()
    private let menuButton = UIButton(type: .system)
    
    var menuAction: (() -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.numberOfLines = 1
        
        authorLabel.font = .systemFont(ofSize: 14)
        authorLabel.textColor = .secondaryLabel
        
        dateLabel.font = .systemFont(ofSize: 12)
        dateLabel.textColor = .tertiaryLabel
        
        menuButton.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        menuButton.tintColor = .systemGray
        menuButton.addTarget(self, action: #selector(menuButtonTapped), for: .touchUpInside)
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(authorLabel)
        contentView.addSubview(dateLabel)
        contentView.addSubview(menuButton)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        authorLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: menuButton.leadingAnchor, constant: -8),
            
            authorLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            authorLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            
            dateLabel.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: 4),
            dateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            dateLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
            menuButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            menuButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            menuButton.widthAnchor.constraint(equalToConstant: 24),
            menuButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    @objc private func menuButtonTapped() {
        menuAction?()
    }
    
    func configure(memory: GroupMemory) {
        titleLabel.text = memory.title
        authorLabel.text = "By \(memory.userName ?? "Unknown")"
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        dateLabel.text = formatter.string(from: memory.createdAt)
    }
}
