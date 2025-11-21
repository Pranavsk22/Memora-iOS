import UIKit

final class MemoryCategoryTableViewCell: UITableViewCell {
    static let reuseId = "MemoryCategoryCell" // ensure this matches your XIB reuse identifier

    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var countLabel: UILabel!

    override func awakeFromNib() {
           super.awakeFromNib()
           backgroundColor = .clear
           iconImageView.layer.cornerRadius = 12
           iconImageView.clipsToBounds = true
           iconImageView.contentMode = .scaleAspectFill

           titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .regular)
           countLabel.font = UIFont.systemFont(ofSize: 14)
           countLabel.textColor = UIColor(white: 0.6, alpha: 1)
       }

       override func prepareForReuse() {
           super.prepareForReuse()
           iconImageView.image = nil
           titleLabel.text = nil
           countLabel.text = nil
       }

       /// Configure cell. `iconName` should be the asset name in your asset catalog (e.g. "cat_recipes")
       func configure(iconName: String?, title: String, count: Int) {
           titleLabel.text = title
           countLabel.text = "\(count)"

           // Try loading from asset catalog first
           if let name = iconName, let img = UIImage(named: name) {
               iconImageView.image = img
               return
           }

           // fallback: try .png/.jpg in bundle
           if let name = iconName {
               let bundle = Bundle.main
               if let png = bundle.path(forResource: name, ofType: "png"),
                  let img = UIImage(contentsOfFile: png) {
                   iconImageView.image = img
                   return
               }
               if let jpg = bundle.path(forResource: name, ofType: "jpg"),
                  let img = UIImage(contentsOfFile: jpg) {
                   iconImageView.image = img
                   return
               }
           }

           // final fallback
           iconImageView.image = UIImage(systemName: "photo")
           // Debug hint (remove in production)
           #if DEBUG
           if let name = iconName {
               print("MemoryCategoryTableViewCell: could not load icon named '\(name)'. Check asset name and target membership.")
           }
           #endif
       }
   }
