//
//  JoinGroupModalViewController.swift
//  Memora
//
//  Created by user@3 on 28/12/25.
//

import UIKit

class JoinGroupModalViewController: UIViewController {

    @IBOutlet weak var codeTextField: UITextField!
    @IBOutlet weak var joinButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Join Group"
        view.backgroundColor = UIColor.systemGray6

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(close)
        )

        joinButton.layer.cornerRadius = 16
    }

    @IBAction func joinPressed(_ sender: UIButton) {
        let code = codeTextField.text ?? ""
        print("Joining group with code:", code)
        dismiss(animated: true)
    }

    @objc private func close() {
        dismiss(animated: true)
    }
}

