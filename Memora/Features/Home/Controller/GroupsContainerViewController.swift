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
