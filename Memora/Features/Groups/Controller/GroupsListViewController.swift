import UIKit

class GroupsListViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var addGroupButton: UIButton!

    // MARK: - Dummy Data
    let groups: [(name: String, subtitle: String, image: String)] = [
        ("Family", "12 members", "group_family"),
        ("School Friends", "8 members", "group_school"),
        ("Army Buddies", "15 members", "group_army")
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("tableView:", tableView as Any)
        print("addGroupButton:", addGroupButton as Any)


        // Hard safety check
        assert(tableView != nil, "❌ tableView outlet not connected")
        assert(addGroupButton != nil, "❌ addGroupButton outlet not connected")

        view.backgroundColor = UIColor.systemGray6
        setupTableView()
        setupFloatingButton()
    }

    // MARK: - Table Setup
    private func setupTableView() {
        let nib = UINib(nibName: "GroupsTableViewCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "GroupCell")

        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.rowHeight = 84
        tableView.sectionHeaderHeight = 0
        tableView.sectionFooterHeight = 0
    }

    // MARK: - Floating Button
    private func setupFloatingButton() {
        addGroupButton.layer.cornerRadius = 28
        addGroupButton.backgroundColor = .systemBlue
        addGroupButton.tintColor = .white

        addGroupButton.layer.shadowColor = UIColor.black.cgColor
        addGroupButton.layer.shadowOpacity = 0.2
        addGroupButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        addGroupButton.layer.shadowRadius = 8
    }

    @IBAction func addGroupPressed(_ sender: UIButton) {
        let vc = JoinGroupModalViewController()
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet

        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }

        present(nav, animated: true)
    }
}

// MARK: - Table Delegates
extension GroupsListViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        groups.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(
            withIdentifier: "GroupCell",
            for: indexPath
        ) as! GroupsTableViewCell

        let group = groups[indexPath.row]
        cell.configure(
            title: group.name,
            subtitle: group.subtitle,
            image: UIImage(named: group.image)
        )

        return cell
    }
    
    

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let vc = FamilyMemberViewController(
            nibName: "FamilyMemberViewController",
            bundle: nil
        )

        navigationController?.pushViewController(vc, animated: true)
    }
}

extension GroupsListViewController {

    func tableView(_ tableView: UITableView,
                   heightForFooterInSection section: Int) -> CGFloat {
        return 8   // 👈 small, clean gap
    }

    func tableView(_ tableView: UITableView,
                   viewForFooterInSection section: Int) -> UIView? {
        let v = UIView()
        v.backgroundColor = .clear
        return v
    }
}
