//
//  FamilyMemberCollectionViewCell.swift
//  Memora
//
//  Created by user@3 on 10/11/25.
//
import UIKit

class FamilyMemberCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var MemberImageView: UIImageView!
    @IBOutlet weak var memberNameLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupAppearance()
    }

    private func setupAppearance() {
        // --- Proper rectangular card with rounded corners ---
        contentView.backgroundColor = .white
        contentView.layer.cornerRadius = 20
        contentView.layer.masksToBounds = true

        // --- Image rounded slightly, not capsule ---
        MemberImageView.clipsToBounds = true
        MemberImageView.contentMode = .scaleAspectFill
        MemberImageView.layer.cornerRadius = 16
        MemberImageView.backgroundColor = .systemGray6

        // --- Member name label ---
        memberNameLabel.textAlignment = .center
        memberNameLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        memberNameLabel.textColor = .label
        memberNameLabel.numberOfLines = 1

        // --- Soft shadow ---
        layer.shadowColor = UIColor.black.withAlphaComponent(0.10).cgColor
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 10
        layer.shadowOpacity = 1
        layer.masksToBounds = false
    }

    func configure(name: String, image: UIImage? = nil) {
        memberNameLabel.text = name
        
        if let image = image {
            MemberImageView.image = image
            MemberImageView.backgroundColor = .clear
        } else {
            // Use system image as placeholder with color based on name
            MemberImageView.image = UIImage(systemName: "person.circle.fill")
            MemberImageView.tintColor = colorForName(name)
            MemberImageView.backgroundColor = .systemGray6
        }
    }

    private func colorForName(_ name: String) -> UIColor {
        // Generate a consistent color based on the name
        let colors: [UIColor] = [
            .systemBlue, .systemGreen, .systemOrange, .systemPurple,
            .systemPink, .systemTeal, .systemIndigo, .systemBrown
        ]
        
        let hash = name.utf8.reduce(0) { ($0 << 5) &+ $0 &+ Int($1) }
        return colors[abs(hash) % colors.count]
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        MemberImageView.image = nil
        memberNameLabel.text = nil
    }
}
