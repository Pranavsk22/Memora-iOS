import UIKit

class FamilyMemoriesCollectionViewCell: UICollectionViewCell {

    private let cardView = UIView()
    private let memoryImageView = UIImageView()

    private let detailContainer = UIView()
    private let avatarImageView = UIImageView()
    private let titleLabel = UILabel()
    private let authorLabel = UILabel()
    private let timeLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear

        // Card
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = .white
        cardView.layer.cornerRadius = 28
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.06
        cardView.layer.shadowOffset = CGSize(width: 0, height: 10)
        cardView.layer.shadowRadius = 20
        cardView.layer.masksToBounds = false

        contentView.addSubview(cardView)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        // Image
        memoryImageView.translatesAutoresizingMaskIntoConstraints = false
        memoryImageView.contentMode = .scaleAspectFill
        memoryImageView.clipsToBounds = true
        memoryImageView.layer.cornerRadius = 28
        memoryImageView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

        // Detail Container
        detailContainer.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.backgroundColor = .white
        detailContainer.layer.cornerRadius = 28
        detailContainer.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]

        // Avatar
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.layer.cornerRadius = 22
        avatarImageView.backgroundColor = UIColor.systemGray5
        avatarImageView.layer.shadowColor = UIColor.black.cgColor
        avatarImageView.layer.shadowOpacity = 0.1
        avatarImageView.layer.shadowOffset = CGSize(width: 0, height: 4)
        avatarImageView.layer.shadowRadius = 6

        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .black
        titleLabel.numberOfLines = 2

        // Author
        authorLabel.translatesAutoresizingMaskIntoConstraints = false
        authorLabel.font = .systemFont(ofSize: 15, weight: .medium)
        authorLabel.textColor = .darkGray

        // Time
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = .systemFont(ofSize: 13, weight: .regular)
        timeLabel.textColor = .gray

        cardView.addSubview(memoryImageView)
        cardView.addSubview(detailContainer)

        detailContainer.addSubview(avatarImageView)
        detailContainer.addSubview(titleLabel)
        detailContainer.addSubview(authorLabel)
        detailContainer.addSubview(timeLabel)

        NSLayoutConstraint.activate([
            memoryImageView.topAnchor.constraint(equalTo: cardView.topAnchor),
            memoryImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            memoryImageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            memoryImageView.heightAnchor.constraint(equalTo: cardView.heightAnchor, multiplier: 0.65),

            detailContainer.topAnchor.constraint(equalTo: memoryImageView.bottomAnchor),
            detailContainer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            detailContainer.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            detailContainer.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),

            avatarImageView.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor, constant: 18),
            avatarImageView.topAnchor.constraint(equalTo: detailContainer.topAnchor, constant: 18),
            avatarImageView.widthAnchor.constraint(equalToConstant: 44),
            avatarImageView.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.topAnchor.constraint(equalTo: detailContainer.topAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: detailContainer.trailingAnchor, constant: -18),

            authorLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            authorLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),

            timeLabel.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: 4),
            timeLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            timeLabel.bottomAnchor.constraint(lessThanOrEqualTo: detailContainer.bottomAnchor, constant: -18)
        ])
    }

    func configure(prompt: String, author: String, imageURL: String?) {
        titleLabel.text = prompt
        authorLabel.text = author
        timeLabel.text = "2 days ago"

        avatarImageView.image = UIImage(systemName: "person.circle.fill")
        memoryImageView.image = UIImage(systemName: "photo")

        guard let imageURL = imageURL,
              let url = URL(string: imageURL) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.memoryImageView.alpha = 0
                self?.memoryImageView.image = image
                UIView.animate(withDuration: 0.3) {
                    self?.memoryImageView.alpha = 1
                }
            }
        }.resume()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        memoryImageView.image = nil
        avatarImageView.image = nil
        titleLabel.text = nil
        authorLabel.text = nil
        timeLabel.text = nil
    }
}
