import UIKit

/// XIB cell for category tiles. Reuse identifier in your XIB is "CategoryCell".
final class MemoryCategoryCollectionViewCell: UICollectionViewCell {
    // Must match the XIB reuseIdentifier
    static let reuseIdentifier = "CategoryCell"

    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!

    // Simple fixed set of categories
    enum Category {
        case recipies
        case childhood
        case travel
        case lifeLesson
        case love

        var title: String {
            switch self {
            case .recipies: return "Recipes"
            case .childhood: return "Childhood"
            case .travel: return "Travel"
            case .lifeLesson: return "Life Lesson"
            case .love: return "Love"
            }
        }

        /// Image asset name to use for this category — add these to Assets.xcassets
        var imageName: String {
            switch self {
            case .recipies: return "cat_recipes"
            case .childhood: return "cat_childhood"
            case .travel: return "cat_travel"
            case .lifeLesson: return "cat_lifelesson"
            case .love: return "cat_love"
            }
        }
    }

    // MARK: - Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        setupAppearance()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.image = nil
        titleLabel.text = nil
    }

    // MARK: - Appearance
    private func setupAppearance() {
        // The XIB sets cornerRadius; ensure image fills and clips
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.clipsToBounds = true
        // Ensure label style is consistent
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .white
        // Put a subtle shadow on the title for legibility over images
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowRadius = 4
        titleLabel.layer.shadowOpacity = 0.45
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        titleLabel.layer.masksToBounds = false
    }

    // MARK: - Configure
    /// Configure the cell for one of the fixed categories
    func configure(with category: Category) {
        titleLabel.text = category.title

        // Try asset-first; fall back to SF symbol
        if let img = UIImage(named: category.imageName) {
            iconImageView.image = img
        } else {
            iconImageView.image = UIImage(systemName: "photo")
        }

        // Ensure label is visible on top of image (XIB constraint/order should handle this).
        bringSubviewToFront(titleLabel)
    }

    /// Convenience configure by title string (maps string to enum if possible).
    func configure(withTitle title: String) {
        let lowered = title.lowercased()
        if lowered.contains("recipies") || lowered.contains("recipies") {
            configure(with: .recipies); return
        }
        if lowered.contains("child") {
            configure(with: .childhood); return
        }
        if lowered.contains("travel") {
            configure(with: .travel); return
        }
        if lowered.contains("life") || lowered.contains("lesson") {
            configure(with: .lifeLesson); return
        }
        if lowered.contains("love") {
            configure(with: .love); return
        }
        // default fallback
        configure(with: .lifeLesson)
    }
}
