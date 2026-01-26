//
//  FamilyMemberListViewController.swift
//  Memora
//
//  Created by user@3 on 11/11/25.
//

import UIKit

class FamilyMemberListViewController: UIViewController {
    
    private func isCurrentUserAdmin() -> Bool {
        guard let group = group,
              let currentUserId = SupabaseManager.shared.getCurrentUserId() else {
            return false
        }
        
        print("isCurrentUserAdmin: Checking for user \(currentUserId)")
        print("isCurrentUserAdmin: Group admin ID: \(group.adminId)")
        
        // Check if user is the main admin in groups table
        let isMainAdmin = currentUserId.lowercased() == group.adminId.lowercased()
        print("isCurrentUserAdmin: Is main admin? \(isMainAdmin)")
        
        if isMainAdmin {
            return true
        }
        
        // Check in current members list
        for member in members {
            if member.id.lowercased() == currentUserId.lowercased() {
                print("isCurrentUserAdmin: Found member \(member.name), isAdmin: \(member.isAdmin)")
                return member.isAdmin
            }
        }
        
        print("isCurrentUserAdmin: User not found in members list or not admin")
        return false
    }

    let lightGrey = UIColor(red: 242/255, green: 242/255, blue: 247/255, alpha: 1)
    
    @IBOutlet weak var tableView: UITableView!
    
    var group: UserGroup? // You'll need to pass this from previous screen
    var joinRequests: [JoinRequest] = []
    var members: [GroupMember] = []
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        print("\n=== DEBUG: FamilyMemberListViewController ===")
        print("Is current user admin? \(isCurrentUserAdmin())")
        print("Join requests count: \(joinRequests.count)")
        print("Members count: \(members.count)")
        print("Number of sections in table: \(tableView.numberOfSections)")
        
        for section in 0..<tableView.numberOfSections {
            print("Section \(section) has \(tableView.numberOfRows(inSection: section)) rows")
        }
        
        // Force a reload to ensure everything is fresh
        tableView.reloadData()
        
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("=== FamilyMemberListViewController Debug ===")
        print("Group ID: \(group?.id ?? "No group")")
        print("Group name: \(group?.name ?? "No name")")
        print("Group adminId: \(group?.adminId ?? "No adminId")")
        print("Current user ID: \(SupabaseManager.shared.getCurrentUserId() ?? "No user")")
        
        // Check admin status
        let isAdminByGroupTable = group?.adminId == SupabaseManager.shared.getCurrentUserId()
        print("Is admin by groups table? \(isAdminByGroupTable)")
        
        // Also check case-insensitively
        let currentUserId = SupabaseManager.shared.getCurrentUserId()?.lowercased()
        let groupAdminId = group?.adminId.lowercased()
        let isAdminCaseInsensitive = currentUserId == groupAdminId
        print("Is admin (case-insensitive)? \(isAdminCaseInsensitive)")
        
        // Fetch current group data from database to see actual admin_id
        Task {
            if let groupId = group?.id {
                do {
                    let groupResponse = try await SupabaseManager.shared.client
                        .from("groups")
                        .select("admin_id, created_by, name")
                        .eq("id", value: groupId)
                        .single()
                        .execute()
                    
                    if let json = try JSONSerialization.jsonObject(with: groupResponse.data) as? [String: Any] {
                        print("=== Database Group Info ===")
                        print("Actual admin_id in database: \(json["admin_id"] as? String ?? "No admin_id")")
                        print("Created by: \(json["created_by"] as? String ?? "No created_by")")
                        print("Name: \(json["name"] as? String ?? "No name")")
                        
                        // Check if current user matches
                        if let dbAdminId = json["admin_id"] as? String {
                            let currentUserMatches = dbAdminId.lowercased() == currentUserId?.lowercased()
                            print("Current user matches database admin_id? \(currentUserMatches)")
                        }
                    }
                } catch {
                    print("Error fetching group from database: \(error)")
                }
            }
        }
        
        navigationItem.title = "Family Members"
        
        // NO ADD BUTTON - Remove navigation bar button
        navigationItem.rightBarButtonItem = nil
        
        // Register Member Cell (XIB)
        let memberNib = UINib(nibName: "FamilyMemberListTableViewCell", bundle: nil)
        tableView.register(memberNib, forCellReuseIdentifier: "FamilyMemberListCell")
        
        // Register Join Requests Cell (XIB)
        let requestNib = UINib(nibName: "FamilyMemberRequestsTableViewCell", bundle: nil)
        tableView.register(requestNib, forCellReuseIdentifier: "FamilyMemberRequestsCell")
        
        tableView.dataSource = self
        tableView.delegate = self
        
        tableView.rowHeight = 70
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 72, bottom: 0, right: 16)
        tableView.backgroundColor = lightGrey
        view.backgroundColor = lightGrey
        
        // Add long press gesture
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleMemberLongPress))
        tableView.addGestureRecognizer(longPressGesture)
        
        loadData()
    }

    private func loadData() {
        guard let group = group else {
            print("No group to load data for")
            return
        }
        
        print("=== loadData Debug ===")
        print("Loading data for group: \(group.name) (\(group.id))")
        
        Task {
            do {
                // Check if user is admin - compare case-insensitively
                let currentUserId = SupabaseManager.shared.getCurrentUserId()?.lowercased()
                let groupAdminId = group.adminId.lowercased()
                let isAdmin = currentUserId == groupAdminId
                
                print("Current user ID: \(currentUserId ?? "No user")")
                print("Group admin ID from group object: \(groupAdminId)")
                print("User is admin? \(isAdmin)")
                
                // Load members first to check admin status from group_members
                print("Step 1: Loading members...")
                let fetchedMembers = try await SupabaseManager.shared.getGroupMembers(groupId: group.id)
                print("Loaded \(fetchedMembers.count) members")
                
                // Check if current user is admin in group_members
                var isAdminInMembers = false
                if let currentUserId = currentUserId {
                    for member in fetchedMembers {
                        if member.id.lowercased() == currentUserId {
                            isAdminInMembers = member.isAdmin
                            print("Found current user in members: \(member.name)")
                            print("isAdmin in group_members: \(member.isAdmin)")
                            break
                        }
                    }
                }
                
                print("Current user is admin in group_members? \(isAdminInMembers)")
                print("Overall admin status: \(isAdmin || isAdminInMembers)")
                
                // Only load join requests if user is admin (either in groups table OR group_members)
                if isAdmin || isAdminInMembers {
                    print("Step 2: Loading join requests (user is admin)...")
                    let fetchedRequests = try await SupabaseManager.shared.getPendingJoinRequests(groupId: group.id)
                    print("Loaded \(fetchedRequests.count) join requests")
                    
                    // Update joinRequests on main thread
                    DispatchQueue.main.async {
                        self.joinRequests = fetchedRequests
                        print("Updated joinRequests count: \(self.joinRequests.count)")
                    }
                } else {
                    print("Step 2: Skipping join requests (user is not admin)")
                    DispatchQueue.main.async {
                        self.joinRequests = []
                        print("Set joinRequests to empty")
                    }
                }
                
                // Update everything on main thread
                DispatchQueue.main.async {
                    self.members = fetchedMembers
                    self.tableView.reloadData()
                    
                    print("=== UI Update Complete ===")
                    print("Members count: \(self.members.count)")
                    print("Join requests count: \(self.joinRequests.count)")
                    print("Number of sections in table: \(self.tableView.numberOfSections)")
                    
                    for section in 0..<self.tableView.numberOfSections {
                        print("Section \(section) has \(self.tableView.numberOfRows(inSection: section)) rows")
                    }
                    
                    // Debug: Print all members
                    print("=== All Members ===")
                    for (index, member) in self.members.enumerated() {
                        print("Member \(index): \(member.name) (ID: \(member.id), isAdmin: \(member.isAdmin))")
                    }
                    
                    // Debug: Print all join requests
                    print("=== Join Requests ===")
                    for (index, request) in self.joinRequests.enumerated() {
                        print("Request \(index): \(request.userName ?? "No name") (ID: \(request.userId), Status: \(request.status))")
                    }
                }
            } catch {
                print("Error loading data: \(error)")
                
                // Still reload table to show empty state
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    @objc private func handleMemberLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        
        let touchPoint = gesture.location(in: tableView)
        if let indexPath = tableView.indexPathForRow(at: touchPoint) {
            // Determine which member was long-pressed
            let isAdmin = isCurrentUserAdmin()
            let joinRequestsExist = !joinRequests.isEmpty
            var memberIndex = indexPath.row
            
            // Adjust index based on sections
            if isAdmin && joinRequestsExist {
                if indexPath.section == 1 {
                    memberIndex = indexPath.row
                } else if indexPath.section == 0 {
                    return // This is the join requests cell, not a member
                }
            }
            
            guard memberIndex < members.count else { return }
            let member = members[memberIndex]
            
            // Only show options if current user is admin AND not trying to modify themselves
            guard isAdmin,
                  let currentUserId = SupabaseManager.shared.getCurrentUserId(),
                  member.id.lowercased() != currentUserId.lowercased() else {
                return
            }
            
            showMemberActions(for: member)
        }
    }

    private func showMemberActions(for member: GroupMember) {
        let alert = UIAlertController(
            title: member.name,
            message: member.email,
            preferredStyle: .actionSheet
        )
        
        // Remove member option
        alert.addAction(UIAlertAction(title: "Remove from Group", style: .destructive) { [weak self] _ in
            self?.confirmRemoveMember(member)
        })
        
        // Make admin/remove admin option
        if member.isAdmin {
            alert.addAction(UIAlertAction(title: "Remove as Admin", style: .default) { [weak self] _ in
                self?.confirmUpdateAdminStatus(member: member, makeAdmin: false)
            })
        } else {
            alert.addAction(UIAlertAction(title: "Make Admin", style: .default) { [weak self] _ in
                self?.confirmUpdateAdminStatus(member: member, makeAdmin: true)
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

    private func confirmRemoveMember(_ member: GroupMember) {
        guard let group = group else { return }
        
        let alert = UIAlertController(
            title: "Remove Member",
            message: "Are you sure you want to remove \(member.name) from the group?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Remove", style: .destructive) { [weak self] _ in
            self?.removeMember(member, from: group)
        })
        
        present(alert, animated: true)
    }

    private func removeMember(_ member: GroupMember, from group: UserGroup) {
        let loadingAlert = UIAlertController(title: nil, message: "Removing member...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
        
        Task {
            do {
                try await SupabaseManager.shared.removeGroupMember(groupId: group.id, userId: member.id)
                
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        // Refresh the members list
                        self.loadData()
                        self.showAlert(title: "Success", message: "\(member.name) has been removed from the group")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        self.showAlert(title: "Error", message: "Could not remove member: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func confirmUpdateAdminStatus(member: GroupMember, makeAdmin: Bool) {
        guard let group = group else { return }
        
        let action = makeAdmin ? "make admin" : "remove as admin"
        let alert = UIAlertController(
            title: "\(makeAdmin ? "Make Admin" : "Remove Admin")",
            message: "Are you sure you want to \(action) \(member.name)?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: makeAdmin ? "Make Admin" : "Remove Admin", style: .default) { [weak self] _ in
            self?.updateAdminStatus(member: member, group: group, makeAdmin: makeAdmin)
        })
        
        present(alert, animated: true)
    }

    private func updateAdminStatus(member: GroupMember, group: UserGroup, makeAdmin: Bool) {
        let loadingAlert = UIAlertController(title: nil, message: "Updating admin status...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
        
        Task {
            do {
                try await SupabaseManager.shared.updateGroupAdmin(
                    groupId: group.id,
                    userId: member.id,
                    isAdmin: makeAdmin
                )
                
                // Also update the local group object if making admin
                if makeAdmin {
                    var updatedGroup = group
                    // Create a new group with updated adminId
                    // Note: This is a workaround since UserGroup might be a struct
                    // You might need to use a class or different approach
                }
                
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        // Refresh the members list
                        self.loadData()
                        self.showAlert(title: "Success", message: "Admin status updated for \(member.name)")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        self.showAlert(title: "Error", message: "Could not update admin status: \(error.localizedDescription)")
                    }
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


extension FamilyMemberListViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // If user is admin AND there are join requests, show 2 sections
        // Otherwise show 1 section for members only
        let isAdmin = isCurrentUserAdmin()
        return (isAdmin && !joinRequests.isEmpty) ? 2 : 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let isAdmin = isCurrentUserAdmin()
        
        if section == 0 {
            if isAdmin && !joinRequests.isEmpty {
                return 1 // Join Requests cell
            } else {
                return members.count // Members in section 0 when not admin
            }
        }
        
        // Section 1 (only shown for admins with requests)
        return members.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let isAdmin = isCurrentUserAdmin()
        
        // Join Requests section (only for admins with requests)
        if indexPath.section == 0 && isAdmin && !joinRequests.isEmpty {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: "FamilyMemberRequestsCell",
                for: indexPath
            ) as! FamilyMemberRequestsTableViewCell
            
            if joinRequests.count == 1 {
                let request = joinRequests[0]
                cell.configure(
                    name: "Join Requests",
                    info: request.userName ?? "1 request",
                    image: UIImage(systemName: "person.badge.plus")
                )
            } else if joinRequests.count > 1 {
                cell.configure(
                    name: "Join Requests",
                    info: "\(joinRequests.count) requests",
                    image: UIImage(systemName: "person.badge.plus")
                )
            } else {
                cell.configure(
                    name: "Join Requests",
                    info: "No requests",
                    image: UIImage(systemName: "person.badge.plus")
                )
            }
            
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
            cell.backgroundColor = .white
            cell.contentView.backgroundColor = .white
            
            return cell
        }
        
        // Members section
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "FamilyMemberListCell",
            for: indexPath
        ) as! FamilyMemberListTableViewCell
        
        // Determine which member to show based on section
        let memberIndex: Int
        if isAdmin && !joinRequests.isEmpty {
            // If showing join requests section, members are in section 1
            memberIndex = indexPath.section == 1 ? indexPath.row : indexPath.row
        } else {
            // If not showing join requests, members are in section 0
            memberIndex = indexPath.row
        }
        
        let member = members[memberIndex]
        
        // Check if this member is the current user
        guard let currentUserId = SupabaseManager.shared.getCurrentUserId() else {
            return cell
        }
        
        let isCurrentUser = member.id.lowercased() == currentUserId.lowercased()
        
        // Configure name: add "(you)" if it's the current user
        let memberName = isCurrentUser ? "\(member.name) (you)" : member.name
        cell.textLabel?.text = memberName
        cell.detailTextLabel?.text = member.email
        
        // Create a container view for multiple labels
        let containerView = UIView()
        
        // Add "(you)" label if needed
        if isCurrentUser {
            let youLabel = UILabel()
            youLabel.text = "(you)"
            youLabel.font = UIFont.systemFont(ofSize: 14)
            youLabel.textColor = .systemGray
            youLabel.sizeToFit()
            containerView.addSubview(youLabel)
            
            // Position youLabel
            youLabel.frame.origin = CGPoint(x: 0, y: 0)
        }
        
        // Check if this member is an admin
        // Use member.isAdmin instead of comparing with group.adminId
        if member.isAdmin {
            let adminLabel = UILabel()
            adminLabel.text = "Admin"
            adminLabel.font = UIFont.systemFont(ofSize: 12)
            adminLabel.textColor = .systemBlue
            adminLabel.sizeToFit()
            containerView.addSubview(adminLabel)
            
            // Position adminLabel
            let adminX: CGFloat = isCurrentUser ? 45 : 0 // Offset if "(you)" is present
            adminLabel.frame.origin = CGPoint(x: adminX, y: 0)
            
            // Adjust container width
            containerView.frame.size = CGSize(
                width: adminX + adminLabel.frame.width,
                height: max(20, adminLabel.frame.height)
            )
        } else if isCurrentUser {
            // Only "(you)" label, no admin
            containerView.frame.size = CGSize(width: 35, height: 20)
        }
        
        // Only set accessoryView if we have labels to show
        if containerView.subviews.count > 0 {
            cell.accessoryView = containerView
        } else {
            cell.accessoryView = nil
        }
        
        cell.backgroundColor = lightGrey
        cell.contentView.backgroundColor = lightGrey

        return cell
    }
    
    // ADD SPACING BETWEEN SECTIONS
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let isAdmin = isCurrentUserAdmin()
        
        if isAdmin && !joinRequests.isEmpty {
            // For admins with requests, show header for section 1 (members)
            return section == 1 ? 32 : 0.001
        } else {
            // For non-admins or no requests, show header for section 0
            return section == 0 ? 32 : 0.001
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let isAdmin = isCurrentUserAdmin()
        let showHeaderSection: Int
        
        if isAdmin && !joinRequests.isEmpty {
            showHeaderSection = 1 // Members section
        } else {
            showHeaderSection = 0 // Members section
        }
        
        guard section == showHeaderSection else { return nil }

        let headerView = UIView()
        headerView.backgroundColor = lightGrey

        let titleLabel = UILabel()
        titleLabel.text = "Family Members"
        titleLabel.font = UIFont.preferredFont(forTextStyle: .footnote).bold()
        titleLabel.textColor = .secondaryLabel
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        headerView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: headerView.trailingAnchor, constant: -16),
            titleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -6)
        ])

        return headerView
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let isAdmin = isCurrentUserAdmin()
        
        if indexPath.section == 0 && isAdmin && !joinRequests.isEmpty {
            print("Tapped Join Requests")
            
            DispatchQueue.main.async {
                let familyRequest = FamilyRequestsViewController(nibName: "FamilyRequestsViewController", bundle: nil)
                familyRequest.group = self.group
                self.navigationController?.pushViewController(familyRequest, animated: true)
            }
        } else {
            // For members section, determine which member was tapped
            let memberIndex: Int
            if isAdmin && !joinRequests.isEmpty && indexPath.section == 1 {
                memberIndex = indexPath.row
            } else {
                memberIndex = indexPath.row
            }
            
            let member = members[memberIndex]
            print("Tapped \(member.name)")
        }
    }
}

private extension UIFont {
    func bold() -> UIFont { return withTraits(traits: .traitBold) }
    func withTraits(traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits.union(fontDescriptor.symbolicTraits)) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}


