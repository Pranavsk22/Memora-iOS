//
//  PremiumSubscriptionViewController.swift
//  Memora
//
//  Created by user@3 on 01/02/26.
//

import UIKit

final class PremiumSubscriptionViewController: UIViewController {

    // MARK: - Models
    struct Plan {
        let title: String
        let priceLine: String
        let subtitle: String
    }

    private enum PlanType: Int, CaseIterable {
        case starter
        case pro
        case elite
    }

    // MARK: - Data
    private let plans: [PlanType: Plan] = [
        .starter: Plan(title: "Starter : 50 GB", priceLine: "₹ 75.00 a month", subtitle: "Add upto 3 members to your family"),
        .pro:     Plan(title: "Pro : 200 GB",    priceLine: "₹ 149.00 a month", subtitle: "Add upto 5 members to your family"),
        .elite:   Plan(title: "Elite : 2 TB",    priceLine: "₹ 299.00 a month", subtitle: "Unlimited family members")
    ]

    private var selectedPlan: PlanType = .starter {
        didSet { updateSelectionUI() }
    }

    // MARK: - UI
    private let closeButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setImage(UIImage(systemName: "xmark"), for: .normal)
        b.tintColor = .label
        b.backgroundColor = .secondarySystemBackground
        b.layer.cornerRadius = 18
        b.clipsToBounds = true
        return b
    }()

    private let scrollView: UIScrollView = {
        let s = UIScrollView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.alwaysBounceVertical = true
        s.showsVerticalScrollIndicator = false
        return s
    }()

    private let contentView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.image = UIImage(named: "AppIcon") ?? UIImage(systemName: "crown.fill")
        iv.tintColor = .label
        iv.layer.cornerRadius = 18
        iv.clipsToBounds = true
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = "More Storage and\nPowerful Features"
        l.numberOfLines = 0
        l.textAlignment = .center
        l.font = .systemFont(ofSize: 28, weight: .heavy)
        return l
    }()

    private let underlineView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .systemBlue
        v.layer.cornerRadius = 2
        return v
    }()

    private let descriptionLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.textAlignment = .center
        l.numberOfLines = 0
        l.textColor = .secondaryLabel
        l.font = .systemFont(ofSize: 15, weight: .regular)
        l.text =
        """
        Get more storage with Memora+ to save
        your photos, videos, legacies and more,
        along with enhanced privacy features to
        protect you and your data. It’s all the power
        of Memora Plus.
        """
        return l
    }()

    private let plansStack: UIStackView = {
        let s = UIStackView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.axis = .vertical
        s.spacing = 14
        return s
    }()

    // Footer pinned
    private let footerContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .systemBackground
        v.layer.cornerRadius = 24
        v.clipsToBounds = true
        return v
    }()

    private let footerTextLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.textAlignment = .center
        l.numberOfLines = 0
        l.textColor = .secondaryLabel
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.text =
        """
        All plans can be shared with family members. Plan auto renews
        for your subscription until canceled.
        """
        return l
    }()

    private let upgradeButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle("Upgrade", for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        b.backgroundColor = .systemBlue
        b.layer.cornerRadius = 24
        b.clipsToBounds = true
        return b
    }()

    private let notNowButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle("Not Now", for: .normal)
        b.setTitleColor(.label, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        b.backgroundColor = .secondarySystemBackground
        b.layer.cornerRadius = 24
        b.clipsToBounds = true
        return b
    }()

    private var planCards: [PlanType: PlanCardView] = [:]

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        buildUI()
        wireActions()
        updateSelectionUI()
    }

    // MARK: - UI
    private func buildUI() {
        // top controls
        view.addSubview(closeButton)
        view.addSubview(scrollView)
        view.addSubview(footerContainer)

        scrollView.addSubview(contentView)

        // content
        contentView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(underlineView)
        contentView.addSubview(descriptionLabel)
        contentView.addSubview(plansStack)

        // footer
        footerContainer.addSubview(footerTextLabel)
        footerContainer.addSubview(upgradeButton)
        footerContainer.addSubview(notNowButton)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36),

            footerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            footerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            footerContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            scrollView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: footerContainer.topAnchor, constant: -12),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            iconImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            iconImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 86),
            iconImageView.heightAnchor.constraint(equalToConstant: 86),

            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            underlineView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            underlineView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            underlineView.widthAnchor.constraint(equalToConstant: 220),
            underlineView.heightAnchor.constraint(equalToConstant: 4),

            descriptionLabel.topAnchor.constraint(equalTo: underlineView.bottomAnchor, constant: 18),
            descriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 36),
            descriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -36),

            plansStack.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 22),
            plansStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            plansStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            plansStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),

            footerTextLabel.topAnchor.constraint(equalTo: footerContainer.topAnchor, constant: 14),
            footerTextLabel.leadingAnchor.constraint(equalTo: footerContainer.leadingAnchor, constant: 18),
            footerTextLabel.trailingAnchor.constraint(equalTo: footerContainer.trailingAnchor, constant: -18),

            upgradeButton.topAnchor.constraint(equalTo: footerTextLabel.bottomAnchor, constant: 16),
            upgradeButton.leadingAnchor.constraint(equalTo: footerContainer.leadingAnchor, constant: 18),
            upgradeButton.trailingAnchor.constraint(equalTo: footerContainer.trailingAnchor, constant: -18),
            upgradeButton.heightAnchor.constraint(equalToConstant: 56),

            notNowButton.topAnchor.constraint(equalTo: upgradeButton.bottomAnchor, constant: 12),
            notNowButton.leadingAnchor.constraint(equalTo: footerContainer.leadingAnchor, constant: 18),
            notNowButton.trailingAnchor.constraint(equalTo: footerContainer.trailingAnchor, constant: -18),
            notNowButton.heightAnchor.constraint(equalToConstant: 56),
            notNowButton.bottomAnchor.constraint(equalTo: footerContainer.bottomAnchor, constant: -14)
        ])

        // plan cards
        for type in PlanType.allCases {
            guard let plan = plans[type] else { continue }

            let card = PlanCardView(plan: plan)
            card.translatesAutoresizingMaskIntoConstraints = false

            card.onTap = { [weak self] in
                self?.selectedPlan = type
            }

            plansStack.addArrangedSubview(card)
            planCards[type] = card
        }
    }

    private func wireActions() {
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        notNowButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        upgradeButton.addTarget(self, action: #selector(upgradeTapped), for: .touchUpInside)
    }

    private func updateSelectionUI() {
        for (type, card) in planCards {
            card.setSelected(type == selectedPlan)
        }
    }

    // MARK: - Actions
    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func upgradeTapped() {
        let selected = plans[selectedPlan]?.title ?? "Plan"
        let alert = UIAlertController(title: "Upgrade", message: "Selected: \(selected)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Plan Card
private final class PlanCardView: UIControl {

    var onTap: (() -> Void)?

    private let container: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.secondarySystemBackground
        v.layer.cornerRadius = 16
        v.clipsToBounds = true
        return v
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 18, weight: .bold)
        l.textColor = .label
        return l
    }()

    private let priceLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 16, weight: .semibold)
        l.textColor = .label
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.textColor = .secondaryLabel
        l.numberOfLines = 0
        return l
    }()

    private let radioImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.tintColor = UIColor.systemBlue
        return iv
    }()

    init(plan: PremiumSubscriptionViewController.Plan) {
        super.init(frame: .zero)

        isAccessibilityElement = true
        accessibilityTraits = .button

        addSubview(container)
        container.addSubview(titleLabel)
        container.addSubview(priceLabel)
        container.addSubview(subtitleLabel)
        container.addSubview(radioImageView)

        titleLabel.text = plan.title
        priceLabel.text = plan.priceLine
        subtitleLabel.text = plan.subtitle

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),

            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: radioImageView.leadingAnchor, constant: -12),

            priceLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            priceLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            priceLabel.trailingAnchor.constraint(lessThanOrEqualTo: radioImageView.leadingAnchor, constant: -12),

            subtitleLabel.topAnchor.constraint(equalTo: priceLabel.bottomAnchor, constant: 10),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            subtitleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),

            radioImageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            radioImageView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            radioImageView.widthAnchor.constraint(equalToConstant: 22),
            radioImageView.heightAnchor.constraint(equalToConstant: 22)
        ])

        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        setSelected(false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func tapped() {
        onTap?()
    }

    func setSelected(_ selected: Bool) {
        if selected {
            container.layer.borderWidth = 2
            container.layer.borderColor = UIColor.systemBlue.cgColor
            radioImageView.image = UIImage(systemName: "checkmark.circle.fill")
            accessibilityValue = "Selected"
        } else {
            container.layer.borderWidth = 0
            container.layer.borderColor = UIColor.clear.cgColor
            radioImageView.image = UIImage(systemName: "circle")
            accessibilityValue = nil
        }
    }
}
