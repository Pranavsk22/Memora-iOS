import UIKit

protocol MemoryCollectionViewCellDelegate: AnyObject {
    /// called when user taps the cell
    func memoryCollectionViewCellDidTap(_ cell: MemoryCollectionViewCell)
}

final class MemoryCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "MemoryCell" // must match the XIB reuse identifier

    // Connected in your XIB: image view
    @IBOutlet private weak var iconImageView: UIImageView!

    // Delegate
    weak var delegate: MemoryCollectionViewCellDelegate?

    // Track currently-loading filename to avoid stale images on reuse
    private var currentlyLoadingFilename: String?

    override func awakeFromNib() {
        super.awakeFromNib()
        setupAppearance()
        addTapGesture()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.image = nil
        currentlyLoadingFilename = nil
    }

    private func setupAppearance() {
        // Make sure image view clips and scales correctly.
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.clipsToBounds = true
        // XIB may already set corner radius; ensure background while loading
        iconImageView.backgroundColor = UIColor(white: 0.97, alpha: 1)
        contentView.isUserInteractionEnabled = true
    }

    private func addTapGesture() {
        // Keep a tap inside the cell and forward it to delegate
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        contentView.addGestureRecognizer(tap)
    }

    @objc private func handleTap() {
        delegate?.memoryCollectionViewCellDidTap(self)
    }

    
    /// Configure the cell with a SupabaseMemory — loads from memory_media
    func configure(with supabaseMemory: SupabaseMemory) {
        iconImageView.image = UIImage(systemName: "photo")
        
        // Check if we have media
        if let imageMedia = supabaseMemory.memoryMedia?.first(where: { $0.mediaType == "photo" }) {
            let imageUrl = imageMedia.mediaUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let url = URL(string: imageUrl) {
                ImageLoader.shared.load(from: url) { [weak self] image in
                    DispatchQueue.main.async {
                        self?.iconImageView.image = image ?? UIImage(systemName: "photo")
                    }
                }
            }
        } else {
            // No image media found
            iconImageView.image = UIImage(systemName: "photo")
        }
    }
}


