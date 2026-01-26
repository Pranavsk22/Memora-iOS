//
//  GroupsTableViewCell.swift
//  Memora
//
//  Created by user@3 on 28/12/25.
//

import UIKit

class GroupsTableViewCell: UITableViewCell {
    
    @IBOutlet weak var containerView: UIView!
    //@IBOutlet weak var groupImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var adminBadge: UIView!
    @IBOutlet weak var adminLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        backgroundColor = .clear
        selectionStyle = .none
        
        containerView.layer.cornerRadius = 22
        containerView.backgroundColor = .white
        
//        groupImageView.layer.cornerRadius = 24
//        groupImageView.clipsToBounds = true
        
        // Admin badge styling
        adminBadge.layer.cornerRadius = 8
        adminBadge.backgroundColor = .systemBlue.withAlphaComponent(0.1)
        adminLabel.textColor = .systemBlue
        adminLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        adminBadge.isHidden = true
    }
    
    func configure(title: String, subtitle: String, isAdmin: Bool = false) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        //groupImageView.image = image
        
        // Show admin badge if user is admin
        adminBadge.isHidden = !isAdmin
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        adminBadge.isHidden = true
    }
}

