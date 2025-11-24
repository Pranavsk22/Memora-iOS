//
//  FamilyMemberListViewController.swift
//  Memora
//
//  Created by user@3 on 11/11/25.
//

import UIKit

class FamilyMemberListViewController: UIViewController {

    
    let lightGrey = UIColor(red: 242/255, green: 242/255, blue: 247/255, alpha: 1)
    
    @IBOutlet weak var tableView: UITableView!
    
    let joinRequests = ["Peterson", "Amanda", "Chris", "Rishi"]  // sample
    let members = [
        ("John", "9876543210"),
        ("Peter", "9876543210"),
        ("Raqual", "9876543210"),
        ("Raunak", "9876543210"),
        ("Eliana", "9876543210"),
        ("Jennie", "9876543210"),
        ("Denver", "9876543210")
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        

        navigationItem.title = "Family Members"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addMemberTapped)
        )
        
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
    }
    
    //add member button
    @objc func addMemberTapped() {
        let modalVC = AddFamilyMemberModalViewController(
            nibName: "AddFamilyMemberModalViewController",
            bundle: nil
        )
        
        // iOS Bottom Sheet
        modalVC.modalPresentationStyle = .pageSheet
        
        if let sheet = modalVC.sheetPresentationController {
            sheet.detents = [.large()]        // or .medium(), or custom height
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        
        present(modalVC, animated: true)
    }

}

extension FamilyMemberListViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2   // Section 0 => Join Requests, Section 1 => Members
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 1 : members.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: "FamilyMemberRequestsCell",
                for: indexPath
            ) as! FamilyMemberRequestsTableViewCell
            
            cell.textLabel?.text = "Join Requests"
            
            if joinRequests.count == 1 {
                cell.detailTextLabel?.text = joinRequests[0]
            } else {
                cell.detailTextLabel?.text = "\(joinRequests[0]) + \(joinRequests.count - 1) others"
            }
            
            cell.backgroundColor = lightGrey
            cell.contentView.backgroundColor = lightGrey

            
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "FamilyMemberListCell",
            for: indexPath
        ) as! FamilyMemberListTableViewCell
        
        
        cell.backgroundColor = lightGrey
        cell.contentView.backgroundColor = lightGrey

        let member = members[indexPath.row]
        cell.textLabel?.text = member.0
        cell.detailTextLabel?.text = member.1
        
        return cell
    }
    
    // ✅ ADD SPACING BETWEEN SECTIONS
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 1 ? 32 : 0.001
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section == 1 else { return nil }

        let headerView = UIView()
        headerView.backgroundColor = lightGrey


        let titleLabel = UILabel()
        titleLabel.text = "Family Members"
        titleLabel.font = UIFont.preferredFont(forTextStyle: .footnote).bold()
        titleLabel.textColor = .secondaryLabel
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        headerView.addSubview(titleLabel)

        // Constrain label with left/right insets to align with cell content (72 leading to match separator inset)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: headerView.trailingAnchor, constant: -16),
            titleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -6)
        ])

        return headerView
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            print("Tapped Join Requests")
            let familyRequest = FamilyRequestsViewController(nibName: "FamilyRequestsViewController", bundle: nil)
            navigationController?.pushViewController(familyRequest, animated: true)
        } else {
            print("Tapped \(members[indexPath.row].0)")
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
