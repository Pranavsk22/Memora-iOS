//
//  FamilyRequestsViewController.swift
//  Memora
//
//  Created by user@3 on 12/11/25.
//

import UIKit

class FamilyRequestsViewController: UIViewController {

    private let tableView = UITableView()
    
    // Mock Request Model
    struct Request {
        let name: String
        let email: String
    }
    
    // Dummy list (replace later with API data)
    var requests: [Request] = [
        Request(name: "John Doe", email: "john@gmail.com"),
        Request(name: "Priya Singh", email: "priya@gmail.com"),
        Request(name: "Karan Mehta", email: "karan@gmail.com")
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(red: 242/255, green: 242/255, blue: 247/255, alpha: 1)

        self.title = "Join Requests"
        
        setupTableView()
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
        
        cell.nameLabel.text = request.name
        cell.emailLabel.text = request.email
        
        //  APPROVE confirmation
        cell.approveAction = { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(
                title: "Confirm Approval",
                message: "Are you sure you want to approve this request?",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Approve", style: .default, handler: { _ in
                self.requests.remove(at: indexPath.row)
                
                tableView.performBatchUpdates({
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                }, completion: nil)
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
                self.requests.remove(at: indexPath.row)
                
                tableView.performBatchUpdates({
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                }, completion: nil)
            }))
            
            self.present(alert, animated: true)
        }
        
        return cell
    }
}
