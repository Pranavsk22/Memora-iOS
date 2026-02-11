import UIKit

class FamilyMemberCollectionViewCell: UICollectionViewCell {

    private let imageView = UIImageView()
    private let nameLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear

        contentView.backgroundColor = .white
        contentView.layer.cornerRadius = 20
        contentView.layer.masksToBounds = true

        layer.shadowColor = UIColor.black.withAlphaComponent(0.10).cgColor
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 10
        layer.shadowOpacity = 1
        layer.masksToBounds = false

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 16
        imageView.clipsToBounds = true

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 14, weight: .medium)
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 2

        contentView.addSubview(imageView)
        contentView.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),

            nameLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            nameLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8)
        ])
    }

    func configure(name: String, image: UIImage?) {
        nameLabel.text = name
        imageView.image = image
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        nameLabel.text = nil
    }
}
