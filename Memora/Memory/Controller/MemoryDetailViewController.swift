//
// MemoryDetailViewController.swift
// Programmatic Memory detail page with collage + audio rows + improved image preview
//

import UIKit
import AVFoundation

final class MemoryDetailViewController: UIViewController {

    // MARK: - Public model
    private let memory: Memory

    // MARK: - UI
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let headerStack = UIStackView()
    private let avatarImageView = UIImageView()
    private let ownerLabel = UILabel()

    private let bodyLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        l.textColor = .label
        l.numberOfLines = 0
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        l.textColor = .secondaryLabel
        l.numberOfLines = 0
        return l
    }()

    private let imagesContainer = UIView()
    /// fixed height to keep consistent look across counts
    private var imagesContainerHeightConstraint: NSLayoutConstraint!

    // Audio stack: contains one AudioRowView per audio attachment
    private let audioStack = UIStackView()

    // Helpers
    private var imageViews: [UIImageView] = []
    private var audioRows: [AudioRowView] = []

    // Derived list of image path/url strings
    private lazy var imageURLStrings: [String] = {
        memory.attachments.filter { $0.kind == .image }.map { $0.filename.trimmingCharacters(in: .whitespacesAndNewlines) }
    }()

    // MARK: - Init
    init(memory: Memory) {
        self.memory = memory
        super.init(nibName: nil, bundle: nil)
        self.title = "Memory"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupNavigationBar()
        setupViews()
        layoutForImages()
        setupAudioRows()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // stop all audio rows when leaving
        audioRows.forEach { $0.stop() }
    }

    // MARK: - Navigation Bar
    private func setupNavigationBar() {
        let ellipsis = UIImage(systemName: "ellipsis")
        let barItem = UIBarButtonItem(image: ellipsis, style: .plain, target: self, action: #selector(didTapEllipsis(_:)))
        navigationItem.rightBarButtonItem = barItem
        navigationController?.navigationBar.prefersLargeTitles = false
    }

    @objc private func didTapEllipsis(_ sender: UIBarButtonItem) {
        // Haptic for opening menu (light)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        // Edit action with icon & haptic
        let edit = UIAlertAction(title: " Edit", style: .default) { [weak self] _ in
            // medium impact to indicate a navigation/edit action
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            self?.openEditWithSmoothTransition()
        }
        edit.setValue(UIImage(systemName: "pencil"), forKey: "image")
        // align left spacing (small hack)
        edit.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
        sheet.addAction(edit)

        // Delete action with icon & haptic
        let delete = UIAlertAction(title: " Delete", style: .destructive) { [weak self] _ in
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            self?.confirmDeletion()
        }
        delete.setValue(UIImage(systemName: "trash"), forKey: "image")
        delete.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
        sheet.addAction(delete)

        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        sheet.addAction(cancel)

        if let p = sheet.popoverPresentationController { p.barButtonItem = sender }
        present(sheet, animated: true, completion: nil)
    }

    // MARK: - Edit + smooth transition
    private func openEditWithSmoothTransition() {
        // Ensure MemoryEditViewController initializer exists: MemoryEditViewController(memory: Memory)
        let editVC = MemoryEditViewController(memory: memory)
        // Hide the default back button in the edit screen
        editVC.navigationItem.hidesBackButton = true

        // Add a custom smooth push transition (CATransition)
        guard let nav = navigationController else {
            // fallback to present if no nav controller
            let navWrap = UINavigationController(rootViewController: editVC)
            navWrap.modalPresentationStyle = .fullScreen
            present(navWrap, animated: true, completion: nil)
            return
        }

        let transition = CATransition()
        transition.duration = 0.34
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        transition.type = CATransitionType.push
        transition.subtype = CATransitionSubtype.fromRight
        nav.view.layer.add(transition, forKey: kCATransition)

        nav.pushViewController(editVC, animated: false)
    }

    // MARK: - Deletion
    private func confirmDeletion() {
        let a = UIAlertController(title: "Delete Memory", message: "Are you sure you want to delete this memory? This will remove attachments stored locally.", preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        a.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            // strong heavy haptic indicating destructive action
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            self?.performDeletion()
        }))
        present(a, animated: true, completion: nil)
    }

    private func performDeletion() {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.color = .secondaryLabel
        view.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        indicator.startAnimating()

        MemoryStore.shared.deleteMemory(id: memory.id) { [weak self] result in
            DispatchQueue.main.async {
                indicator.stopAnimating()
                indicator.removeFromSuperview()
            }
            switch result {
            case .success:
                // success light haptic feedback
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                NotificationCenter.default.post(name: .memoriesUpdated, object: nil)
                DispatchQueue.main.async { self?.navigationController?.popViewController(animated: true) }
            case .failure(let err):
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Delete Failed", message: "Unable to delete memory: \(err.localizedDescription)", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }
    }

    // MARK: - Setup UI
    private func setupViews() {
        // Scroll setup
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

            // Important for vertical scrolling: match width
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        // header (avatar + owner)
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 12
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.layer.cornerRadius = 20
        avatarImageView.clipsToBounds = true
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.backgroundColor = UIColor(white: 0.9, alpha: 1)

        // use Session current user
        let sessionUser = Session.shared.currentUser
        if let avatar = sessionUser.avatarName, let img = UIImage(named: avatar) {
            avatarImageView.image = img
        } else {
            avatarImageView.image = UIImage(systemName: "person.crop.circle.fill")
            avatarImageView.tintColor = .systemBlue
        }

        ownerLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        ownerLabel.textColor = .label
        ownerLabel.text = sessionUser.name

        headerStack.addArrangedSubview(avatarImageView)
        headerStack.addArrangedSubview(ownerLabel)

        contentView.addSubview(headerStack)
        headerStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18).isActive = true
        headerStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12).isActive = true

        NSLayoutConstraint.activate([
            avatarImageView.widthAnchor.constraint(equalToConstant: 40),
            avatarImageView.heightAnchor.constraint(equalToConstant: 40)
        ])

        // Body
        contentView.addSubview(bodyLabel)
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.text = memory.title

        contentView.addSubview(subtitleLabel)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = memory.body

        // Images container
        contentView.addSubview(imagesContainer)
        imagesContainer.translatesAutoresizingMaskIntoConstraints = false
        imagesContainer.layer.masksToBounds = false

        // fixed container height — avoid images expanding unexpectedly
        imagesContainerHeightConstraint = imagesContainer.heightAnchor.constraint(equalToConstant: 260)
        imagesContainerHeightConstraint.isActive = true

        // Audio stack
        audioStack.axis = .vertical
        audioStack.spacing = 12
        audioStack.alignment = .fill
        audioStack.distribution = .fill
        audioStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(audioStack)

        NSLayoutConstraint.activate([
            bodyLabel.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 18),
            bodyLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            bodyLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            subtitleLabel.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            imagesContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 18),
            imagesContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            imagesContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            audioStack.topAnchor.constraint(equalTo: imagesContainer.bottomAnchor, constant: 22),
            audioStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            audioStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            audioStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -28)
        ])
    }

    // MARK: - Images layout logic
    private func layoutForImages() {
        imagesContainer.subviews.forEach { $0.removeFromSuperview() }
        imageViews.removeAll()

        let imageAttachments = memory.attachments.filter { $0.kind == .image }
        let imageCount = imageAttachments.count

        func makeImageView() -> UIImageView {
            let iv = UIImageView()
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.contentMode = .scaleAspectFill
            iv.clipsToBounds = true
            iv.layer.cornerRadius = 12
            iv.backgroundColor = UIColor(white: 0.95, alpha: 1)
            imageViews.append(iv)
            return iv
        }

        // If no images, set height 0
        if imageCount == 0 {
            imagesContainerHeightConstraint.constant = 0
            return
        }

        // Keep a consistent container height for all cases
        let containerH: CGFloat = 260
        imagesContainerHeightConstraint.constant = containerH

        // spacing between cells (reduced)
        let spacing: CGFloat = 8

        switch imageCount {
        case 1:
            // single full width image
            let iv = makeImageView()
            imagesContainer.addSubview(iv)
            NSLayoutConstraint.activate([
                iv.topAnchor.constraint(equalTo: imagesContainer.topAnchor),
                iv.leadingAnchor.constraint(equalTo: imagesContainer.leadingAnchor),
                iv.trailingAnchor.constraint(equalTo: imagesContainer.trailingAnchor),
                iv.bottomAnchor.constraint(equalTo: imagesContainer.bottomAnchor)
            ])
            setImage(for: iv, from: imageAttachments[0].filename)
            addTap(to: iv, index: 0)

        case 2:
            // two side-by-side arranged to visually match grid cells (top row)
            let left = makeImageView()
            let right = makeImageView()
            imagesContainer.addSubview(left)
            imagesContainer.addSubview(right)

            // Both top images occupy the top half of the container; we keep bottom placeholders invisible to preserve layout
            NSLayoutConstraint.activate([
                left.topAnchor.constraint(equalTo: imagesContainer.topAnchor),
                left.leadingAnchor.constraint(equalTo: imagesContainer.leadingAnchor),
                left.trailingAnchor.constraint(equalTo: right.leadingAnchor, constant: -spacing),
                left.heightAnchor.constraint(equalTo: imagesContainer.heightAnchor, multiplier: 0.5, constant: -(spacing/2)),

                right.topAnchor.constraint(equalTo: imagesContainer.topAnchor),
                right.trailingAnchor.constraint(equalTo: imagesContainer.trailingAnchor),
                right.heightAnchor.constraint(equalTo: imagesContainer.heightAnchor, multiplier: 0.5, constant: -(spacing/2)),

                left.widthAnchor.constraint(equalTo: right.widthAnchor)
            ])

            // Add transparent bottom placeholders to keep grid look (hidden)
            let leftBottom = makeImageView(); let rightBottom = makeImageView()
            leftBottom.isHidden = true; rightBottom.isHidden = true
            imagesContainer.addSubview(leftBottom); imagesContainer.addSubview(rightBottom)

            NSLayoutConstraint.activate([
                leftBottom.topAnchor.constraint(equalTo: left.bottomAnchor, constant: spacing),
                leftBottom.leadingAnchor.constraint(equalTo: imagesContainer.leadingAnchor),
                leftBottom.bottomAnchor.constraint(equalTo: imagesContainer.bottomAnchor),
                leftBottom.trailingAnchor.constraint(equalTo: rightBottom.leadingAnchor, constant: -spacing),

                rightBottom.topAnchor.constraint(equalTo: right.bottomAnchor, constant: spacing),
                rightBottom.trailingAnchor.constraint(equalTo: imagesContainer.trailingAnchor),
                rightBottom.bottomAnchor.constraint(equalTo: imagesContainer.bottomAnchor),

                leftBottom.widthAnchor.constraint(equalTo: rightBottom.widthAnchor),
                leftBottom.widthAnchor.constraint(equalTo: left.widthAnchor)
            ])

            setImage(for: left, from: imageAttachments[0].filename)
            setImage(for: right, from: imageAttachments[1].filename)
            addTap(to: left, index: 0); addTap(to: right, index: 1)

        case 3:
            // left full column, right two stacked — widths tuned to 0.5 each to match grid balance
            let left = makeImageView()
            let rightTop = makeImageView()
            let rightBottom = makeImageView()

            imagesContainer.addSubview(left)
            imagesContainer.addSubview(rightTop)
            imagesContainer.addSubview(rightBottom)

            NSLayoutConstraint.activate([
                left.topAnchor.constraint(equalTo: imagesContainer.topAnchor),
                left.leadingAnchor.constraint(equalTo: imagesContainer.leadingAnchor),
                left.bottomAnchor.constraint(equalTo: imagesContainer.bottomAnchor),

                rightTop.topAnchor.constraint(equalTo: imagesContainer.topAnchor),
                rightTop.leadingAnchor.constraint(equalTo: left.trailingAnchor, constant: spacing),
                rightTop.trailingAnchor.constraint(equalTo: imagesContainer.trailingAnchor),

                rightBottom.topAnchor.constraint(equalTo: rightTop.bottomAnchor, constant: spacing),
                rightBottom.leadingAnchor.constraint(equalTo: left.trailingAnchor, constant: spacing),
                rightBottom.trailingAnchor.constraint(equalTo: imagesContainer.trailingAnchor),
                rightBottom.bottomAnchor.constraint(equalTo: imagesContainer.bottomAnchor),

                left.widthAnchor.constraint(equalTo: imagesContainer.widthAnchor, multiplier: 0.5, constant: -spacing/2),
                rightTop.heightAnchor.constraint(equalTo: rightBottom.heightAnchor),
                rightTop.heightAnchor.constraint(equalTo: imagesContainer.heightAnchor, multiplier: 0.5, constant: -(spacing/2))
            ])

            setImage(for: left, from: imageAttachments[0].filename)
            setImage(for: rightTop, from: imageAttachments[1].filename)
            setImage(for: rightBottom, from: imageAttachments[2].filename)
            addTap(to: left, index: 0); addTap(to: rightTop, index: 1); addTap(to: rightBottom, index: 2)

        default:
            // 4 or more: 2x2 grid.
            let topLeft = makeImageView()
            let topRight = makeImageView()
            let bottomLeft = makeImageView()
            let bottomRight = makeImageView()

            imagesContainer.addSubview(topLeft)
            imagesContainer.addSubview(topRight)
            imagesContainer.addSubview(bottomLeft)
            imagesContainer.addSubview(bottomRight)

            NSLayoutConstraint.activate([
                topLeft.topAnchor.constraint(equalTo: imagesContainer.topAnchor),
                topLeft.leadingAnchor.constraint(equalTo: imagesContainer.leadingAnchor),
                topLeft.trailingAnchor.constraint(equalTo: topRight.leadingAnchor, constant: -spacing),

                topRight.topAnchor.constraint(equalTo: imagesContainer.topAnchor),
                topRight.trailingAnchor.constraint(equalTo: imagesContainer.trailingAnchor),

                bottomLeft.topAnchor.constraint(equalTo: topLeft.bottomAnchor, constant: spacing),
                bottomLeft.leadingAnchor.constraint(equalTo: imagesContainer.leadingAnchor),
                bottomLeft.trailingAnchor.constraint(equalTo: bottomRight.leadingAnchor, constant: -spacing),
                bottomLeft.bottomAnchor.constraint(equalTo: imagesContainer.bottomAnchor),

                bottomRight.topAnchor.constraint(equalTo: topRight.bottomAnchor, constant: spacing),
                bottomRight.trailingAnchor.constraint(equalTo: imagesContainer.trailingAnchor),
                bottomRight.bottomAnchor.constraint(equalTo: imagesContainer.bottomAnchor),

                // equal widths/heights
                topLeft.widthAnchor.constraint(equalTo: topRight.widthAnchor),
                bottomLeft.widthAnchor.constraint(equalTo: bottomRight.widthAnchor),
                topLeft.widthAnchor.constraint(equalTo: bottomLeft.widthAnchor),

                topLeft.heightAnchor.constraint(equalTo: imagesContainer.heightAnchor, multiplier: 0.5, constant: -(spacing/2)),
                topRight.heightAnchor.constraint(equalTo: imagesContainer.heightAnchor, multiplier: 0.5, constant: -(spacing/2))
            ])

            setImage(for: topLeft, from: imageAttachments[0].filename)
            setImage(for: topRight, from: imageAttachments[1].filename)
            setImage(for: bottomLeft, from: imageAttachments[2].filename)
            setImage(for: bottomRight, from: imageAttachments[3].filename)

            addTap(to: topLeft, index: 0)
            addTap(to: topRight, index: 1)
            addTap(to: bottomLeft, index: 2)
            addTap(to: bottomRight, index: 3)

            if imageAttachments.count > 4 {
                let moreCount = imageAttachments.count - 4
                let overlay = UIView()
                overlay.translatesAutoresizingMaskIntoConstraints = false
                overlay.backgroundColor = UIColor(white: 0, alpha: 0.45)
                overlay.layer.cornerRadius = 12
                bottomRight.addSubview(overlay)
                NSLayoutConstraint.activate([
                    overlay.leadingAnchor.constraint(equalTo: bottomRight.leadingAnchor),
                    overlay.trailingAnchor.constraint(equalTo: bottomRight.trailingAnchor),
                    overlay.topAnchor.constraint(equalTo: bottomRight.topAnchor),
                    overlay.bottomAnchor.constraint(equalTo: bottomRight.bottomAnchor)
                ])

                let label = UILabel()
                label.translatesAutoresizingMaskIntoConstraints = false
                label.text = "+\(moreCount)"
                label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
                label.textColor = .white
                overlay.addSubview(label)
                NSLayoutConstraint.activate([
                    label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
                    label.centerYAnchor.constraint(equalTo: overlay.centerYAnchor)
                ])
            }
        }
    }

    private func addTap(to imageView: UIImageView, index: Int) {
        imageView.isUserInteractionEnabled = true
        let g = UITapGestureRecognizer(target: self, action: #selector(handleImageTap(_:)))
        imageView.addGestureRecognizer(g)
        imageView.tag = index
    }

    @objc private func handleImageTap(_ g: UITapGestureRecognizer) {
        guard let iv = g.view as? UIImageView else { return }
        let idx = iv.tag
        let preview = ImagePreviewPageViewController(images: imageURLStrings, initialIndex: idx)
        // Present over full screen so the preview controller can animate a blur of the background
        preview.modalPresentationStyle = .overFullScreen
        present(preview, animated: true, completion: nil)
    }

    // MARK: - Image loading helper
    private func setImage(for imageView: UIImageView, from pathOrUrlString: String) {
        imageView.image = nil
        imageView.backgroundColor = UIColor(white: 0.96, alpha: 1)

        ImageLoader.shared.loadImage(from: pathOrUrlString) { [weak imageView] img in
            DispatchQueue.main.async {
                guard let imgView = imageView else { return }
                UIView.transition(with: imgView, duration: 0.24, options: .transitionCrossDissolve, animations: {
                    imgView.image = img ?? UIImage(systemName: "photo")
                    imgView.backgroundColor = img == nil ? UIColor(white: 0.96, alpha: 1) : .clear
                }, completion: nil)
            }
        }
    }

    // MARK: - Audio: multi-audio rows
    private func setupAudioRows() {
        // Clear any existing rows
        audioStack.arrangedSubviews.forEach { audioStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        audioRows.removeAll()

        let audioAttachments = memory.attachments.filter { $0.kind == .audio }
        if audioAttachments.isEmpty { return }

        for (idx, att) in audioAttachments.enumerated() {
            let row = AudioRowView()
            row.translatesAutoresizingMaskIntoConstraints = false
            row.title = "Voice note \(idx + 1)"
            row.delegate = self

            // use session user avatar for audio row avatar
            row.setAvatarImage(Session.shared.currentUser.avatarName)

            let audioURL = MemoryStore.shared.urlForAttachment(filename: att.filename)
            row.loadAudioFile(url: audioURL)

            audioStack.addArrangedSubview(row)
            audioRows.append(row)

            // requested height 61
            NSLayoutConstraint.activate([ row.heightAnchor.constraint(equalToConstant: 61) ])
        }
    }
}

// When a row starts playing, stop all other rows
extension MemoryDetailViewController: AudioRowViewDelegate {
    func audioRowViewDidStartPlaying(_ row: AudioRowView) {
        for r in audioRows where r !== row { r.stop() }
    }
}

// MARK: - AudioRowView + delegate

protocol AudioRowViewDelegate: AnyObject {
    func audioRowViewDidStartPlaying(_ row: AudioRowView)
}

/// Single-row audio player with slider, remaining time, and avatar
final class AudioRowView: UIView {
    // UI
    private let container = UIView()
    private let playButton = UIButton(type: .system)
    private let timeLabel = UILabel()
    private let avatarImageView = UIImageView()
    private let slider = UISlider()

    // playback
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var audioURL: URL?
    private var wasPlayingBeforeScrub: Bool = false

    weak var delegate: AudioRowViewDelegate?

    var title: String?

    // MARK: - init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)
        container.backgroundColor = .systemBackground
        container.layer.cornerRadius = 26 // requested corner radius
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.04
        container.layer.shadowOffset = CGSize(width: 0, height: 2)
        container.layer.shadowRadius = 6

        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playButton.tintColor = .label
        playButton.addTarget(self, action: #selector(didTapPlay), for: .touchUpInside)

        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.text = "00:00"
        timeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        timeLabel.textColor = .secondaryLabel

        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.layer.cornerRadius = 16
        avatarImageView.clipsToBounds = true
        avatarImageView.backgroundColor = UIColor(white: 0.9, alpha: 1)
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.image = UIImage(systemName: "person.circle.fill")
        avatarImageView.tintColor = .systemBlue

        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.value = 0
        slider.addTarget(self, action: #selector(sliderChanged(_:)), for: .valueChanged)
        slider.addTarget(self, action: #selector(sliderTouchDown(_:)), for: .touchDown)
        slider.addTarget(self, action: #selector(sliderTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        container.addSubview(playButton)
        container.addSubview(slider)
        container.addSubview(timeLabel)
        container.addSubview(avatarImageView)

        // layout tuned for compact 61 height
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.topAnchor.constraint(equalTo: topAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),

            playButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            playButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 36),
            playButton.heightAnchor.constraint(equalToConstant: 36),

            avatarImageView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            avatarImageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 32),
            avatarImageView.heightAnchor.constraint(equalToConstant: 32),

            timeLabel.trailingAnchor.constraint(equalTo: avatarImageView.leadingAnchor, constant: -10),
            timeLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            slider.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: 10),
            slider.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -10),
            slider.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
    }

    func setAvatarImage(_ avatarName: String?) {
        if let name = avatarName, let img = UIImage(named: name) {
            avatarImageView.image = img
        } else {
            let s = Session.shared.currentUser
            if let name = s.avatarName, let img = UIImage(named: name) {
                avatarImageView.image = img
            } else {
                avatarImageView.image = UIImage(systemName: "person.circle.fill")
                avatarImageView.tintColor = .systemBlue
            }
        }
    }

    // MARK: - Loading
    func loadAudioFile(url: URL) {
        audioURL = url
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if FileManager.default.fileExists(atPath: url.path) {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.prepareToPlay()
                    player.delegate = self
                    self.audioPlayer = player
                    DispatchQueue.main.async {
                        self.updateTimeLabel(reset: true)
                    }
                } catch {
                    print("AudioRowView: failed to load audio:", error)
                    DispatchQueue.main.async { self.isHidden = true }
                }
            } else {
                DispatchQueue.main.async { self.isHidden = true }
            }
        }
    }

    // MARK: - Playback controls
    @objc private func didTapPlay() {
        guard let player = audioPlayer else { return }
        if player.isPlaying {
            player.pause()
            stopTimer()
            playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        } else {
            delegate?.audioRowViewDidStartPlaying(self)
            player.play()
            startTimer()
            playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        }
    }

    func stop() {
        if let p = audioPlayer, p.isPlaying { p.pause() }
        playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        stopTimer()
        slider.value = 0
        updateTimeLabel(reset: true)
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            self?.updateTimeLabel()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// If reset==true will show total duration; otherwise show remaining time decreasing
    private func updateTimeLabel(reset: Bool = false) {
        guard let p = audioPlayer else {
            timeLabel.text = "00:00"
            slider.value = 0
            return
        }
        let total = Int(p.duration)
        if reset || (!p.isPlaying && p.currentTime == 0) {
            // show total
            timeLabel.text = String(format: "%02d:%02d", total / 60, total % 60)
            slider.value = 0
            return
        }
        // show remaining
        let remaining = max(0, Int(round(p.duration - p.currentTime)))
        timeLabel.text = String(format: "%02d:%02d", remaining / 60, remaining % 60)
        if p.duration > 0 {
            slider.value = Float(p.currentTime / p.duration)
        }
    }

    @objc private func sliderChanged(_ s: UISlider) {
        if let p = audioPlayer, p.duration > 0 {
            let pos = Double(s.value) * p.duration
            let rem = max(0, Int(round(p.duration - pos)))
            timeLabel.text = String(format: "%02d:%02d", rem / 60, rem % 60)
        }
    }

    @objc private func sliderTouchDown(_ s: UISlider) {
        wasPlayingBeforeScrub = audioPlayer?.isPlaying ?? false
        if wasPlayingBeforeScrub {
            audioPlayer?.pause()
            stopTimer()
            playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        }
    }

    @objc private func sliderTouchUp(_ s: UISlider) {
        guard let p = audioPlayer else { return }
        p.currentTime = TimeInterval(s.value) * p.duration
        updateTimeLabel()
        if wasPlayingBeforeScrub {
            p.play()
            startTimer()
            playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        }
    }
}

// AVAudioPlayerDelegate — detect end of playback
extension AudioRowView: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stop()
        updateTimeLabel(reset: true)
    }
}

// MARK: - Image preview: page controller + zooming view

final class ImagePreviewPageViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {

    private let images: [String]
    private var controllers: [ZoomImageViewController] = []
    private var startIndex: Int = 0
    private let pageControl = UIPageControl()

    // Blur to show underlying content softly
    private var backgroundBlurView: UIVisualEffectView?

    init(images: [String], initialIndex: Int = 0) {
        self.images = images
        self.startIndex = max(0, min(initialIndex, images.count - 1))
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
        self.dataSource = self
        self.delegate = self
        self.modalPresentationCapturesStatusBarAppearance = true
        buildControllers()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildControllers() {
        controllers = images.map { urlStr in
            let vc = ZoomImageViewController(imageString: urlStr)
            vc.dismissHandler = { [weak self] in
                self?.dismissSelf()
            }
            return vc
        }
        if controllers.isEmpty {
            controllers = [ZoomImageViewController(imageString: "")]
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Add a dark blur behind the page content so underlying MemoryDetailViewController is softly blurred.
        // Because we present overFullScreen, this blur will affect the presenting controller visually.
        let blur = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blur)
        blurView.alpha = 0.0
        blurView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blurView)
        view.sendSubviewToBack(blurView)
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: view.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        backgroundBlurView = blurView

        view.backgroundColor = .black
        setViewControllers([controllers[startIndex]], direction: .forward, animated: false, completion: nil)

        // page control
        pageControl.numberOfPages = controllers.count
        pageControl.currentPage = startIndex
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.currentPageIndicatorTintColor = .white
        pageControl.pageIndicatorTintColor = UIColor(white: 0.6, alpha: 0.8)
        view.addSubview(pageControl)
        NSLayoutConstraint.activate([
            pageControl.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])

        // Close button in top-left
        let close = UIButton(type: .system)
        close.translatesAutoresizingMaskIntoConstraints = false
        close.setImage(UIImage(systemName: "chevron.down.circle.fill"), for: .normal)
        close.tintColor = .white
        close.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
        view.addSubview(close)
        NSLayoutConstraint.activate([
            close.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            close.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            close.widthAnchor.constraint(equalToConstant: 44),
            close.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // animate blur in
        UIView.animate(withDuration: 0.25) { [weak self] in
            self?.backgroundBlurView?.alpha = 1.0
        }
    }

    // Dismiss with blur fade-out
    @objc private func dismissSelf() {
        // animate blur out, then dismiss
        UIView.animate(withDuration: 0.22, animations: { [weak self] in
            self?.backgroundBlurView?.alpha = 0.0
            self?.view.backgroundColor = .clear
        }, completion: { [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
        })
    }

    // MARK: - Page data source
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let current = viewController as? ZoomImageViewController,
              let idx = controllers.firstIndex(of: current),
              idx > 0 else { return nil }
        return controllers[idx - 1]
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let current = viewController as? ZoomImageViewController,
              let idx = controllers.firstIndex(of: current),
              idx < controllers.count - 1 else { return nil }
        return controllers[idx + 1]
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed, let current = viewControllers?.first as? ZoomImageViewController, let idx = controllers.firstIndex(of: current) {
            pageControl.currentPage = idx
        }
    }
}

/// Single page preview with pinch & double-tap zoom
final class ZoomImageViewController: UIViewController, UIScrollViewDelegate {
    let imageString: String
    let scrollView = UIScrollView()
    let imageView = UIImageView()
    var dismissHandler: (() -> Void)?

    init(imageString: String) {
        self.imageString = imageString
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .black
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        loadImage()
    }

    private func setup() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.maximumZoomScale = 4.0
        scrollView.minimumZoomScale = 1.0
        scrollView.delegate = self
        view.addSubview(scrollView)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        imageView.addGestureRecognizer(tap)

        let dbl = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        dbl.numberOfTapsRequired = 2
        imageView.addGestureRecognizer(dbl)
        tap.require(toFail: dbl)
    }

    private func loadImage() {
        guard !imageString.isEmpty else { imageView.image = nil; return }
        ImageLoader.shared.loadImage(from: imageString) { [weak self] img in
            DispatchQueue.main.async {
                self?.imageView.image = img ?? UIImage(systemName: "photo")
            }
        }
    }

    @objc private func handleTap(_ g: UITapGestureRecognizer) {
        dismissHandler?()
    }

    @objc private func handleDoubleTap(_ g: UITapGestureRecognizer) {
        if scrollView.zoomScale > 1.0 {
            scrollView.setZoomScale(1.0, animated: true)
        } else {
            let point = g.location(in: imageView)
            let w = scrollView.bounds.width / 2
            let h = scrollView.bounds.height / 2
            let r = CGRect(x: point.x - w/2, y: point.y - h/2, width: w, height: h)
            scrollView.zoom(to: r, animated: true)
        }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
}
