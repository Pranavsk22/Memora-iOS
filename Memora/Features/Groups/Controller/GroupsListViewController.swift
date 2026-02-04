import UIKit
import Supabase

class GroupsListViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var addGroupButton: UIButton!
    @IBOutlet weak var emptyStateView: UIView!
    @IBOutlet weak var emptyStateLabel: UILabel!
    @IBOutlet weak var emptyStateImage: UIImageView!
    
    private var groups: [UserGroup] = []
    private var refreshControl = UIRefreshControl()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.systemGray6
        setupTableView()
        setupFloatingButton()
        setupEmptyState()
        
        // Add long press gesture for delete/leave
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        tableView.addGestureRecognizer(longPressGesture)
        
        print("\n🚀=== APP STARTED ===🚀")
        print("👤 User ID: \(SupabaseManager.shared.getCurrentUserId() ?? "None")")
        
        // Test connection
        Task {
            let connected = await SupabaseManager.shared.testConnection()
            print("🌐 Supabase connection: \(connected ? "✅ Connected" : "❌ Failed")")
            
            // Load groups
            loadGroups()
        }
        
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(refreshGroups),
                                             name: NSNotification.Name("GroupsListShouldRefresh"),
                                             object: nil)
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        
        let touchPoint = gesture.location(in: tableView)
        if let indexPath = tableView.indexPathForRow(at: touchPoint) {
            let group = groups[indexPath.row]
            showGroupActions(for: group, at: indexPath)
        }
    }

    private func showGroupActions(for group: UserGroup, at indexPath: IndexPath) {
        guard let currentUserId = SupabaseManager.shared.getCurrentUserId() else { return }
        
        let isAdmin = group.adminId == currentUserId
        
        let alert = UIAlertController(
            title: group.name,
            message: "Group Code: \(group.code)",
            preferredStyle: .actionSheet
        )
        
        // Copy Group Code option (available to everyone)
        alert.addAction(UIAlertAction(title: "Copy Group Code", style: .default) { [weak self] _ in
            UIPasteboard.general.string = group.code
            self?.showAlert(title: "Copied", message: "Group code copied to clipboard")
        })
        
        // View Members option (available to everyone)
        alert.addAction(UIAlertAction(title: "View Members", style: .default) { [weak self] _ in
            self?.viewGroupMembers(group: group)
        })
        
        // Share Group Code option (available to everyone)
        alert.addAction(UIAlertAction(title: "Share Group Code", style: .default) { [weak self] _ in
            self?.shareGroupCode(group: group)
        })
        
        if isAdmin {
            // Admin options
            alert.addAction(UIAlertAction(title: "Delete Group", style: .destructive) { [weak self] _ in
                self?.confirmDeleteGroup(group: group, at: indexPath)
            })
            
            // Admin leaving requires special handling
            alert.addAction(UIAlertAction(title: "Leave Group", style: .destructive) { [weak self] _ in
                self?.confirmAdminLeaveGroup(group: group, at: indexPath)
            })
        } else {
            // Member options - simple leave
            alert.addAction(UIAlertAction(title: "Leave Group", style: .destructive) { [weak self] _ in
                self?.confirmLeaveGroup(group: group, at: indexPath)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = tableView.cellForRow(at: indexPath)
            popoverController.sourceRect = tableView.cellForRow(at: indexPath)?.bounds ?? CGRect.zero
        }
        
        present(alert, animated: true)
    }

    private func confirmAdminLeaveGroup(group: UserGroup, at indexPath: IndexPath) {
        // First, check if there are other admins
        let loadingAlert = UIAlertController(title: nil, message: "Checking group members...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
        
        Task {
            do {
                let members = try await SupabaseManager.shared.getGroupMembers(groupId: group.id)
                
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        // Filter out current user and find other admins
                        guard let currentUserId = SupabaseManager.shared.getCurrentUserId() else { return }
                        
                        let otherAdmins = members.filter { member in
                            member.isAdmin && member.id.lowercased() != currentUserId.lowercased()
                        }
                        
                        if otherAdmins.isEmpty {
                            // No other admins - must transfer admin or delete group
                            self.showNoOtherAdminsAlert(group: group, at: indexPath, members: members)
                        } else {
                            // Other admins exist - show list to choose new admin
                            self.showTransferAdminAlert(group: group, at: indexPath, otherAdmins: otherAdmins)
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        self.showAlert(title: "Error", message: "Could not check group members: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func showNoOtherAdminsAlert(group: UserGroup, at indexPath: IndexPath, members: [GroupMember]) {
        guard let currentUserId = SupabaseManager.shared.getCurrentUserId() else { return }
        
        // Filter out current user
        let otherMembers = members.filter { member in
            member.id.lowercased() != currentUserId.lowercased()
        }
        
        if otherMembers.isEmpty {
            // No other members at all - just delete the group
            let alert = UIAlertController(
                title: "Cannot Leave Group",
                message: "You are the only member in this group. You must delete the group instead.",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Delete Group", style: .destructive) { [weak self] _ in
                self?.confirmDeleteGroup(group: group, at: indexPath)
            })
            
            present(alert, animated: true)
        } else {
            // There are other members but no other admins
            let alert = UIAlertController(
                title: "Transfer Admin Role",
                message: "You must transfer the admin role to another member before leaving. Choose a new admin:",
                preferredStyle: .actionSheet
            )
            
            for member in otherMembers {
                alert.addAction(UIAlertAction(title: "\(member.name)", style: .default) { [weak self] _ in
                    self?.transferAdminAndLeave(group: group, newAdmin: member, at: indexPath)
                })
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            // For iPad
            if let popoverController = alert.popoverPresentationController {
                popoverController.sourceView = tableView
                popoverController.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            }
            
            present(alert, animated: true)
        }
    }

    private func showTransferAdminAlert(group: UserGroup, at indexPath: IndexPath, otherAdmins: [GroupMember]) {
        let alert = UIAlertController(
            title: "Transfer Admin Role",
            message: "Choose which admin should take over before you leave:",
            preferredStyle: .actionSheet
        )
        
        for admin in otherAdmins {
            alert.addAction(UIAlertAction(title: "\(admin.name)", style: .default) { [weak self] _ in
                self?.transferAdminAndLeave(group: group, newAdmin: admin, at: indexPath)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = tableView
            popoverController.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        
        present(alert, animated: true)
    }

    private func transferAdminAndLeave(group: UserGroup, newAdmin: GroupMember, at indexPath: IndexPath) {
        let loadingAlert = UIAlertController(title: nil, message: "Transferring admin and leaving...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
        
        Task {
            do {
                // First, update the new admin status in group_members
                try await SupabaseManager.shared.updateGroupAdmin(
                    groupId: group.id,
                    userId: newAdmin.id,
                    isAdmin: true
                )
                
                // Then, update the groups table to set new admin_id
                try await client
                    .from("groups")
                    .update(["admin_id": newAdmin.id])
                    .eq("id", value: group.id)
                    .execute()
                
                // Finally, remove current user from group
                guard let currentUserId = SupabaseManager.shared.getCurrentUserId() else { return }
                try await SupabaseManager.shared.removeGroupMember(
                    groupId: group.id,
                    userId: currentUserId
                )
                
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        // Remove group from list
                        self.groups.remove(at: indexPath.row)
                        self.tableView.deleteRows(at: [indexPath], with: .automatic)
                        self.emptyStateView.isHidden = !self.groups.isEmpty
                        
                        self.showAlert(
                            title: "Success",
                            message: "Admin role transferred to \(newAdmin.name) and you have left the group"
                        )
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        self.showAlert(title: "Error", message: "Could not transfer admin and leave: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // Add client property to GroupsListViewController
    private var client: SupabaseClient {
        return SupabaseManager.shared.client
    }

    private func shareGroupCode(group: UserGroup) {
        let shareText = "Join my group '\(group.name)' on Memora! Group Code: \(group.code)"
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        
        // For iPad
        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = self.view
            popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
        }
        
        present(activityVC, animated: true)
    }

    private func viewGroupMembers(group: UserGroup) {
        let loadingAlert = UIAlertController(title: nil, message: "Loading members...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
        
        Task {
            do {
                let members = try await SupabaseManager.shared.getGroupMembers(groupId: group.id)
                
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        self.showMembersList(group: group, members: members)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        self.showAlert(title: "Error", message: "Could not load members: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func showMembersList(group: UserGroup, members: [GroupMember]) {
        let message = members.map { member in
            "• \(member.name) \(member.isAdmin ? "👑 (Admin)" : "")"
        }.joined(separator: "\n")
        
        let alert = UIAlertController(
            title: "\(group.name) Members",
            message: message.isEmpty ? "No members found" : message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Close", style: .default))
        
        present(alert, animated: true)
    }

    // Update the existing confirmDeleteGroup and confirmLeaveGroup to show loading indicators
    private func confirmDeleteGroup(group: UserGroup, at indexPath: IndexPath) {
        let alert = UIAlertController(
            title: "Delete Group",
            message: "Are you sure you want to delete '\(group.name)'? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteGroup(group: group, at: indexPath)
        })
        
        present(alert, animated: true)
    }

    private func deleteGroup(group: UserGroup, at indexPath: IndexPath) {
        let loadingAlert = UIAlertController(title: nil, message: "Deleting group...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
        
        Task {
            do {
                try await SupabaseManager.shared.deleteGroup(groupId: group.id)
                
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        self.groups.remove(at: indexPath.row)
                        self.tableView.deleteRows(at: [indexPath], with: .automatic)
                        self.emptyStateView.isHidden = !self.groups.isEmpty
                        self.showAlert(title: "Success", message: "Group deleted successfully")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        self.showAlert(title: "Error", message: error.localizedDescription)
                    }
                }
            }
        }
    }

    private func confirmLeaveGroup(group: UserGroup, at indexPath: IndexPath) {
        let alert = UIAlertController(
            title: "Leave Group",
            message: "Are you sure you want to leave '\(group.name)'?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Leave", style: .destructive) { [weak self] _ in
            self?.leaveGroup(group: group, at: indexPath)
        })
        
        present(alert, animated: true)
    }

    private func leaveGroup(group: UserGroup, at indexPath: IndexPath) {
        guard let userId = SupabaseManager.shared.getCurrentUserId() else { return }
        
        let loadingAlert = UIAlertController(title: nil, message: "Leaving group...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
        
        Task {
            do {
                try await SupabaseManager.shared.removeGroupMember(groupId: group.id, userId: userId)
                
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        self.groups.remove(at: indexPath.row)
                        self.tableView.deleteRows(at: [indexPath], with: .automatic)
                        self.emptyStateView.isHidden = !self.groups.isEmpty
                        self.showAlert(title: "Success", message: "Left group successfully")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        self.showAlert(title: "Error", message: error.localizedDescription)
                    }
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // load groups normally
        loadGroups()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Ensure button stays circular after layout changes
        addGroupButton.layer.cornerRadius = addGroupButton.frame.width / 2
    }
    
    private func setupTableView() {
        let nib = UINib(nibName: "GroupsTableViewCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "GroupCell")
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.rowHeight = 84
        
        // Add refresh control
        refreshControl.addTarget(self, action: #selector(refreshGroups), for: .valueChanged)
        refreshControl.tintColor = .systemBlue
        tableView.refreshControl = refreshControl
    }
    
    private func setupFloatingButton() {
        // Set button to perfect circle
        addGroupButton.layer.cornerRadius = addGroupButton.frame.width / 2
        addGroupButton.clipsToBounds = true
        addGroupButton.backgroundColor = .systemBlue
        
        // Configure plus icon
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        let plusImage = UIImage(systemName: "plus", withConfiguration: config)
        addGroupButton.setImage(plusImage, for: .normal)
        addGroupButton.tintColor = .white
        
        // Shadow
        addGroupButton.layer.shadowColor = UIColor.black.cgColor
        addGroupButton.layer.shadowOpacity = 0.3
        addGroupButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        addGroupButton.layer.shadowRadius = 8
        addGroupButton.layer.masksToBounds = false
        
        // Ensure button is on top
        addGroupButton.layer.zPosition = 1000
    }
    
    private func setupEmptyState() {
        emptyStateView.isHidden = true
        emptyStateImage.image = UIImage(systemName: "person.3.fill")
        emptyStateImage.tintColor = .systemGray3
        emptyStateLabel.text = "No groups yet\nCreate or join a group to get started"
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0
    }
    
    @objc private func debugButtonPress() {
        print("DEBUG: Button pressed at \(Date())")
    }
    
    @objc private func refreshGroups() {
        loadGroups()
    }
    
    private func loadGroups() {
        print("📱 Loading groups...")
        
        Task {
            do {
                let fetchedGroups = try await SupabaseManager.shared.getMyGroups()
                print("📱 Successfully loaded \(fetchedGroups.count) groups")
                
                DispatchQueue.main.async {
                    self.groups = fetchedGroups
                    self.tableView.reloadData()
                    self.refreshControl.endRefreshing()
                    self.emptyStateView.isHidden = !self.groups.isEmpty
                    
                    // Print all groups
                    for (index, group) in self.groups.enumerated() {
                        print("📱 Group \(index + 1): \(group.name) (\(group.code))")
                    }
                    
                    // Show success message if we have groups
                    if !self.groups.isEmpty {
                        let groupNames = self.groups.map { $0.name }.joined(separator: ", ")
                        print("📱 Showing groups: \(groupNames)")
                    }
                }
            } catch {
                print("❌ Error in loadGroups: \(error)")
                DispatchQueue.main.async {
                    self.refreshControl.endRefreshing()
                    
                    // Even on error, show demo groups
                    let demoGroups = SupabaseManager.shared.getDemoGroups()
                    self.groups = demoGroups
                    self.tableView.reloadData()
                    self.emptyStateView.isHidden = true
                    
                    print("📱 Showing demo groups due to error")
                }
            }
        }
    }
    
    @IBAction func addGroupPressed(_ sender: UIButton) {
        print("addGroupPressed called - showing action sheet")
        
        // Create and present the action sheet
        let actionSheet = GroupActionSheetViewController()
        actionSheet.delegate = self
        
        // IMPORTANT: Use overFullScreen to cover everything including tab bar
        actionSheet.modalPresentationStyle = .overFullScreen
        actionSheet.modalTransitionStyle = .crossDissolve
        
        // Present from self (since we're in a tab controller)
        self.present(actionSheet, animated: true) {
            print("Action sheet presented successfully")
        }
    }
    
    // Helper to get topmost view controller
    private func getTopViewController() -> UIViewController? {
        var topController: UIViewController? = self
        
        while let presentedViewController = topController?.presentedViewController {
            topController = presentedViewController
        }
        
        // If we're in a tab bar controller, return self
        if topController != self {
            return topController
        }
        return self
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - TableView DataSource & Delegate
extension GroupsListViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groups.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "GroupCell",
            for: indexPath
        ) as! GroupsTableViewCell
        
        let group = groups[indexPath.row]
        
        // Check if current user is admin
        let isAdmin = group.adminId == SupabaseManager.shared.getCurrentUserId()
        
        // Configure cell with admin badge if user is admin
        cell.configure(
            title: group.name,
            subtitle: "Code: \(group.code)",
//            image: UIImage(named: "group_family"), // Use appropriate image
            isAdmin: isAdmin
        )
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let group = groups[indexPath.row]
        print("Selected group: \(group.name), ID: \(group.id)")
        
        // Navigate to FamilyMemberViewController
        let familyVC = FamilyMemberViewController(nibName: "FamilyMemberViewController", bundle: nil)
        familyVC.group = group // Pass the group
        navigationController?.pushViewController(familyVC, animated: true)
    }
    
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let group = groups[indexPath.row]
        
        // Only allow admin to delete group
        if group.adminId == SupabaseManager.shared.getCurrentUserId() {
            let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
                self?.confirmDeleteGroup(group: group, at: indexPath)
                completion(true)
            }
            deleteAction.backgroundColor = .systemRed
            
            return UISwipeActionsConfiguration(actions: [deleteAction])
        }
        
        let leaveAction = UIContextualAction(style: .destructive, title: "Leave") { [weak self] _, _, completion in
            self?.confirmLeaveGroup(group: group, at: indexPath)
            completion(true)
        }
        leaveAction.backgroundColor = .systemOrange
        
        return UISwipeActionsConfiguration(actions: [leaveAction])
    }
    

}

// MARK: - GroupActionSheetDelegate
extension GroupsListViewController: GroupActionSheetDelegate {
    func didSelectCreateGroup() {
        print("Create group selected")
        let createVC = CreateGroupViewController(nibName: "CreateGroupViewController", bundle: nil)
        createVC.delegate = self  // Add this line
        let nav = UINavigationController(rootViewController: createVC)
        nav.modalPresentationStyle = .pageSheet
        
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        
        present(nav, animated: true)
    }

    
    func didSelectJoinGroup() {
        print("Join group selected")
        let joinVC = JoinGroupModalViewController(nibName: "JoinGroupModalViewController", bundle: nil)
        joinVC.delegate = self  // Add this line
        let nav = UINavigationController(rootViewController: joinVC)
        nav.modalPresentationStyle = .pageSheet
        
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        
        present(nav, animated: true)
    }
}



// MARK: - CreateGroupDelegate
extension GroupsListViewController: CreateGroupDelegate {
    func didCreateGroupSuccessfully() {
        print("Group created successfully, refreshing list...")
        // Refresh after a short delay to ensure data is saved
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadGroups()
        }
    }
}

// MARK: - JoinGroupDelegate
extension GroupsListViewController: JoinGroupDelegate {
    func didJoinGroupSuccessfully() {
        print("Group joined successfully, refreshing list...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadGroups()
        }
    }
    
    func didSendJoinRequest() {
        print("Join request sent successfully, showing confirmation...")
        // You might want to show a confirmation alert
        showAlert(title: "Request Sent", message: "Your join request has been sent to the group admin for approval.")
    }
}


// In CreateGroupViewController, call delegate when group is created
