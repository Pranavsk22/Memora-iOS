//
//  GroupsContainerViewController.swift
//  Memora
//
//  Created by user@3 on 29/12/25.
//


import UIKit

final class GroupsContainerViewController: UIViewController {

    private var groupsVC: GroupsListViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        embedGroupsXIB()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

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

    @objc private func didTapProfile() {
        let vc = AccountModalViewController()
        vc.title = "Account"

        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        nav.navigationBar.prefersLargeTitles = true

        if let sheet = nav.sheetPresentationController {
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }

        present(nav, animated: true)
    }

    private func embedGroupsXIB() {
        let vc = GroupsListViewController(
            nibName: "GroupsListViewController",
            bundle: nil
        )

        addChild(vc)
        view.addSubview(vc.view)
        vc.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            vc.view.topAnchor.constraint(equalTo: view.topAnchor),
            vc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            vc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            vc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        vc.didMove(toParent: self)
        self.groupsVC = vc
    }
}
