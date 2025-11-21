import UIKit

final class CategoryCardTableViewCell: UITableViewCell {

    static let reuseId = "CategoryCardCell"

    @IBOutlet weak var cardContainer: UIView!
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!

    // track which filename we're currently loading (avoid race conditions)
      private var currentlyLoadingFilename: String?

      override func awakeFromNib() {
          super.awakeFromNib()

          selectionStyle = .none
          backgroundColor = .clear
          contentView.backgroundColor = .clear

          // Rounded card container (clipping for the image)
          cardContainer.layer.cornerRadius = 26
          cardContainer.clipsToBounds = true
          cardContainer.backgroundColor = .clear

          // Thumbnail
          thumbnailImageView.contentMode = .scaleAspectFill
          thumbnailImageView.clipsToBounds = true
          thumbnailImageView.layer.cornerRadius = 26
          thumbnailImageView.layer.masksToBounds = true

          // Title styling
          titleLabel.textColor = .white
          titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
          titleLabel.numberOfLines = 2
          // readable text on photos
          titleLabel.layer.shadowColor = UIColor.black.cgColor
          titleLabel.layer.shadowOpacity = 0.75
          titleLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
          titleLabel.layer.shadowRadius = 3
          titleLabel.layer.masksToBounds = false

          // Drop shadow for the visual card (use contentView's layer)
          // We will set shadowPath in layoutSubviews for better performance
          contentView.layer.shadowColor = UIColor.black.cgColor
          contentView.layer.shadowOpacity = 0.06
          contentView.layer.shadowOffset = CGSize(width: 0, height: 6)
          contentView.layer.shadowRadius = 12
          contentView.layer.masksToBounds = false
      }

      override func prepareForReuse() {
          super.prepareForReuse()
          currentlyLoadingFilename = nil
          thumbnailImageView.image = nil
          titleLabel.text = nil
      }

      override func layoutSubviews() {
          super.layoutSubviews()
          // ensure shadow follows the visible card shape
          // the shadow path should match the cardContainer frame in the cell's coordinate space
          // convert cardContainer frame to contentView coordinates
          let frameInContent = contentView.convert(cardContainer.frame, from: cardContainer.superview)
          contentView.layer.shadowPath = UIBezierPath(
              roundedRect: frameInContent.insetBy(dx: 0, dy: 0),
              cornerRadius: cardContainer.layer.cornerRadius
          ).cgPath
      }

      /// Configure the cell from a Memory model
      func configure(with memory: Memory) {
          titleLabel.text = memory.title

          // reset image state
          thumbnailImageView.image = nil
          currentlyLoadingFilename = nil

          // Find first image attachment
          guard let att = memory.attachments.first(where: { $0.kind == .image }) else {
              thumbnailImageView.image = UIImage(systemName: "photo")
              return
          }

          let filename = att.filename.trimmingCharacters(in: .whitespacesAndNewlines)
          currentlyLoadingFilename = filename

          // Prefer local file if it exists
          let localURL = MemoryStore.shared.urlForAttachment(filename: filename)
          if FileManager.default.fileExists(atPath: localURL.path) {
              // Use project's ImageLoader if available
              if NSClassFromString("ImageLoader") != nil {
                  ImageLoader.shared.loadLocal(from: localURL) { [weak self] img in
                      DispatchQueue.main.async {
                          guard let self = self, self.currentlyLoadingFilename == filename else { return }
                          self.thumbnailImageView.image = img ?? UIImage(systemName: "photo")
                      }
                  }
              } else {
                  // Fallback to direct disk load
                  DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                      let img = UIImage(contentsOfFile: localURL.path)
                      DispatchQueue.main.async {
                          guard let self = self, self.currentlyLoadingFilename == filename else { return }
                          self.thumbnailImageView.image = img ?? UIImage(systemName: "photo")
                      }
                  }
              }
              return
          }

          // If filename looks like a remote URL, try network load
          if let url = URL(string: filename), (url.scheme?.hasPrefix("http") ?? false) {
              if NSClassFromString("ImageLoader") != nil {
                  ImageLoader.shared.load(from: url) { [weak self] img in
                      DispatchQueue.main.async {
                          guard let self = self, self.currentlyLoadingFilename == filename else { return }
                          self.thumbnailImageView.image = img ?? UIImage(systemName: "photo")
                      }
                  }
              } else {
                  // Simple network fallback (synchronous Data(contentsOf:) on background queue)
                  DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                      let data = try? Data(contentsOf: url)
                      let img = data.flatMap { UIImage(data: $0) }
                      DispatchQueue.main.async {
                          guard let self = self, self.currentlyLoadingFilename == filename else { return }
                          self.thumbnailImageView.image = img ?? UIImage(systemName: "photo")
                      }
                  }
              }
              return
          }

          // otherwise: no valid image -> placeholder
          thumbnailImageView.image = UIImage(systemName: "photo")
      }
  }
