//
//  AddFamilyMemberModalViewController.swift
//  Memora
//
//  Created by user@3 on 11/11/25.
//

import UIKit

class AddFamilyMemberModalViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var qrCardView: UIView!
    @IBOutlet weak var qrImageView: UIImageView!
    @IBOutlet weak var guidanceLabel: UILabel!
    @IBOutlet weak var codeStackView: UIStackView!

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.black.withAlphaComponent(0.35)

        setupCardUI()
        setupProfileImage()
        roundGrabber()
    }

    // MARK: - Setup UI
    private func setupCardUI() {
        qrCardView.backgroundColor = .white
        qrCardView.layer.cornerRadius = 20
        qrCardView.layer.masksToBounds = false

        qrCardView.layer.shadowColor = UIColor.black.withAlphaComponent(0.12).cgColor
        qrCardView.layer.shadowOffset = CGSize(width: 0, height: 6)
        qrCardView.layer.shadowRadius = 14
        qrCardView.layer.shadowOpacity = 1
    }

    private func setupProfileImage() {
        profileImageView.image = UIImage(named: "profilePhoto")
        profileImageView.contentMode = .scaleAspectFill
        profileImageView.clipsToBounds = true

        profileImageView.layer.borderColor = UIColor.white.cgColor
        profileImageView.layer.borderWidth = 3

        // Keep visible above card
        view.bringSubviewToFront(profileImageView)
    }

    /// ✅ Rounded grabber bar at top
    /// Add a UIView on top, set height ~5–6 px, and give it tag = 999 in Interface Builder
    private func roundGrabber() {
        if let grabber = view.viewWithTag(999) {
            grabber.backgroundColor = UIColor.lightGray.withAlphaComponent(0.6)
            grabber.layer.cornerRadius = grabber.frame.height / 2
            grabber.clipsToBounds = true
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        profileImageView.layer.cornerRadius = profileImageView.frame.width / 2
    }

    // MARK: - IBActions
    @IBAction func closePressed(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

    @IBAction func sharePressed(_ sender: Any) {
        let text = "Join code: 4 7 2 8"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        present(activityVC, animated: true)
    }
}
