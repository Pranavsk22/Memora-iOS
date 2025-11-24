//
//  FamilyMemberListTableViewCell.swift
//  Memora
//
//  Created by user@3 on 11/11/25.
//

import UIKit

class FamilyMemberListTableViewCell: UITableViewCell {

    //@IBOutlet weak var profileImageView: UIImageView!   // connect this to your image view in XIB
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Make profile image circular
        //profileImageView.layer.cornerRadius = profileImageView.frame.height / 2
        //profileImageView.clipsToBounds = true
        
        // Cell style adjustments
        self.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        self.detailTextLabel?.font = UIFont.systemFont(ofSize: 14)
        self.detailTextLabel?.textColor = .gray
        self.accessoryType = .disclosureIndicator
    }

    // Adjust radius after layout
    override func layoutSubviews() {
        super.layoutSubviews()
        //profileImageView.layer.cornerRadius = profileImageView.frame.height / 2
    }

    func configure(name: String, phone: String, image: UIImage?) {
        self.textLabel?.text = name
        self.detailTextLabel?.text = phone
        //self.profileImageView.image = image
    }
}
