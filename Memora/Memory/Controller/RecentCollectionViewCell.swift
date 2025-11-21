import UIKit

final class RecentCollectionViewCell: UICollectionViewCell {
    static let reuseId = "RecentCell"

    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet private weak var overlayView: UIView!
    
    
    @IBOutlet weak var imageView: UIImageView!
    
    // Track current loading url so async callback doesn't override a reused cell
      private var currentImageURL: URL?
      private var activityIndicator: UIActivityIndicatorView?

      override func awakeFromNib() {
          super.awakeFromNib()

          // Card styling
          contentView.layer.cornerRadius = 22
          contentView.clipsToBounds = true
          contentView.backgroundColor = .secondarySystemBackground

          // Image view
          imageView.contentMode = .scaleAspectFill
          imageView.clipsToBounds = true
          imageView.layer.masksToBounds = true

          // overlay
          overlayView.backgroundColor = UIColor(white: 0, alpha: 0.28)
          overlayView.layer.cornerRadius = 12
          overlayView.layer.masksToBounds = true

          titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
          titleLabel.textColor = .white

          // Activity indicator
          let indicator = UIActivityIndicatorView(style: .medium)
          indicator.hidesWhenStopped = true
          indicator.translatesAutoresizingMaskIntoConstraints = false
          contentView.addSubview(indicator)
          NSLayoutConstraint.activate([
              indicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
              indicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
          ])
          self.activityIndicator = indicator
      }

      override func prepareForReuse() {
          super.prepareForReuse()

          // Cancel previous remote load if any
          if let url = currentImageURL {
              ImageLoader.shared.cancelLoad(for: url)
          }
          currentImageURL = nil

          // Reset UI
          activityIndicator?.stopAnimating()
          imageView.image = nil
          imageView.backgroundColor = UIColor(white: 0.95, alpha: 1)
          titleLabel.text = nil
      }

      /// Configure with Memory and optional remote image URL string
      /// - memory: Memory model
      /// - imageURLString: optional remote URL override (e.g. unsplash link). If nil, the cell will prefer local attachment if available.
      func configure(with memory: Memory, imageURLString: String?) {
          titleLabel.text = memory.title

          // Make sure cell visible while loading
          contentView.isHidden = false
          imageView.alpha = 1.0
          imageView.backgroundColor = UIColor(white: 0.95, alpha: 1)
          imageView.image = nil

          // Cancel any previous
          if let prev = currentImageURL {
              ImageLoader.shared.cancelLoad(for: prev)
              currentImageURL = nil
          }

          // Start indicator
          DispatchQueue.main.async {
              self.activityIndicator?.startAnimating()
          }

          // 1) Prefer local attachment if present and file exists on disk
          if let firstAttachment = memory.attachments.first(where: { $0.kind == .image }) {
              let filename = firstAttachment.filename.trimmingCharacters(in: .whitespacesAndNewlines)
              let localURL = MemoryStore.shared.urlForAttachment(filename: filename)
              if FileManager.default.fileExists(atPath: localURL.path) {
                  // load from disk
                  ImageLoader.shared.loadLocal(from: localURL) { [weak self] image in
                      guard let self = self else { return }
                      DispatchQueue.main.async {
                          self.activityIndicator?.stopAnimating()
                          self.setImageWithFade(image)
                      }
                  }
                  return
              }

              // If filename itself is a remote url, we will consider it below unless we have explicit override
          }

          // 2) If caller passed explicit remote image URL, use it
          if let s = imageURLString?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty,
             let url = URL(string: s), s.hasPrefix("http") {
              currentImageURL = url
              ImageLoader.shared.load(from: url) { [weak self] image in
                  guard let self = self else { return }
                  DispatchQueue.main.async {
                      // ensure still the expected URL
                      if self.currentImageURL == url {
                          self.activityIndicator?.stopAnimating()
                          self.setImageWithFade(image)
                      }
                  }
              }
              return
          }

          // 3) If first attachment is remote URL, use it
          if let firstAttachment = memory.attachments.first(where: { $0.kind == .image }) {
              let filename = firstAttachment.filename.trimmingCharacters(in: .whitespacesAndNewlines)
              if let url = URL(string: filename), filename.hasPrefix("http") {
                  currentImageURL = url
                  ImageLoader.shared.load(from: url) { [weak self] image in
                      guard let self = self else { return }
                      DispatchQueue.main.async {
                          if self.currentImageURL == url {
                              self.activityIndicator?.stopAnimating()
                              self.setImageWithFade(image)
                          }
                      }
                  }
                  return
              }
          }

          // 4) Nothing available — stop indicator and set placeholder
          DispatchQueue.main.async {
              self.activityIndicator?.stopAnimating()
              self.imageView.image = UIImage(systemName: "photo")
              self.imageView.tintColor = UIColor(white: 0.75, alpha: 1)
              self.imageView.backgroundColor = UIColor(white: 0.95, alpha: 1)
          }
      }

      // helper: fade-in
      private func setImageWithFade(_ image: UIImage?) {
          let img = image ?? UIImage(systemName: "photo")
          imageView.alpha = 0.0
          imageView.image = img
          imageView.backgroundColor = image == nil ? UIColor(white: 0.95, alpha: 1) : .clear
          UIView.animate(withDuration: 0.28) {
              self.imageView.alpha = 1.0
          }
      }
  }
