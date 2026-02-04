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

        // Container styling
        containerView.layer.cornerRadius = 18
        containerView.backgroundColor = .secondarySystemBackground
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.08
        containerView.layer.shadowRadius = 12
        containerView.layer.shadowOffset = CGSize(width: 0, height: 6)
        containerView.layer.masksToBounds = false
        
//        groupImageView.layer.cornerRadius = 24
//        groupImageView.clipsToBounds = true
        
        // Admin badge styling
        adminBadge.layer.cornerRadius = 8
        adminBadge.backgroundColor = .systemBlue.withAlphaComponent(0.1)
        adminLabel.textColor = .systemBlue
        adminLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        adminBadge.isHidden = true
        
        // Labels styling
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
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
