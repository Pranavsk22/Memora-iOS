//
//  GroupMembersManagementViewController.swift
//  Memora
//
//  Created by user@3 on 10/01/26.
//


import UIKit

class GroupMembersManagementViewController: UIViewController {
    
    private let group: UserGroup
    private var members: [GroupMember]
    
    private let tableView = UITableView(frame: .zero, style: .grouped)
    
    init(group: UserGroup, members: [GroupMember]) {
        self.group = group
        self.members = members
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Manage Members"
        view.backgroundColor = .systemGroupedBackground
        
        setupNavigationBar()
        setupTableView()
    }
    
    private func setupNavigationBar() {
        // Add invite button
        let inviteButton = UIBarButtonItem(image: UIImage(systemName: "person.badge.plus"),
                                          style: .plain,
                                          target: self,
                                          action: #selector(inviteTapped))
        navigationItem.rightBarButtonItem = inviteButton
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
        tableView.register(GroupManagementMemberCell.self, forCellReuseIdentifier: "GroupManagementMemberCell")
        tableView.separatorStyle = .singleLine
    }
    
    @objc private func inviteTapped() {
        let alert = UIAlertController(
            title: "Invite to Group",
            message: "Share this code with others to join: \(group.code)",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Copy Code", style: .default) { _ in
            UIPasteboard.general.string = self.group.code
        })
        
        alert.addAction(UIAlertAction(title: "Share", style: .default) { _ in
            self.shareGroupCode()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func shareGroupCode() {
        let text = "Join my group '\(group.name)' on Memora!\n\nUse code: \(group.code)"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        present(activityVC, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableView DataSource & Delegate
extension GroupMembersManagementViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return members.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "GroupManagementMemberCell", for: indexPath) as! GroupManagementMemberCell
        let member = members[indexPath.row]
        
        // Check if current user is admin and can manage
        let isCurrentUserAdmin = group.adminId == SupabaseManager.shared.getCurrentUserId()
        let isCurrentUser = member.id == SupabaseManager.shared.getCurrentUserId()
        
        cell.configure(
            member: member,
            canManage: isCurrentUserAdmin && !isCurrentUser, // Can't remove yourself
            isAdmin: member.isAdmin
        )
        
        cell.removeAction = { [weak self] in
            self?.confirmRemoveMember(member: member, at: indexPath)
        }
        
        cell.makeAdminAction = { [weak self] in
            self?.confirmMakeAdmin(member: member)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Group Members (\(members.count))"
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
    
    private func confirmRemoveMember(member: GroupMember, at indexPath: IndexPath) {
        let alert = UIAlertController(
            title: "Remove Member",
            message: "Are you sure you want to remove \(member.name) from the group?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Remove", style: .destructive) { [weak self] _ in
            self?.removeMember(member: member, at: indexPath)
        })
        
        present(alert, animated: true)
    }
    
    private func removeMember(member: GroupMember, at indexPath: IndexPath) {
        Task {
            do {
                try await SupabaseManager.shared.removeGroupMember(groupId: group.id, userId: member.id)
                
                DispatchQueue.main.async {
                    self.members.remove(at: indexPath.row)
                    self.tableView.deleteRows(at: [indexPath], with: .automatic)
                }
            } catch {
                DispatchQueue.main.async {
                    self.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func confirmMakeAdmin(member: GroupMember) {
        let alert = UIAlertController(
            title: "Make Admin",
            message: "Are you sure you want to make \(member.name) an admin?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Make Admin", style: .default) { [weak self] _ in
            self?.makeAdmin(member: member)
        })
        
        present(alert, animated: true)
    }
    
    private func makeAdmin(member: GroupMember) {
        Task {
            do {
                try await SupabaseManager.shared.updateGroupAdmin(groupId: group.id, userId: member.id, isAdmin: true)
                
                DispatchQueue.main.async {
                    // Update local data
                    if let index = self.members.firstIndex(where: { $0.id == member.id }) {
                        self.members[index] = GroupMember(
                            id: member.id,
                            name: member.name,
                            email: member.email,
                            isAdmin: true,
                            joinedAt: member.joinedAt
                        )
                        self.tableView.reloadData()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Custom Cell for Member Management
class GroupManagementMemberCell: UITableViewCell {
    
    private let nameLabel = UILabel()
    private let emailLabel = UILabel()
    private let adminBadge = UILabel()
    private let removeButton = UIButton(type: .system)
    private let makeAdminButton = UIButton(type: .system)
    
    var removeAction: (() -> Void)?
    var makeAdminAction: (() -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Name label
        nameLabel.font = .systemFont(ofSize: 16, weight: .medium)
        
        // Email label
        emailLabel.font = .systemFont(ofSize: 14)
        emailLabel.textColor = .secondaryLabel
        
        // Admin badge
        adminBadge.font = .systemFont(ofSize: 12, weight: .semibold)
        adminBadge.textColor = .systemBlue
        adminBadge.text = "Admin"
        adminBadge.textAlignment = .center
        adminBadge.layer.cornerRadius = 4
        adminBadge.layer.borderWidth = 1
        adminBadge.layer.borderColor = UIColor.systemBlue.cgColor
        adminBadge.clipsToBounds = true
        adminBadge.isHidden = true
        
        // Remove button
        removeButton.setTitle("Remove", for: .normal)
        removeButton.setTitleColor(.systemRed, for: .normal)
        removeButton.titleLabel?.font = .systemFont(ofSize: 14)
        removeButton.addTarget(self, action: #selector(removeTapped), for: .touchUpInside)
        removeButton.isHidden = true
        
        // Make admin button
        makeAdminButton.setTitle("Make Admin", for: .normal)
        makeAdminButton.setTitleColor(.systemBlue, for: .normal)
        makeAdminButton.titleLabel?.font = .systemFont(ofSize: 14)
        makeAdminButton.addTarget(self, action: #selector(makeAdminTapped), for: .touchUpInside)
        makeAdminButton.isHidden = true
        
        contentView.addSubview(nameLabel)
        contentView.addSubview(emailLabel)
        contentView.addSubview(adminBadge)
        contentView.addSubview(removeButton)
        contentView.addSubview(makeAdminButton)
        
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        emailLabel.translatesAutoresizingMaskIntoConstraints = false
        adminBadge.translatesAutoresizingMaskIntoConstraints = false
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        makeAdminButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            emailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            emailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            emailLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
            adminBadge.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            adminBadge.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            adminBadge.widthAnchor.constraint(equalToConstant: 50),
            adminBadge.heightAnchor.constraint(equalToConstant: 20),
            
            makeAdminButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            makeAdminButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            removeButton.trailingAnchor.constraint(equalTo: makeAdminButton.leadingAnchor, constant: -12),
            removeButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    func configure(member: GroupMember, canManage: Bool, isAdmin: Bool) {
        nameLabel.text = member.name
        emailLabel.text = member.email
        adminBadge.isHidden = !isAdmin
        
        // Show/hide management buttons
        removeButton.isHidden = !canManage
        makeAdminButton.isHidden = !canManage || isAdmin
    }
    
    @objc private func removeTapped() {
        removeAction?()
    }
    
    @objc private func makeAdminTapped() {
        makeAdminAction?()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        removeAction = nil
        makeAdminAction = nil
        adminBadge.isHidden = true
        removeButton.isHidden = true
        makeAdminButton.isHidden = true
    }
}
