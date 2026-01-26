//
//  FamilyRequestsViewController.swift
//  Memora
//
//  Created by user@3 on 12/11/25.
//

import UIKit

class FamilyRequestsViewController: UIViewController {

    private let tableView = UITableView()
    var group: UserGroup?
    var requests: [JoinRequest] = []
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(red: 242/255, green: 242/255, blue: 247/255, alpha: 1)

        self.title = "Join Requests"
        
        setupTableView()
        loadRequests()
    }
    
    private func loadRequests() {
        guard let group = group else {
            print("No group provided to FamilyRequestsViewController")
            return
        }
        
        print("Loading requests for group: \(group.name) (\(group.id))")
        
        let loadingAlert = UIAlertController(title: nil, message: "Loading requests...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
        
        Task {
            do {
                requests = try await SupabaseManager.shared.getPendingJoinRequests(groupId: group.id)
                print("Loaded \(requests.count) requests in FamilyRequestsViewController")
                
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true)
                    self.tableView.reloadData()
                    print("Table reloaded with \(self.requests.count) requests")
                }
            } catch {
                print("Error loading requests in FamilyRequestsViewController: \(error)")
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true)
                    self.showAlert(title: "Error", message: "Could not load requests: \(error.localizedDescription)")
                }
            }
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
        
        tableView.register(FamilyRequestsTableViewCell.self, forCellReuseIdentifier: "FamilyRequestsTableViewCell")
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.rowHeight = 90
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 72, bottom: 0, right: 16)

        tableView.tableHeaderView = makeTableHeader()
    }
    
    private func makeTableHeader() -> UIView {
        let header = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 50))
        let label = UILabel()
        label.text = "Pending Approvals"
        label.font = .boldSystemFont(ofSize: 20)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        header.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            label.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -5)
        ])
        
        return header
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
}

extension FamilyRequestsViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return requests.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        guard let cell = tableView.dequeueReusableCell(withIdentifier: "FamilyRequestsTableViewCell", for: indexPath) as? FamilyRequestsTableViewCell else {
            return UITableViewCell()
        }

        let request = requests[indexPath.row]
        
        cell.nameLabel.text = request.userName ?? "Unknown User"
        cell.emailLabel.text = request.userEmail ?? "No email"
        
        //  APPROVE confirmation
        cell.approveAction = { [weak self] in
            guard let self = self, let group = self.group else { return }
            
            let alert = UIAlertController(
                title: "Confirm Approval",
                message: "Are you sure you want to approve this request?",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Approve", style: .default, handler: { _ in
                self.approveRequest(request: request, at: indexPath)
                
            }))
            
            self.present(alert, animated: true)
        }
        
        //  REJECT confirmation
        cell.rejectAction = { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(
                title: "Confirm Rejection",
                message: "Are you sure you want to reject this request?",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Reject", style: .destructive, handler: { _ in
                self.rejectRequest(request: request, at: indexPath)
                
            }))
            
            self.present(alert, animated: true)
        }
        
        return cell
    }
    
    
    private func approveRequest(request: JoinRequest, at indexPath: IndexPath) {
        guard let group = group else { return }
        
        let loadingAlert = UIAlertController(title: nil, message: "Approving...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
        
        Task {
            do {
                try await SupabaseManager.shared.approveJoinRequest(
                    requestId: request.id,
                    groupId: group.id,
                    userId: request.userId
                )
                
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        self.requests.remove(at: indexPath.row)
                        self.tableView.deleteRows(at: [indexPath], with: .automatic)
                        self.showAlert(title: "Success", message: "Request approved successfully")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        self.showAlert(title: "Error", message: "Could not approve request: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    
    private func rejectRequest(request: JoinRequest, at indexPath: IndexPath) {
        let loadingAlert = UIAlertController(title: nil, message: "Rejecting...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
        
        Task {
            do {
                try await SupabaseManager.shared.rejectJoinRequest(requestId: request.id)
                
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        self.requests.remove(at: indexPath.row)
                        self.tableView.deleteRows(at: [indexPath], with: .automatic)
                        self.showAlert(title: "Success", message: "Request rejected")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        self.showAlert(title: "Error", message: "Could not reject request: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
