//
//  MultipleGroupsSelectionViewController.swift
//  Memora
//
//  Created by user@3 on 04/02/26.
//


import UIKit

class MultipleGroupsSelectionViewController: UITableViewController {
    
    // MARK: - Properties
    var userGroups: [UserGroup] = []
    var selectedGroups: [UserGroup] = []
    var onSelectionComplete: (([UserGroup]) -> Void)?
    
    private let searchController = UISearchController(searchResultsController: nil)
    private var filteredGroups: [UserGroup] = []
    private var isSearching: Bool {
        return searchController.isActive && !(searchController.searchBar.text?.isEmpty ?? true)
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupSearchController()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = false
    }
    
    // MARK: - Setup
    private func setupUI() {
        title = "Select Groups"
        view.backgroundColor = .systemBackground
        
        // Configure navigation
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Done",
            style: .done,
            target: self,
            action: #selector(doneTapped)
        )
        
        // Configure table view
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "GroupCell")
        tableView.separatorStyle = .singleLine
        tableView.tableFooterView = UIView()
        
        // Show message if no groups
        if userGroups.isEmpty {
            showEmptyState()
        }
    }
    
    private func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search groups..."
        searchController.searchBar.tintColor = .systemBlue
        searchController.searchBar.searchTextField.backgroundColor = .secondarySystemBackground
        
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }
    
    private func showEmptyState() {
        let emptyView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 300))
        
        let imageView = UIImageView(image: UIImage(systemName: "person.3"))
        imageView.tintColor = .systemGray3
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "No Groups Available"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let messageLabel = UILabel()
        messageLabel.text = "Create or join a group first to share memories."
        messageLabel.font = UIFont.systemFont(ofSize: 15)
        messageLabel.textColor = .tertiaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        emptyView.addSubview(imageView)
        emptyView.addSubview(titleLabel)
        emptyView.addSubview(messageLabel)
        
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: emptyView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: emptyView.centerYAnchor, constant: -40),
            imageView.widthAnchor.constraint(equalToConstant: 80),
            imageView.heightAnchor.constraint(equalToConstant: 80),
            
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: emptyView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: emptyView.trailingAnchor, constant: -20),
            
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: emptyView.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: emptyView.trailingAnchor, constant: -20)
        ])
        
        tableView.backgroundView = emptyView
        tableView.separatorStyle = .none
    }
    
    private func hideEmptyState() {
        tableView.backgroundView = nil
        tableView.separatorStyle = .singleLine
    }
    
    // MARK: - Actions
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func doneTapped() {
        onSelectionComplete?(selectedGroups)
        dismiss(animated: true)
    }
    
    // MARK: - Helper Methods
    private func groupsToDisplay() -> [UserGroup] {
        return isSearching ? filteredGroups : userGroups
    }
    
    private func isGroupSelected(_ group: UserGroup) -> Bool {
        return selectedGroups.contains(where: { $0.id == group.id })
    }
    
    private func toggleGroupSelection(_ group: UserGroup) {
        if let index = selectedGroups.firstIndex(where: { $0.id == group.id }) {
            selectedGroups.remove(at: index)
        } else {
            selectedGroups.append(group)
        }
        
        // Update navigation title with count
        updateNavigationTitle()
    }
    
    private func updateNavigationTitle() {
        if selectedGroups.isEmpty {
            navigationItem.title = "Select Groups"
        } else {
            navigationItem.title = "Selected: \(selectedGroups.count)"
        }
    }
    
    // MARK: - Table View Data Source
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = groupsToDisplay().count
        if count == 0 && !isSearching {
            showEmptyState()
        } else {
            hideEmptyState()
        }
        return count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "GroupCell", for: indexPath)
        let groups = groupsToDisplay()
        guard indexPath.row < groups.count else { return cell }
        
        let group = groups[indexPath.row]
        
        // Configure cell
        cell.textLabel?.text = group.name
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16)
        
        // Show checkmark if selected
        cell.accessoryType = isGroupSelected(group) ? .checkmark : .none
        
        // Add admin indicator if user is admin
        if let currentUserId = SupabaseManager.shared.getCurrentUserId(),
           group.adminId == currentUserId {
            let adminLabel = UILabel()
            adminLabel.text = "Admin"
            adminLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
            adminLabel.textColor = .systemBlue
            adminLabel.sizeToFit()
            cell.accessoryView = adminLabel
        } else {
            cell.accessoryView = nil
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let groups = groupsToDisplay()
        guard indexPath.row < groups.count else { return }
        
        let group = groups[indexPath.row]
        toggleGroupSelection(group)
        
        // Update the cell
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 56
    }
    
    // MARK: - Search
    private func filterGroups(for searchText: String) {
        if searchText.isEmpty {
            filteredGroups = userGroups
        } else {
            filteredGroups = userGroups.filter { group in
                group.name.lowercased().contains(searchText.lowercased())
            }
        }
        tableView.reloadData()
    }
}

// MARK: - UISearchResultsUpdating
extension MultipleGroupsSelectionViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        filterGroups(for: searchController.searchBar.text ?? "")
    }
}
