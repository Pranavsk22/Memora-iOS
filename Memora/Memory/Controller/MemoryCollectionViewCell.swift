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

    /// Configure the cell with a Memory — only loads the first image attachment (if any).
    func configure(with memory: Memory, placeholder: UIImage? = nil) {
        // default placeholder
        iconImageView.image = placeholder ?? UIImage(systemName: "photo")

        // find the first image attachment
        let imageAttachments = memory.attachments.filter { $0.kind == .image }
        guard let first = imageAttachments.first else {
            currentlyLoadingFilename = nil
            return
        }

        let filename = first.filename.trimmingCharacters(in: .whitespacesAndNewlines)
        currentlyLoadingFilename = filename

        // Try local file first
        let localURL = MemoryStore.shared.urlForAttachment(filename: filename)
        if FileManager.default.fileExists(atPath: localURL.path) {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                let img = UIImage(contentsOfFile: localURL.path)
                DispatchQueue.main.async {
                    guard self.currentlyLoadingFilename == filename else { return }
                    self.iconImageView.image = img ?? (placeholder ?? UIImage(systemName: "photo"))
                }
            }
            return
        }

        // If filename is an http(s) URL, try to load remotely
        if let url = URL(string: filename), (url.scheme?.hasPrefix("http") ?? false) {
            // Use project's ImageLoader if available
            if let _ = NSClassFromString("ImageLoader") {
                // call through to ImageLoader API used in the project
                ImageLoader.shared.loadImage(from: filename) { [weak self] img in
                    DispatchQueue.main.async {
                        guard let self = self, self.currentlyLoadingFilename == filename else { return }
                        self.iconImageView.image = img ?? (placeholder ?? UIImage(systemName: "photo"))
                    }
                }
                return
            } else {
                // fallback simple fetch (not ideal for production)
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    guard let self = self else { return }
                    if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                        DispatchQueue.main.async {
                            guard self.currentlyLoadingFilename == filename else { return }
                            self.iconImageView.image = img
                        }
                    } else {
                        DispatchQueue.main.async {
                            guard self.currentlyLoadingFilename == filename else { return }
                            self.iconImageView.image = placeholder ?? UIImage(systemName: "photo")
                        }
                    }
                }
                return
            }
        }

        // Not local and not http(s) — clear to placeholder
        currentlyLoadingFilename = nil
        iconImageView.image = placeholder ?? UIImage(systemName: "photo")
    }
}
