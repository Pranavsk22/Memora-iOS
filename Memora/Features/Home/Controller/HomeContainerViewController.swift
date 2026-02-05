//
// HomeContainerViewController
//

import UIKit

final class HomeContainerViewController: UIViewController {
    private var homeFromXib: HomeViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        embedHomeXIB()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        title = "Home"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always

        let profileItem = UIBarButtonItem(
            image: UIImage(systemName: "person.circle"),
            style: .plain,
            target: self,
            action: #selector(didTapProfile)
        )
        profileItem.tintColor = .label
        navigationItem.rightBarButtonItem = profileItem
    }

    private func embedHomeXIB() {
        let home = HomeViewController(nibName: "HomeViewController", bundle: nil)
        addChild(home)
        view.addSubview(home.view)
        home.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            home.view.topAnchor.constraint(equalTo: view.topAnchor),
            home.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            home.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            home.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        home.didMove(toParent: self)
        self.homeFromXib = home
    }

    @objc private func didTapProfile() {
        let vc = AccountModalViewController()
        vc.title = "Account"

        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
        nav.navigationBar.prefersLargeTitles = true

        present(nav, animated: true)
    }
}
