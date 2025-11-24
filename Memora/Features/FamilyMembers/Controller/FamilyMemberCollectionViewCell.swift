//
//  FamilyMemberCollectionViewCell.swift
//  Memora
//
//  Created by user@3 on 10/11/25.
//

import UIKit

class FamilyMemberCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var MemberImageView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        setupAppearance()
    }

    private func setupAppearance() {

        // --- Proper rectangular card with rounded corners ---
        contentView.backgroundColor = .white
        contentView.layer.cornerRadius = 20    // FIX: was 50 (too large)
        contentView.layer.masksToBounds = true

        // --- Image rounded slightly, not capsule ---
        MemberImageView.clipsToBounds = true
        MemberImageView.contentMode = .scaleAspectFill
        MemberImageView.layer.cornerRadius = 16

        // --- Soft shadow ---
        layer.shadowColor = UIColor.black.withAlphaComponent(0.10).cgColor
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 10
        layer.shadowOpacity = 1
        layer.masksToBounds = false
    }

    func configure(name: String, image: UIImage?) {
        MemberImageView.image = image
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        MemberImageView.image = nil
    }
}
