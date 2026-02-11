//
//  FamilyContainerViewController.swift
//  Memora
//
//  Created by user@3 on 24/11/25.
//

import Foundation
import UIKit

final class FamilyContainerViewController: UIViewController {
    private var familyVC: FamilyMemberViewController?

    override func viewDidLoad() {
        view.backgroundColor = .systemBackground
        super.viewDidLoad()
        embedFamilyProgrammatic()
    }

    private func embedFamilyProgrammatic() {
        let vc = FamilyMemberViewController()
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
        self.familyVC = vc
    }
}
