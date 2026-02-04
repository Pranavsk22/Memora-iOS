import UIKit

class FamilyMemoriesCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var cardImageView: UIImageView!
    @IBOutlet weak var promptLabel: UILabel!
    @IBOutlet weak var authorLabel: UILabel!
    @IBOutlet weak var cardView: UIView!
//    @IBOutlet weak var yearLabel: UILabel!
    
    private var imageLoadingTask: URLSessionDataTask?
    
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
        cardImageView.backgroundColor = .systemGray6
        if #available(iOS 11.0, *) {
            cardImageView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        }

        // Labels
        promptLabel.numberOfLines = 2
        promptLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)

        authorLabel.font = UIFont.systemFont(ofSize: 14)
        authorLabel.textColor = .secondaryLabel
        
        // Year label styling (add if needed)
//        yearLabel?.font = UIFont.systemFont(ofSize: 13)
//        yearLabel?.textColor = .tertiaryLabel
    }

    func configure(memory: GroupMemory) {
        promptLabel.text = memory.title
        authorLabel.text = "By \(memory.userName ?? "Unknown")"
        
//        if let year = memory.year {
//            yearLabel?.text = "\(year)"
//            yearLabel?.isHidden = false
//        } else {
//            yearLabel?.isHidden = true
//        }
        
        // Cancel any previous image loading
        imageLoadingTask?.cancel()
        
        // Load the first photo from memory media if available
        if let firstPhoto = memory.memoryMedia?.first(where: { $0.mediaType == "photo" }) {
            loadImage(from: firstPhoto.mediaUrl)
        } else if let mediaUrl = memory.mediaUrl, memory.mediaType == "photo" {
            // Fallback to single media URL
            loadImage(from: mediaUrl)
        } else {
            // No photos available, show placeholder
            cardImageView.image = UIImage(systemName: "photo.on.rectangle.angled")
            cardImageView.tintColor = .systemGray3
            cardImageView.contentMode = .center
        }
    }
    
    private func loadImage(from urlString: String) {
        guard let url = URL(string: urlString) else {
            cardImageView.image = UIImage(systemName: "photo.on.rectangle.angled")
            cardImageView.tintColor = .systemGray3
            cardImageView.contentMode = .center
            return
        }
        
        // Show loading state
        cardImageView.image = nil
        cardImageView.backgroundColor = .systemGray6
        
        // Load image asynchronously
        imageLoadingTask = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to load image: \(error)")
                    self.cardImageView.image = UIImage(systemName: "photo.on.rectangle.angled")
                    self.cardImageView.tintColor = .systemGray3
                    self.cardImageView.contentMode = .center
                    return
                }
                
                if let data = data, let image = UIImage(data: data) {
                    self.cardImageView.image = image
                    self.cardImageView.contentMode = .scaleAspectFill
                    self.cardImageView.backgroundColor = .clear
                } else {
                    self.cardImageView.image = UIImage(systemName: "photo.on.rectangle.angled")
                    self.cardImageView.tintColor = .systemGray3
                    self.cardImageView.contentMode = .center
                }
            }
        }
        imageLoadingTask?.resume()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageLoadingTask?.cancel()
        cardImageView.image = nil
        promptLabel.text = nil
        authorLabel.text = nil
        //yearLabel?.text = nil
    }
}
