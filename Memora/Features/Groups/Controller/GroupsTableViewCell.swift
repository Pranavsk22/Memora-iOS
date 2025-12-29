//
//  GroupsTableViewCell.swift
//  Memora
//
//  Created by user@3 on 28/12/25.
//

import UIKit

class GroupsTableViewCell: UITableViewCell {

    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var groupImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundColor = .clear
        selectionStyle = .none

        containerView.layer.cornerRadius = 22
        containerView.backgroundColor = .white

        groupImageView.layer.cornerRadius = 24
        groupImageView.clipsToBounds = true
    }

    func configure(title: String, subtitle: String, image: UIImage?) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        groupImageView.image = image
    }
}

