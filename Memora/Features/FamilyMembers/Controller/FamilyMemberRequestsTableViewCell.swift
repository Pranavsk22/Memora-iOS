//
//  FamilyMemberRequestsTableViewCell.swift
//  Memora
//
//  Created by user@3 on 11/11/25.
//
import UIKit

class FamilyMemberRequestsTableViewCell: UITableViewCell {

    //@IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var statusDotView: UIView!   // A small black dot view on right side

    override func awakeFromNib() {
        super.awakeFromNib()

        // --- Profile Image Circular ---
//        profileImageView.clipsToBounds = true
//        profileImageView.contentMode = .scaleAspectFill
//
//        // circular corner
//        profileImageView.layer.cornerRadius = profileImageView.frame.height / 2

        // Subtitle formatting
        self.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        self.detailTextLabel?.font = UIFont.systemFont(ofSize: 14)
        self.detailTextLabel?.textColor = .gray

        // Status dot styling
        statusDotView.backgroundColor = .black
        statusDotView.layer.cornerRadius = statusDotView.frame.height / 2

        // Accessory arrow
        self.accessoryType = .disclosureIndicator
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        //profileImageView.layer.cornerRadius = profileImageView.frame.height / 2
        statusDotView.layer.cornerRadius = statusDotView.frame.height / 2
    }

    func configure(name: String, info: String, image: UIImage?) {
        self.textLabel?.text = name                    // e.g. "Join Requests"
        self.detailTextLabel?.text = info              // e.g. "Peterson + 3 others"
        //self.profileImageView.image = image
    }
}

