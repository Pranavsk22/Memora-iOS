import UIKit

/// Photos-style bottom sheet for a Memory (big actions + list + cancel).
final class MemoryOptionsSheetViewController: UIViewController {

    // MARK: - Public callbacks & data
    var memory: Memory!
    var onDelete: ((Memory) -> Void)?
    var onEdit: ((Memory) -> Void)?
    var onView: ((Memory) -> Void)?
    var onShare: ((Memory) -> Void)?

    // Local placeholder path (uploaded in conversation)
    private let placeholderPath = "/mnt/data/Screenshot 2025-11-20 at 11.41.23 AM.png"

    // MARK: - Views
    private let dimView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(white: 0, alpha: 0.25)
        v.alpha = 0
        return v
    }()

    // The frosted card container (we'll add a blur view inside for that thick-surface look)
    private let cardContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.layer.cornerRadius = 28
        v.layer.masksToBounds = false
        // shadow gives that lifted card look like Photos
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.18
        v.layer.shadowRadius = 20
        v.layer.shadowOffset = CGSize(width: 0, height: 8)
        return v
    }()

    private let cardBlur: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemThinMaterial)
        let v = UIVisualEffectView(effect: blur)
        v.layer.cornerRadius = 28
        v.clipsToBounds = true
        return v
    }()

    // content stack within card
    private let contentStack = UIStackView()
    private let topActionStack = UIStackView()
    private let listStack = UIStackView()

    // preview image (rounded rectangle)
    private let previewImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 12
        iv.backgroundColor = UIColor(white: 0.95, alpha: 1)
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.heightAnchor.constraint(equalToConstant: 140).isActive = true
        return iv
    }()

    // Cancel button (separate floating button)
    private let cancelButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Cancel", for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        b.setTitleColor(.systemBlue, for: .normal)
        b.backgroundColor = UIColor(white: 1, alpha: 0.0001) // transparent, keeps tappable area
        b.layer.cornerRadius = 16
        b.layer.masksToBounds = true
        return b
    }()

    // layout
    private var cardBottomConstraint: NSLayoutConstraint!

    // MARK: - Init
    init(memory: Memory) {
        self.memory = memory
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupViews()
        loadPreview()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIn()
    }

    // MARK: - Setup
    private func setupViews() {
        // dim behind
        view.addSubview(dimView)
        dimView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        let dimTap = UITapGestureRecognizer(target: self, action: #selector(dismissTapped))
        dimView.addGestureRecognizer(dimTap)

        // card container + blur inside
        view.addSubview(cardContainer)
        cardContainer.translatesAutoresizingMaskIntoConstraints = false
        cardBottomConstraint = cardContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 420) // start off screen
        NSLayoutConstraint.activate([
            cardContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            cardContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            cardBottomConstraint
        ])

        cardContainer.addSubview(cardBlur)
        cardBlur.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cardBlur.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor),
            cardBlur.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor),
            cardBlur.topAnchor.constraint(equalTo: cardContainer.topAnchor),
            cardBlur.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor)
        ])

        // content stack inside blur
        cardBlur.contentView.addSubview(contentStack)
        contentStack.axis = .vertical
        contentStack.spacing = 12
        contentStack.alignment = .fill
        contentStack.distribution = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        contentStack.isLayoutMarginsRelativeArrangement = true

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: cardBlur.contentView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: cardBlur.contentView.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: cardBlur.contentView.topAnchor),
        ])

        // preview (top)
        contentStack.addArrangedSubview(previewImageView)

        // top action stack (three circular buttons)
        topActionStack.axis = .horizontal
        topActionStack.alignment = .center
        topActionStack.distribution = .equalSpacing
        topActionStack.spacing = 28
        topActionStack.translatesAutoresizingMaskIntoConstraints = false
        topActionStack.heightAnchor.constraint(equalToConstant: 110).isActive = true
        contentStack.addArrangedSubview(topActionStack)

        // listStack
        listStack.axis = .vertical
        listStack.alignment = .fill
        listStack.distribution = .fill
        listStack.spacing = 8
        contentStack.addArrangedSubview(listStack)

        // add big actions & list rows
        buildTopActions()
        buildListRows()

        // Cancel button below the card (floating)
        view.addSubview(cancelButton)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cancelButton.topAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: 12),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cancelButton.heightAnchor.constraint(equalToConstant: 56),
            cancelButton.widthAnchor.constraint(equalTo: cardContainer.widthAnchor, multiplier: 0.65),
            cancelButton.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        ])
        cancelButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
    }

    // MARK: - Build UI pieces
    private func buildTopActions() {
        topActionStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Helper: circular button with icon and label
        func circleAction(systemName: String, title: String, tint: UIColor = .label, handler: @escaping (UIControl) -> Void) -> UIControl {
            let control = UIControl()
            control.translatesAutoresizingMaskIntoConstraints = false
            control.widthAnchor.constraint(equalToConstant: 84).isActive = true
            control.heightAnchor.constraint(equalToConstant: 110).isActive = true

            // circular background blur
            let bg = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
            bg.layer.cornerRadius = 36
            bg.clipsToBounds = true
            bg.translatesAutoresizingMaskIntoConstraints = false
            control.addSubview(bg)

            NSLayoutConstraint.activate([
                bg.centerXAnchor.constraint(equalTo: control.centerXAnchor),
                bg.topAnchor.constraint(equalTo: control.topAnchor),
                bg.widthAnchor.constraint(equalToConstant: 72),
                bg.heightAnchor.constraint(equalToConstant: 72)
            ])

            // icon inside
            let iv = UIImageView(image: UIImage(systemName: systemName))
            iv.tintColor = tint
            iv.contentMode = .center
            iv.translatesAutoresizingMaskIntoConstraints = false
            bg.contentView.addSubview(iv)
            NSLayoutConstraint.activate([
                iv.leadingAnchor.constraint(equalTo: bg.contentView.leadingAnchor),
                iv.trailingAnchor.constraint(equalTo: bg.contentView.trailingAnchor),
                iv.topAnchor.constraint(equalTo: bg.contentView.topAnchor),
                iv.bottomAnchor.constraint(equalTo: bg.contentView.bottomAnchor)
            ])

            // label
            let lbl = UILabel()
            lbl.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            lbl.textAlignment = .center
            lbl.textColor = .label
            lbl.text = title
            lbl.translatesAutoresizingMaskIntoConstraints = false
            control.addSubview(lbl)
            NSLayoutConstraint.activate([
                lbl.topAnchor.constraint(equalTo: bg.bottomAnchor, constant: 8),
                lbl.centerXAnchor.constraint(equalTo: control.centerXAnchor)
            ])

            control.addAction(UIAction { _ in handler(control) }, for: .touchUpInside)
            return control
        }

        let share = circleAction(systemName: "square.and.arrow.up", title: "Share") { [weak self] _ in
            guard let s = self else { return }
            s.onShare?(s.memory)
            s.dismissAnimated()
        }

        let favorite = circleAction(systemName: "heart", title: "Favorite") { [weak self] control in
            guard let s = self else { return }
            s.animateTempHeartFill(button: control)
            s.onEdit?(s.memory)
            // keep sheet open
        }

        let delete = circleAction(systemName: "trash", title: "Delete", tint: .systemRed) { [weak self] _ in
            self?.confirmDelete()
        }

        topActionStack.addArrangedSubview(share)
        topActionStack.addArrangedSubview(favorite)
        topActionStack.addArrangedSubview(delete)
    }

    private func buildListRows() {
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        func row(title: String, icon: String?, tint: UIColor = .label, action: @escaping () -> Void) -> UIView {
            let control = UIControl()
            control.translatesAutoresizingMaskIntoConstraints = false
            control.heightAnchor.constraint(equalToConstant: 64).isActive = true

            let h = UIStackView()
            h.axis = .horizontal
            h.alignment = .center
            h.spacing = 12
            h.translatesAutoresizingMaskIntoConstraints = false

            if let ic = icon {
                let iv = UIImageView(image: UIImage(systemName: ic))
                iv.tintColor = tint
                iv.translatesAutoresizingMaskIntoConstraints = false
                iv.widthAnchor.constraint(equalToConstant: 28).isActive = true
                iv.heightAnchor.constraint(equalToConstant: 28).isActive = true
                h.addArrangedSubview(iv)
            } else {
                let spacer = UIView()
                spacer.widthAnchor.constraint(equalToConstant: 28).isActive = true
                h.addArrangedSubview(spacer)
            }

            let lbl = UILabel()
            lbl.text = title
            lbl.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
            lbl.textColor = .label
            h.addArrangedSubview(lbl)

            h.addArrangedSubview(UIView()) // flexible space

            control.addSubview(h)
            NSLayoutConstraint.activate([
                h.leadingAnchor.constraint(equalTo: control.leadingAnchor, constant: 12),
                h.trailingAnchor.constraint(equalTo: control.trailingAnchor, constant: -12),
                h.centerYAnchor.constraint(equalTo: control.centerYAnchor)
            ])

            // add separator line below each row (except maybe last)
            let sep = UIView()
            sep.backgroundColor = UIColor(white: 0.85, alpha: 0.8)
            sep.translatesAutoresizingMaskIntoConstraints = false
            control.addSubview(sep)
            NSLayoutConstraint.activate([
                sep.leadingAnchor.constraint(equalTo: control.leadingAnchor, constant: 12),
                sep.trailingAnchor.constraint(equalTo: control.trailingAnchor, constant: -12),
                sep.bottomAnchor.constraint(equalTo: control.bottomAnchor),
                sep.heightAnchor.constraint(equalToConstant: 0.5)
            ])

            control.addAction(UIAction { _ in action() }, for: .touchUpInside)
            return control
        }

        // Copy
        listStack.addArrangedSubview(row(title: "Copy", icon: "doc.on.doc") { [weak self] in
            guard let s = self, let mem = s.memory else { return }
            UIPasteboard.general.string = mem.title + "\n" + (mem.body ?? "")
            s.dismissAnimated()
        })

        // Duplicate
        listStack.addArrangedSubview(row(title: "Duplicate", icon: "plus.square.on.square") { [weak self] in
            guard let s = self, let mem = s.memory else { return }
            var copy = mem
            copy.id = UUID().uuidString
            MemoryStore.shared.add(copy) { _ in
                DispatchQueue.main.async { s.dismissAnimated() }
            }
        })

        // Hide
        listStack.addArrangedSubview(row(title: "Hide", icon: "eye.slash") { [weak self] in
            guard let s = self else { return }
            s.onEdit?(s.memory)
            s.dismissAnimated()
        })

        // Add to Album
        listStack.addArrangedSubview(row(title: "Add to Album", icon: "folder.badge.plus") { [weak self] in
            guard let s = self else { return }
            // hook your album flow here
            s.dismissAnimated()
        })
    }

    // MARK: - Load preview
    private func loadPreview() {
        if let att = memory.attachments.first(where: { $0.kind == .image }) {
            let fname = att.filename
            if fname.lowercased().hasPrefix("http"), let url = URL(string: fname) {
                DispatchQueue.global(qos: .userInitiated).async {
                    if let d = try? Data(contentsOf: url), let img = UIImage(data: d) {
                        DispatchQueue.main.async { self.previewImageView.image = img }
                    } else {
                        self.loadPlaceholder()
                    }
                }
            } else {
                let url = MemoryStore.shared.urlForAttachment(filename: fname)
                if let d = try? Data(contentsOf: url), let img = UIImage(data: d) {
                    previewImageView.image = img
                } else {
                    loadPlaceholder()
                }
            }
        } else {
            loadPlaceholder()
        }
    }

    private func loadPlaceholder() {
        let path = placeholderPath
        let url = URL(fileURLWithPath: path)
        if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
            previewImageView.image = img
        } else {
            previewImageView.image = UIImage(systemName: "photo")
        }
    }

    // MARK: - Animations & Actions
    @objc private func dismissTapped() {
        dismissAnimated()
    }

    private func animateIn() {
        view.layoutIfNeeded()
        // animate dim + card up
        cardBottomConstraint.constant = -12 - view.safeAreaInsets.bottom
        UIView.animate(withDuration: 0.32, delay: 0, usingSpringWithDamping: 0.86, initialSpringVelocity: 0.8, options: .curveEaseOut) {
            self.dimView.alpha = 1
            self.view.layoutIfNeeded()
        }
    }

    private func dismissAnimated(completion: (() -> Void)? = nil) {
        cardBottomConstraint.constant = 420
        UIView.animate(withDuration: 0.22, animations: {
            self.dimView.alpha = 0
            self.view.layoutIfNeeded()
        }, completion: { _ in
            completion?()
            self.dismiss(animated: false, completion: nil)
        })
    }

    private func confirmDelete() {
        guard let mem = memory else { return }
        let confirm = UIAlertController(title: "Delete memory?", message: "This will remove the memory and its local attachments.", preferredStyle: .alert)
        confirm.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
            MemoryStore.shared.deleteMemory(id: mem.id) { [weak self] res in
                DispatchQueue.main.async {
                    switch res {
                    case .success:
                        self?.onDelete?(mem)
                        self?.dismissAnimated()
                    case .failure(let err):
                        let errAc = UIAlertController(title: "Error", message: err.localizedDescription, preferredStyle: .alert)
                        errAc.addAction(UIAlertAction(title: "OK", style: .default))
                        self?.present(errAc, animated: true)
                    }
                }
            }
        }))
        confirm.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(confirm, animated: true)
    }

    private func animateTempHeartFill(button: UIControl) {
        // small scale animation to indicate toggle; it's visual only here
        UIView.animate(withDuration: 0.12, animations: {
            button.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }, completion: { _ in
            UIView.animate(withDuration: 0.12) {
                button.transform = .identity
            }
        })
    }
}
