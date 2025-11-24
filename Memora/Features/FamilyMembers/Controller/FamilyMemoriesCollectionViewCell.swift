import UIKit

class FamilyMemoriesCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var cardImageView: UIImageView!
    @IBOutlet weak var promptLabel: UILabel!
    @IBOutlet weak var authorLabel: UILabel!
    @IBOutlet weak var cardView: UIView!

    override func awakeFromNib() {
        super.awakeFromNib()
        setupCard()
    }

    private func setupCard() {
        backgroundColor = .clear

        // Main card container
        cardView.layer.cornerRadius = 22
        cardView.backgroundColor = .systemBackground
        cardView.layer.masksToBounds = false
        
        // shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowRadius = 16
        layer.shadowOffset = CGSize(width: 0, height: 6)
        layer.masksToBounds = false

        // Image styling
        cardImageView.layer.cornerRadius = 18
        cardImageView.clipsToBounds = true
        cardImageView.contentMode = .scaleAspectFill
        if #available(iOS 11.0, *) {
            cardImageView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        }

        // Labels
        promptLabel.numberOfLines = 2
        promptLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)

        authorLabel.font = UIFont.systemFont(ofSize: 14)
        authorLabel.textColor = .secondaryLabel
    }

    func configure(prompt: String, author: String, image: UIImage?) {
        promptLabel.text = prompt
        authorLabel.text = author
        cardImageView.image = image ?? UIImage(systemName: "photo")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        cardImageView.image = nil
        promptLabel.text = nil
        authorLabel.text = nil
    }
}
