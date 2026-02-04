//
// PromptDetailViewControllerSimple+Waveform.swift
// Single-file implementation: PromptDetailViewControllerSimple + AudioCardView + LiveBarsView
//
// Integrated with Memory / MemoryStore (local save) — minimal changes to existing logic.
//

import UIKit
import PhotosUI
import AVFoundation
import DSWaveformImage
import DSWaveformImageViews

// MARK: - AudioCardView (reusable audio card) — pill layout with title below (Option C)
final class AudioCardView: UIView {
    let audioURL: URL
    let duration: TimeInterval

    // UI
    private let pillBackground = UIView()
    private let slider = UISlider()
    private let titleLabel = UILabel()
    private let durationLabel = UILabel()
    private let playButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)

    // callbacks
    private let playHandler: (AudioCardView) -> Void
    private let deleteHandler: (AudioCardView) -> Void

    // external seek callback (controller may set this)
    public var onSeek: ((TimeInterval) -> Void)?

    init(url: URL,
         duration: TimeInterval,
         playHandler: @escaping (AudioCardView) -> Void,
         deleteHandler: @escaping (AudioCardView) -> Void) {
        self.audioURL = url
        self.duration = duration
        self.playHandler = playHandler
        self.deleteHandler = deleteHandler
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        // Pill background
        pillBackground.translatesAutoresizingMaskIntoConstraints = false
        pillBackground.backgroundColor = UIColor { trait in
            return trait.userInterfaceStyle == .dark ? UIColor(white: 0.06, alpha: 1) : UIColor(white: 1, alpha: 1)
        }
        pillBackground.layer.cornerRadius = 32
        pillBackground.layer.masksToBounds = true
        addSubview(pillBackground)

        // Play button
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playButton.tintColor = .label
        playButton.widthAnchor.constraint(equalToConstant: 44).isActive = true
        playButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        pillBackground.addSubview(playButton)

        // Delete
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
        deleteButton.tintColor = .systemRed
        deleteButton.widthAnchor.constraint(equalToConstant: 40).isActive = true
        deleteButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        pillBackground.addSubview(deleteButton)

        // Duration label (to the left of delete)
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        durationLabel.textColor = .secondaryLabel
        durationLabel.text = formattedTime(duration)
        durationLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        pillBackground.addSubview(durationLabel)

        // Slider (center area)
        slider.translatesAutoresizingMaskIntoConstraints = false
        // configure slider appearance
        slider.minimumValue = 0
        slider.maximumValue = Float(max(0.0001, duration))
        slider.value = 0
        slider.isContinuous = true
        // custom thumb: simple filled circle
        let thumbDiameter: CGFloat = 14
        let thumb = UIImage.circle(diameter: thumbDiameter, color: .black)
        slider.setThumbImage(thumb, for: .normal)
        // track tint
        slider.minimumTrackTintColor = UIColor.black
        slider.maximumTrackTintColor = UIColor(white: 0.92, alpha: 1)
        pillBackground.addSubview(slider)

        // Title below pill
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.text = "Voice note"
        addSubview(titleLabel)

        // Layout constraints
        NSLayoutConstraint.activate([
            pillBackground.leadingAnchor.constraint(equalTo: leadingAnchor),
            pillBackground.trailingAnchor.constraint(equalTo: trailingAnchor),
            pillBackground.topAnchor.constraint(equalTo: topAnchor),
            pillBackground.heightAnchor.constraint(equalToConstant: 72),

            // play button on left inside pill
            playButton.leadingAnchor.constraint(equalTo: pillBackground.leadingAnchor, constant: 12),
            playButton.centerYAnchor.constraint(equalTo: pillBackground.centerYAnchor),

            // delete button on right inside pill
            deleteButton.trailingAnchor.constraint(equalTo: pillBackground.trailingAnchor, constant: -12),
            deleteButton.centerYAnchor.constraint(equalTo: pillBackground.centerYAnchor),

            // duration label just left of delete
            durationLabel.centerYAnchor.constraint(equalTo: pillBackground.centerYAnchor),
            durationLabel.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -12),

            // slider fills area between play and duration
            slider.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: 12),
            slider.trailingAnchor.constraint(equalTo: durationLabel.leadingAnchor, constant: -12),
            slider.centerYAnchor.constraint(equalTo: pillBackground.centerYAnchor),

            // Title below
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: pillBackground.bottomAnchor, constant: 8),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])

        // Actions
        playButton.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.playHandler(self)
        }, for: .touchUpInside)

        deleteButton.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.deleteHandler(self)
        }, for: .touchUpInside)

        // Slider events: continuous update -> call onSeek for live seeking
        slider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        // When user lifts finger, commit seek
        slider.addTarget(self, action: #selector(sliderTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    // MARK: Slider handlers
    @objc private func sliderValueChanged(_ s: UISlider) {
        // update remaining label visually while dragging
        let current = TimeInterval(s.value)
        let remaining = max(0, duration - current)
        updateRemaining(remaining)
        // We don't call onSeek here final; allow continuous if desired:
        // (optional) uncomment if you want continuous seeking:
        // onSeek?(current)
    }

    @objc private func sliderTouchUp(_ s: UISlider) {
        let current = TimeInterval(s.value)
        // commit seek
        onSeek?(current)
    }

    // MARK: External update helpers (controller uses these)
    func playButtonSetPlaying(_ playing: Bool) {
        let name = playing ? "pause.fill" : "play.fill"
        playButton.setImage(UIImage(systemName: name), for: .normal)
    }

    func updateRemaining(_ remaining: TimeInterval) {
        durationLabel.text = formattedTime(remaining)
    }

    /// progress percent: 0...1
    func updateProgress(percent: CGFloat) {
        guard duration > 0 else {
            slider.value = 0
            return
        }
        let clamped = max(0, min(1, percent))
        let value = Float(clamped) * Float(duration)
        slider.value = value
        // update remaining label
        let remaining = max(0, duration - TimeInterval(value))
        updateRemaining(remaining)
    }

    /// Called when playback starts (controller can set slider to startOffset). We don't animate the slider here;
    /// the controller's playbackTimer should call updateProgress periodically.
    func startProgressAnimation(totalDuration: TimeInterval, startOffset: TimeInterval) {
        slider.minimumValue = 0
        slider.maximumValue = Float(max(0.0001, totalDuration))
        slider.value = Float(startOffset)
        updateRemaining(max(0, totalDuration - startOffset))
    }

    func stopProgressAnimation() {
        // nothing special; controller will call updateProgress/updateRemaining
    }

    // MARK: Utilities
    private func formattedTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "00:00" }
        let s = Int(max(0, round(seconds)))
        let mm = s / 60
        let ss = s % 60
        return String(format: "%02d:%02d", mm, ss)
    }
}

// MARK: - UIImage helper for thumb
fileprivate extension UIImage {
    static func circle(diameter: CGFloat, color: UIColor) -> UIImage? {
        let size = CGSize(width: diameter, height: diameter)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        ctx.setFillColor(color.cgColor)
        let r = CGRect(origin: .zero, size: size)
        ctx.fillEllipse(in: r)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img
    }
}
// MARK: - LiveBarsView (simple shifting bar visualizer for live recording)
final class LiveBarsView: UIView {
    private let barCount = 36
    private var barLayers: [CALayer] = []
    private var amplitudes: [CGFloat] = []
    private let barWidth: CGFloat = 4
    private let spacing: CGFloat = 4

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    private func setup() {
        backgroundColor = .clear
        clipsToBounds = true
        amplitudes = Array(repeating: 0.05, count: barCount)
        createLayers()
    }

    private func createLayers() {
        barLayers.forEach { $0.removeFromSuperlayer() }
        barLayers = []
        for _ in 0..<barCount {
            let l = CALayer()
            l.backgroundColor = UIColor.systemGray2.cgColor
            layer.addSublayer(l)
            barLayers.append(l)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutBarLayers()
    }

    private func layoutBarLayers() {
        let totalSpacing = CGFloat(barCount - 1) * spacing
        let w = max(2, (bounds.width - totalSpacing) / CGFloat(barCount))
        let barW = min(w, barWidth)
        for (i, sub) in barLayers.enumerated() {
            let x = CGFloat(i) * (barW + spacing)
            let amp = max(0.02, amplitudes[i])
            let h = max(2, bounds.height * amp)
            sub.frame = CGRect(x: x, y: bounds.height - h, width: barW, height: h)
            sub.cornerRadius = barW / 2
        }
    }

    // push new amplitude value (0...1). Values shift left and new appended to right.
    func push(amplitude: CGFloat) {
        let a = max(0, min(1, amplitude))
        amplitudes.removeFirst()
        amplitudes.append(a * 0.95 + 0.05)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layoutBarLayers()
        CATransaction.commit()
    }
}

// MARK: - PromptDetailViewControllerSimple
final class PromptDetailViewControllerSimple: UIViewController, PostOptionsViewControllerDelegate {

    // MARK: Models
    enum Attachment {
        case image(id: UUID, image: UIImage)
        case audio(url: URL, duration: TimeInterval)
    }

    private enum RecordingState {
        case idle
        case recording
        case paused
    }

    // MARK: Dependencies
    private let prompt: Prompt
    init(prompt: Prompt) {
        self.prompt = prompt
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: State
    private var attachments: [Attachment] = [] { didSet { refreshAttachmentsViews() } }

    private var recordingState: RecordingState = .idle {
        didSet { DispatchQueue.main.async { self.syncToolbarToRecordingState() } }
    }

    private var audioFileURL: URL?
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var audioDurationSeconds: TimeInterval = 0

    private var meterTimer: Timer?
    private var durationTimer: Timer?
    private var playbackTimer: Timer?

    private var recordingStartDate: Date?
    private var accumulatedRecordingDuration: TimeInterval = 0

    private var pendingSendAfterStop: Bool = false

    // playback coordination
    private weak var currentPlayingCard: AudioCardView?

    // waveform drawer
    private let waveformDrawer = WaveformImageDrawer()

    // MARK: Views
    private let scrollView: UIScrollView = {
        let s = UIScrollView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.alwaysBounceVertical = true
        return s
    }()

    private let contentView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 20
        return iv
    }()

    private lazy var textView: UITextView = {
        let tv = UITextView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.font = UIFont.systemFont(ofSize: 16)
        tv.isScrollEnabled = false
        tv.delegate = self
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.backgroundColor = .clear
        return tv
    }()

    private let placeholderLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.textColor = .systemGray
        l.numberOfLines = 0
        l.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        return l
    }()

    private let attachmentsStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 16
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let toolbarEffectView: UIVisualEffectView = {
        let v = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialLight))
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 32
        v.layer.masksToBounds = true
        return v
    }()

    private let cameraButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setImage(UIImage(systemName: "camera"), for: .normal)
        b.tintColor = .label
        return b
    }()

    private let galleryButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setImage(UIImage(systemName: "photo.on.rectangle.angled"), for: .normal)
        b.tintColor = .label
        return b
    }()

    private let trashButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setImage(UIImage(systemName: "trash"), for: .normal)
        b.tintColor = .systemRed
        b.isHidden = true
        return b
    }()

    private let pauseButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setImage(UIImage(systemName: "pause.circle"), for: .normal)
        b.tintColor = .label
        b.isHidden = true
        return b
    }()

    private let sendButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle("Send", for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        b.setTitleColor(.systemBlue, for: .normal)
        b.isHidden = true
        return b
    }()

    private let micButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        b.tintColor = .label
        return b
    }()

    private var toolbarBottomConstraint: NSLayoutConstraint!
    private var textViewHeightConstraint: NSLayoutConstraint!

    private var liveRecordingContainer: UIView?
    private var liveBarsView: LiveBarsView?
    private var liveDurationLabel: UILabel?

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 242/255, green: 242/255, blue: 247/255, alpha: 1)
        setupNav()
        setupViews()
        wireActions()
        placeholderLabel.text = prompt.text

        if let name = Session.shared.currentUser.avatarName, let img = UIImage(named: name) {
            avatarImageView.image = img
        } else {
            avatarImageView.image = UIImage(systemName: "person.circle.fill")
        }

        addKeyboardObservers()
        addTapToDismiss()
        recordingState = .idle
    }

    deinit {
        removeKeyboardObservers()
        meterTimer?.invalidate()
        durationTimer?.invalidate()
        playbackTimer?.invalidate()
    }

    // MARK: Setup
    private func setupNav() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "chevron.left"),
                                                           style: .plain,
                                                           target: self,
                                                           action: #selector(onBack))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Post",
                                                            style: .plain,
                                                            target: self,
                                                            action: #selector(onPostTap))
    }

    private func setupViews() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        contentView.addSubview(avatarImageView)
        contentView.addSubview(textView)
        contentView.addSubview(placeholderLabel)
        contentView.addSubview(attachmentsStack)
        view.addSubview(toolbarEffectView)

        let leftStack = UIStackView(arrangedSubviews: [cameraButton, galleryButton])
        leftStack.axis = .horizontal
        leftStack.spacing = 18
        leftStack.alignment = .center
        leftStack.translatesAutoresizingMaskIntoConstraints = false

        toolbarEffectView.contentView.addSubview(leftStack)
        toolbarEffectView.contentView.addSubview(trashButton)
        toolbarEffectView.contentView.addSubview(pauseButton)
        toolbarEffectView.contentView.addSubview(sendButton)
        toolbarEffectView.contentView.addSubview(micButton)

        NSLayoutConstraint.activate([
            avatarImageView.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 16),
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            avatarImageView.widthAnchor.constraint(equalToConstant: 40),
            avatarImageView.heightAnchor.constraint(equalToConstant: 40),

            textView.topAnchor.constraint(equalTo: avatarImageView.topAnchor),
            textView.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            textView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            placeholderLabel.trailingAnchor.constraint(equalTo: textView.trailingAnchor),

            attachmentsStack.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 16),
            attachmentsStack.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            attachmentsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            attachmentsStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -180)
        ])

        NSLayoutConstraint.activate([
            toolbarEffectView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            toolbarEffectView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            toolbarEffectView.heightAnchor.constraint(equalToConstant: 64)
        ])
        toolbarBottomConstraint = toolbarEffectView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        toolbarBottomConstraint.isActive = true

        NSLayoutConstraint.activate([
            leftStack.leadingAnchor.constraint(equalTo: toolbarEffectView.contentView.leadingAnchor, constant: 18),
            leftStack.centerYAnchor.constraint(equalTo: toolbarEffectView.contentView.centerYAnchor),

            trashButton.leadingAnchor.constraint(equalTo: toolbarEffectView.contentView.leadingAnchor, constant: 18),
            trashButton.centerYAnchor.constraint(equalTo: toolbarEffectView.contentView.centerYAnchor),

            pauseButton.centerXAnchor.constraint(equalTo: toolbarEffectView.contentView.centerXAnchor),
            pauseButton.centerYAnchor.constraint(equalTo: toolbarEffectView.contentView.centerYAnchor),

            sendButton.trailingAnchor.constraint(equalTo: toolbarEffectView.contentView.trailingAnchor, constant: -18),
            sendButton.centerYAnchor.constraint(equalTo: toolbarEffectView.contentView.centerYAnchor),

            micButton.trailingAnchor.constraint(equalTo: toolbarEffectView.contentView.trailingAnchor, constant: -18),
            micButton.centerYAnchor.constraint(equalTo: toolbarEffectView.contentView.centerYAnchor)
        ])

        [cameraButton, galleryButton, trashButton, pauseButton, micButton].forEach { btn in
            btn.widthAnchor.constraint(equalToConstant: 34).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 34).isActive = true
        }

        textViewHeightConstraint = textView.heightAnchor.constraint(equalToConstant: 80)
        textViewHeightConstraint.isActive = true

        placeholderLabel.isHidden = !textView.text.isEmpty
    }

    private func wireActions() {
        cameraButton.addTarget(self, action: #selector(cameraTapped), for: .touchUpInside)
        galleryButton.addTarget(self, action: #selector(galleryTapped), for: .touchUpInside)
        micButton.addTarget(self, action: #selector(micToggleTapped), for: .touchUpInside)
        pauseButton.addTarget(self, action: #selector(micToggleTapped), for: .touchUpInside)
        sendButton.addTarget(self, action: #selector(onSendTap), for: .touchUpInside)
        trashButton.addTarget(self, action: #selector(onTrashTap), for: .touchUpInside)
    }

    // MARK: Attachments layout
    private func refreshAttachmentsViews() {
        attachmentsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let imageAttachments = attachments.compactMap { att -> (UUID, UIImage)? in
            if case let .image(id, image) = att { return (id, image) }
            return nil
        }

        if imageAttachments.count == 1 {
            let (id, img) = imageAttachments[0]
            attachmentsStack.addArrangedSubview(attachmentImageView(id: id, image: img, large: true))
        } else if imageAttachments.count == 2 {
            let h = UIStackView()
            h.axis = .horizontal; h.spacing = 12; h.distribution = .fillEqually; h.translatesAutoresizingMaskIntoConstraints = false
            let a = imageAttachments[0]; let b = imageAttachments[1]
            h.addArrangedSubview(smallImageCard(id: a.0, image: a.1))
            h.addArrangedSubview(smallImageCard(id: b.0, image: b.1))
            attachmentsStack.addArrangedSubview(h)
            h.heightAnchor.constraint(equalToConstant: 120).isActive = true
        } else if imageAttachments.count > 2 {
            let scroll = UIScrollView()
            scroll.translatesAutoresizingMaskIntoConstraints = false
            scroll.showsHorizontalScrollIndicator = false
            let hstack = UIStackView(); hstack.translatesAutoresizingMaskIntoConstraints = false; hstack.axis = .horizontal; hstack.spacing = 12
            scroll.addSubview(hstack)
            NSLayoutConstraint.activate([
                hstack.topAnchor.constraint(equalTo: scroll.topAnchor),
                hstack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
                hstack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 12),
                hstack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -12),
                hstack.heightAnchor.constraint(equalTo: scroll.heightAnchor)
            ])
            for (id,image) in imageAttachments {
                let thumb = smallImageCard(id: id, image: image)
                thumb.widthAnchor.constraint(equalToConstant: 120).isActive = true
                thumb.heightAnchor.constraint(equalToConstant: 120).isActive = true
                hstack.addArrangedSubview(thumb)
            }
            attachmentsStack.addArrangedSubview(scroll)
            scroll.heightAnchor.constraint(equalToConstant: 140).isActive = true
        }

        for att in attachments {
            if case let .audio(url, duration) = att {
                let card = AudioCardView(url: url,
                                         duration: duration,
                                         playHandler: { [weak self] card in
                                            self?.playCard(card)
                                         },
                                         deleteHandler: { [weak self] card in
                                            self?.deleteCard(card)
                                         })
                attachmentsStack.addArrangedSubview(card)
            }
        }

        view.layoutIfNeeded()
    }

    // MARK: Builders (image cards unchanged)
    private func attachmentImageView(id: UUID, image: UIImage, large: Bool) -> UIView {
        let container = UIView(); container.translatesAutoresizingMaskIntoConstraints = false
        let imgView = UIImageView(image: image); imgView.translatesAutoresizingMaskIntoConstraints = false
        imgView.contentMode = .scaleAspectFill; imgView.clipsToBounds = true; imgView.layer.cornerRadius = 12
        let delete = UIButton(type: .system); delete.translatesAutoresizingMaskIntoConstraints = false
        delete.setImage(UIImage(systemName: "trash"), for: .normal); delete.tintColor = .systemRed
        delete.addAction(UIAction { [weak self] _ in self?.removeAttachment(id: id) }, for: .touchUpInside)
        container.addSubview(imgView); container.addSubview(delete)
        NSLayoutConstraint.activate([
            imgView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imgView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            imgView.topAnchor.constraint(equalTo: container.topAnchor),
            imgView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            delete.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            delete.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8)
        ])
        imgView.heightAnchor.constraint(equalToConstant: large ? 200 : 160).isActive = true
        return container
    }

    private func smallImageCard(id: UUID, image: UIImage) -> UIView {
        let v = UIView(); v.translatesAutoresizingMaskIntoConstraints = false
        let iv = UIImageView(image: image); iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFill; iv.clipsToBounds = true; iv.layer.cornerRadius = 10
        let delete = UIButton(type: .system); delete.translatesAutoresizingMaskIntoConstraints = false
        delete.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        delete.tintColor = UIColor(white: 1, alpha: 0.95)
        delete.addAction(UIAction { [weak self] _ in self?.removeAttachment(id: id) }, for: .touchUpInside)
        v.addSubview(iv); v.addSubview(delete)
        NSLayoutConstraint.activate([
            iv.leadingAnchor.constraint(equalTo: v.leadingAnchor),
            iv.trailingAnchor.constraint(equalTo: v.trailingAnchor),
            iv.topAnchor.constraint(equalTo: v.topAnchor),
            iv.bottomAnchor.constraint(equalTo: v.bottomAnchor),

            delete.topAnchor.constraint(equalTo: v.topAnchor, constant: 6),
            delete.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -6),
            delete.widthAnchor.constraint(equalToConstant: 28),
            delete.heightAnchor.constraint(equalToConstant: 28)
        ])
        return v
    }

    private func removeAttachment(id: UUID) {
        attachments.removeAll { att in
            switch att {
            case .image(let aid, _): return aid == id
            default: return false
            }
        }
    }

    // MARK: Image picking
    @objc private func galleryTapped() {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 4
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func cameraTapped() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { galleryTapped(); return }
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .camera
        present(picker, animated: true)
    }

    // MARK: Recording flow
    @objc private func micToggleTapped() {
        switch recordingState {
        case .idle:
            requestRecordPermissionAndStart()
        case .recording:
            pauseRecording()
        case .paused:
            resumeRecording()
        }
    }

    @objc private func onSendTap() {
        guard recordingState == .recording || recordingState == .paused else { return }
        if recordingState == .recording {
            pendingSendAfterStop = true
            audioRecorder?.stop()
            return
        }
        if recordingState == .paused {
            guard let url = audioFileURL else { return }
            var duration = accumulatedRecordingDuration
            if let player = try? AVAudioPlayer(contentsOf: url) { duration = player.duration }
            removeLiveRecordingUI()
            finalizeAndAppendRecordedFile(url: url, duration: duration)
        }
    }

    @objc private func onTrashTap() {
        cancelRecordingOrTransientFile()
    }

    private func requestRecordPermissionAndStart() {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    guard granted else { self?.showMicDeniedAlert(); return }
                    self?.startRecording()
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    guard granted else { self?.showMicDeniedAlert(); return }
                    self?.startRecording()
                }
            }
        }
    }

    private func showMicDeniedAlert() {
        let a = UIAlertController(title: "Microphone required",
                                  message: "Please enable microphone access in Settings to record audio.",
                                  preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        a.addAction(UIAlertAction(title: "Settings", style: .default, handler: { _ in
            if let url = URL(string:UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        }))
        present(a, animated: true)
    }

    private func startRecording() {
        // stop playback if playing
        if let player = audioPlayer, player.isPlaying {
            stopPlayback()
            currentPlayingCard?.stopProgressAnimation()
            currentPlayingCard?.playButtonSetPlaying(false)
            currentPlayingCard = nil
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            let url = tempAudioURL()
            audioFileURL = url

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.delegate = self
            audioRecorder?.record()

            recordingStartDate = Date()
            accumulatedRecordingDuration = 0
            audioDurationSeconds = 0

            meterTimer?.invalidate()
            meterTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in self?.updateMeters() }
            if let mt = meterTimer { RunLoop.main.add(mt, forMode: .common) }

            durationTimer?.invalidate()
            durationTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.updateLiveDuration() }
            if let dt = durationTimer { RunLoop.main.add(dt, forMode: .common) }

            showLiveRecordingCard()
            recordingState = .recording

            print("Recording started -> \(url.lastPathComponent)")
        } catch {
            print("startRecording error:", error)
        }
    }

    private func pauseRecording() {
        guard recordingState == .recording, let rec = audioRecorder else { return }
        rec.updateMeters()
        rec.pause()
        if let started = recordingStartDate { accumulatedRecordingDuration += Date().timeIntervalSince(started) }
        recordingStartDate = nil

        meterTimer?.invalidate(); meterTimer = nil
        durationTimer?.invalidate(); durationTimer = nil

        audioDurationSeconds = accumulatedRecordingDuration
        liveDurationLabel?.text = timeString(for: audioDurationSeconds)

        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.12) {
                self.liveBarsView?.alpha = 0.25
                self.liveBarsView?.transform = CGAffineTransform(scaleX: 1.0, y: 0.6)
            }
        }

        recordingState = .paused
        print("Recording paused (accumulated: \(accumulatedRecordingDuration))")
    }

    private func resumeRecording() {
        guard recordingState == .paused, let rec = audioRecorder else { return }
        recordingStartDate = Date()
        rec.record()

        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in self?.updateMeters() }
        if let mt = meterTimer { RunLoop.main.add(mt, forMode: .common) }

        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.updateLiveDuration() }
        if let dt = durationTimer { RunLoop.main.add(dt, forMode: .common) }

        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.12) {
                self.liveBarsView?.alpha = 1.0
                self.liveBarsView?.transform = CGAffineTransform.identity
            }
        }

        recordingState = .recording
        print("Recording resumed")
    }

    private func sendRecordedAudio() {
        onSendTap()
    }

    private func cancelRecordingOrTransientFile() {
        switch recordingState {
        case .recording:
            audioRecorder?.stop()
            audioRecorder = nil
            meterTimer?.invalidate(); meterTimer = nil
            durationTimer?.invalidate(); durationTimer = nil
            if let url = audioFileURL { try? FileManager.default.removeItem(at: url) }
            audioFileURL = nil
            recordingStartDate = nil
            accumulatedRecordingDuration = 0
            removeLiveRecordingUI()
            recordingState = .idle
            pendingSendAfterStop = false
            print("Recording cancelled and file deleted")
        case .paused:
            if let url = audioFileURL { try? FileManager.default.removeItem(at: url) }
            audioFileURL = nil
            accumulatedRecordingDuration = 0
            removeLiveRecordingUI()
            recordingState = .idle
            pendingSendAfterStop = false
            print("Transient paused file deleted")
        case .idle:
            break
        }
    }

    // MARK: Live meters & duration
    private func updateMeters() {
        guard let rec = audioRecorder else { return }
        rec.updateMeters()
        let avg = rec.averagePower(forChannel: 0)
        let amp = max(0, 1 - pow(10, avg / 20))
        DispatchQueue.main.async {
            self.liveBarsView?.push(amplitude: CGFloat(amp))
        }
    }

    private func updateLiveDuration() {
        var seconds = accumulatedRecordingDuration
        if let started = recordingStartDate { seconds += Date().timeIntervalSince(started) }
        audioDurationSeconds = seconds
        DispatchQueue.main.async { [weak self] in self?.liveDurationLabel?.text = self?.timeString(for: seconds) }
    }

    // MARK: Playback per-card orchestration
    private func playCard(_ card: AudioCardView) {
        // If currently playing a different card, stop it
        if let current = currentPlayingCard, current !== card {
            stopPlayback()
            current.playButtonSetPlaying(false)
            current.stopProgressAnimation()
            currentPlayingCard = nil
        }

        // Toggle behaviour
        if let player = audioPlayer, player.isPlaying, currentPlayingCard === card {
            // currently playing this card -> pause
            stopPlayback()
            card.playButtonSetPlaying(false)
            currentPlayingCard = nil
            return
        }

        // start playback for requested card
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: card.audioURL)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            currentPlayingCard = card
            card.playButtonSetPlaying(true)

            let duration = audioPlayer?.duration ?? card.duration
            let startOffset = audioPlayer?.currentTime ?? 0
            card.startProgressAnimation(totalDuration: duration, startOffset: startOffset)

            playbackTimer?.invalidate()
            playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true, block: { [weak self, weak card] _ in
                guard let self = self, let card = card, let player = self.audioPlayer else { return }
                let remaining = max(0, player.duration - player.currentTime)
                card.updateRemaining(remaining)
                let progress = CGFloat(player.currentTime / max(0.0001, player.duration))
                card.updateProgress(percent: progress)
            })
            if let pt = playbackTimer { RunLoop.main.add(pt, forMode: .common) }

        } catch {
            print("play error:", error)
        }
    }

    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func deleteCard(_ card: AudioCardView) {
        if currentPlayingCard === card {
            stopPlayback()
            currentPlayingCard = nil
        }
        attachments.removeAll { att in
            switch att {
            case .audio(let u, _):
                if u == card.audioURL {
                    try? FileManager.default.removeItem(at: u)
                    return true
                } else { return false }
            default: return false
            }
        }
    }

    // MARK: Toolbar sync
    private func syncToolbarToRecordingState() {
        switch recordingState {
        case .idle:
            cameraButton.isHidden = false
            galleryButton.isHidden = false
            micButton.isHidden = false

            pauseButton.isHidden = true
            trashButton.isHidden = true
            sendButton.isHidden = true

            micButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)

        case .recording:
            cameraButton.isHidden = true
            galleryButton.isHidden = true

            micButton.isHidden = true
            pauseButton.isHidden = false
            trashButton.isHidden = false
            sendButton.isHidden = false

            pauseButton.setImage(UIImage(systemName: "pause.circle"), for: .normal)

        case .paused:
            cameraButton.isHidden = true
            galleryButton.isHidden = true

            micButton.isHidden = true
            pauseButton.isHidden = false
            trashButton.isHidden = false
            sendButton.isHidden = false

            pauseButton.setImage(UIImage(systemName: "play.circle"), for: .normal)
        }
    }

    // MARK: Live UI
    private func showLiveRecordingCard() {
        removeLiveRecordingUI()

        let container = UIView(); container.translatesAutoresizingMaskIntoConstraints = false
        container.layer.cornerRadius = 12
        container.backgroundColor = UIColor { trait in trait.userInterfaceStyle == .dark ? UIColor(white: 0.08, alpha: 1) : UIColor(white: 1, alpha: 1) }

        let waveContainer = UIView(); waveContainer.translatesAutoresizingMaskIntoConstraints = false
        waveContainer.layer.cornerRadius = 8
        waveContainer.backgroundColor = UIColor(white: 0.96, alpha: 1)

        let bars = LiveBarsView(); bars.translatesAutoresizingMaskIntoConstraints = false
        bars.layer.cornerRadius = 8
        bars.clipsToBounds = true
        waveContainer.addSubview(bars)

        NSLayoutConstraint.activate([
            bars.leadingAnchor.constraint(equalTo: waveContainer.leadingAnchor, constant: 8),
            bars.trailingAnchor.constraint(equalTo: waveContainer.trailingAnchor, constant: -8),
            bars.topAnchor.constraint(equalTo: waveContainer.topAnchor, constant: 4),
            bars.bottomAnchor.constraint(equalTo: waveContainer.bottomAnchor, constant: -4)
        ])

        let durationLabel = UILabel(); durationLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        durationLabel.textColor = .secondaryLabel
        durationLabel.text = timeString(for: 0)

        view.addSubview(container)
        container.addSubview(waveContainer)
        container.addSubview(durationLabel)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            container.bottomAnchor.constraint(equalTo: toolbarEffectView.topAnchor, constant: -12),

            waveContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            waveContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            waveContainer.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            waveContainer.heightAnchor.constraint(equalToConstant: 56),

            durationLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            durationLabel.topAnchor.constraint(equalTo: waveContainer.bottomAnchor, constant: 8),
            durationLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])

        liveRecordingContainer = container
        liveBarsView = bars
        liveDurationLabel = durationLabel
        liveBarsView?.transform = CGAffineTransform(scaleX: 1.0, y: 0.8)
    }

    private func removeLiveRecordingUI() {
        liveRecordingContainer?.removeFromSuperview()
        liveRecordingContainer = nil
        liveBarsView?.removeFromSuperview()
        liveBarsView = nil
        liveDurationLabel = nil
    }

    // MARK: Utilities
    private func tempAudioURL() -> URL {
        let name = "memory_\(UUID().uuidString).m4a"
        return FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }

    private func timeString(for seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "00:00" }
        let s = Int(max(0, round(seconds)))
        let mm = s / 60
        let ss = s % 60
        return String(format: "%02d:%02d", mm, ss)
    }

    // MARK: Post / Back
    @objc private func onBack() {
        if let nav = navigationController, nav.viewControllers.count > 1 { nav.popViewController(animated: true) }
        else if presentingViewController != nil { dismiss(animated: true, completion: nil) }
    }

    @objc private func onPostTap() {
        let vc = PostOptionsViewController()
        vc.delegate = self
        vc.modalPresentationStyle = .overCurrentContext

        // --- populate optional inputs so PostOptions can auto-save locally if no delegate ---
        vc.bodyText = textView.text
        vc.promptText = prompt.text
        // collect images from attachments
        let imgs = attachments.compactMap { att -> UIImage? in
            switch att {
            case .image(_, let img): return img
            default: return nil
            }
        }
        vc.userImages = imgs

        // collect audio files from attachments
        let audios = attachments.compactMap { att -> (url: URL, duration: TimeInterval)? in
            switch att {
            case .audio(let url, let dur): return (url: url, duration: dur)
            default: return nil
            }
        }
        vc.userAudioFiles = audios

        // fallback: if prompt has a remote or local image path, let PostOptions know
        // Try a few common field names on your Prompt model (iconName, imageURL). Adjust as needed.
        if let p = (prompt as? Prompt) {
            // Prompt in your code seemed to use `iconName` for image/asset or URL string — pass that along.
            // If you have a different property name for prompt image, change the line below accordingly.
            vc.promptFallbackImageURL = (p.iconName ?? "")
        }

        present(vc, animated: true)
    }

    // MARK: Keyboard
    private func addKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)),
                                               name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)),
                                               name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    private func removeKeyboardObservers() { NotificationCenter.default.removeObserver(self) }

    @objc private func keyboardWillShow(_ note: Notification) {
        guard let info = note.userInfo,
              let frameValue = info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curve = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else { return }
        let frame = frameValue.cgRectValue
        let keyboardHeightInView = view.convert(frame, from: nil).height
        let safeBottom = view.safeAreaInsets.bottom
        let moveUp = keyboardHeightInView - safeBottom
        toolbarBottomConstraint.constant = -moveUp - 8
        let options = UIView.AnimationOptions(rawValue: curve << 16)
        UIView.animate(withDuration: duration, delay: 0, options: options) { self.view.layoutIfNeeded() }
    }

    @objc private func keyboardWillHide(_ note: Notification) {
        guard let info = note.userInfo,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curve = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else { return }
        toolbarBottomConstraint.constant = -8
        let options = UIView.AnimationOptions(rawValue: curve << 16)
        UIView.animate(withDuration: duration, delay: 0, options: options) { self.view.layoutIfNeeded() }
    }

    private func addTapToDismiss() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    @objc private func dismissKeyboard() { view.endEditing(true) }

    // MARK: Send finalization helper used from delegate or audioRecorderDidFinishRecording
    private func finalizeAndAppendRecordedFile(url: URL, duration: TimeInterval) {
        let already = attachments.contains { att in
            if case .audio(let u, _) = att { return u == url } else { return false }
        }
        if !already {
            attachments.append(.audio(url: url, duration: duration))
            showSendConfirmation()
            print("Audio appended to attachments: \(url.lastPathComponent) duration:\(duration)")
        } else { print("Audio already in attachments — skipping append") }

        removeLiveRecordingUI()

        audioFileURL = nil
        accumulatedRecordingDuration = 0
        audioDurationSeconds = 0
        pendingSendAfterStop = false

        playbackTimer?.invalidate(); playbackTimer = nil

        recordingState = .idle

        refreshAttachmentsViews()
    }

    private func showSendConfirmation() {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.backgroundColor = UIColor(white: 0, alpha: 0.6)
        lbl.textColor = .white
        lbl.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        lbl.text = "Sent"
        lbl.textAlignment = .center
        lbl.layer.cornerRadius = 8
        lbl.layer.masksToBounds = true
        view.addSubview(lbl)
        NSLayoutConstraint.activate([
            lbl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            lbl.bottomAnchor.constraint(equalTo: toolbarEffectView.topAnchor, constant: -24),
            lbl.widthAnchor.constraint(equalToConstant: 88),
            lbl.heightAnchor.constraint(equalToConstant: 36)
        ])
        lbl.alpha = 0
        UIView.animate(withDuration: 0.18, animations: { lbl.alpha = 1 }) { _ in
            UIView.animate(withDuration: 0.25, delay: 0.6, options: [], animations: { lbl.alpha = 0 }) { _ in lbl.removeFromSuperview() }
        }
    }

    // MARK: PostOptionsViewControllerDelegate
    func postOptionsViewControllerDidCancel(_ controller: UIViewController) { controller.dismiss(animated: true) }

    func postOptionsViewController(_ controller: UIViewController, didFinishPostingWithTitle title: String?, scheduleDate: Date?, visibility: MemoryVisibility) {
        // Build the body and attachments and save to local MemoryStore (preferred)
        controller.dismiss(animated: true) // dismiss the modal first (non-blocking)
        let titleText: String
        if let customTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines), !customTitle.isEmpty {
            titleText = customTitle
        } else {
            // Fallback to prompt text as title
            titleText = prompt.text
        }
        
        let bodyText = textView.text.isEmpty ? nil : textView.text

        // Resolve ownerId robustly (String or UUID or fallback)
        var ownerId: String = "local_user"
        let uid = Session.shared.currentUser.id
        if let s = uid as? String {
            ownerId = s
        } else if let uuid = uid as? UUID {
            ownerId = uuid.uuidString
        } else {
            ownerId = "\(uid)"
        }

        // Prepare attachments: save images/audio to store in background
        DispatchQueue.global(qos: .userInitiated).async {
            var memAttachments: [MemoryAttachment] = []

            // save images
            let images = self.attachments.compactMap { att -> UIImage? in
                if case let .image(_, img) = att { return img }
                return nil
            }
            for img in images {
                do {
                    let filename = try MemoryStore.shared.saveImageAttachment(img)
                    let attach = MemoryAttachment(kind: .image, filename: filename)
                    memAttachments.append(attach)
                } catch {
                    print("PromptDetail: failed to save image attachment:", error)
                }
            }

            // save audio files
            let audios = self.attachments.compactMap { att -> (URL, TimeInterval)? in
                if case let .audio(url, dur) = att { return (url, dur) }
                return nil
            }
            for (url, _) in audios {
                do {
                    let filename = try MemoryStore.shared.saveAudioAttachment(at: url)
                    let attach = MemoryAttachment(kind: .audio, filename: filename)
                    memAttachments.append(attach)
                } catch {
                    print("PromptDetail: failed to save audio attachment:", error)
                }
            }

            // If user attached no images, attempt fallback from prompt (if available)
            if images.isEmpty {
                // If prompt has an image URL or asset name, try to download or load and save it.
                // We'll attempt using `prompt.iconName` as potential fallback (adjust if your model different)
                if let iconStr = (self.prompt as? Prompt)?.iconName.trimmingCharacters(in: .whitespacesAndNewlines),
                   !iconStr.isEmpty {
                    if let url = URL(string: iconStr), url.scheme?.starts(with: "http") == true {
                        // try download
                        do {
                            let data = try Data(contentsOf: url)
                            if let img = UIImage(data: data) {
                                do {
                                    let fname = try MemoryStore.shared.saveImageAttachment(img)
                                    let att = MemoryAttachment(kind: .image, filename: fname)
                                    memAttachments.append(att)
                                } catch {
                                    print("PromptDetail: failed to save downloaded fallback image:", error)
                                }
                            }
                        } catch {
                            print("PromptDetail: couldn't download fallback prompt image:", error)
                        }
                    } else {
                        // treat as asset name
                        if let img = UIImage(named: iconStr) {
                            do {
                                let fname = try MemoryStore.shared.saveImageAttachment(img)
                                let att = MemoryAttachment(kind: .image, filename: fname)
                                memAttachments.append(att)
                            } catch {
                                print("PromptDetail: failed to save bundled fallback image:", error)
                            }
                        }
                    }
                }
            }

            // Create Memory and persist via MemoryStore
            // --- pass category from the prompt so Memory.category is filled ---
            let categoryValue: String? = (self.prompt as? Prompt)?.category

            MemoryStore.shared.createMemory(ownerId: ownerId,
                                            title: titleText,
                                            body: bodyText,
                                            attachments: memAttachments,
                                            visibility: visibility,
                                            scheduledFor: scheduleDate,
                                            category: categoryValue) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let memory):
                        // notify the app and return home (pop to root)
                        NotificationCenter.default.post(name: .memoriesUpdated, object: nil, userInfo: ["memoryId": memory.id])

                        // Print the saved memory (pretty JSON if encodable)
                        do {
                            let enc = JSONEncoder()
                            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
                            let data = try enc.encode(memory)
                            if let s = String(data: data, encoding: .utf8) {
                                print("Memory saved (JSON):\n\(s)")
                            } else {
                                print("Memory saved:", memory)
                            }
                        } catch {
                            print("Memory saved (model):", memory)
                        }

                        // Pop to root (go back to Home)
                        if let nav = self.navigationController {
                            nav.popToRootViewController(animated: true)
                        } else {
                            // fallback: dismiss to root if presented modally
                            var top = self.presentingViewController
                            while let p = top?.presentingViewController { top = p }
                            top?.dismiss(animated: true, completion: nil)
                        }

                    case .failure(let error):
                        // show an alert
                        let a = UIAlertController(title: "Save failed", message: "Could not save memory: \(error.localizedDescription)", preferredStyle: .alert)
                        a.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(a, animated: true)
                        print("MemoryStore create failed:", error)
                    }
                }
            }
        }
    }
}

// MARK: - Delegates
extension PromptDetailViewControllerSimple: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        let width = textView.bounds.width > 0 ? textView.bounds.width : (view.bounds.width - 20 - 40 - 12 - 20)
        let targetSize = CGSize(width: width, height: .greatestFiniteMagnitude)
        let size = textView.sizeThatFits(targetSize)
        let newH = min(max(size.height, 44), 300)
        textViewHeightConstraint?.constant = newH
        UIView.animate(withDuration: 0.12) { self.view.layoutIfNeeded() }
    }
}

extension PromptDetailViewControllerSimple: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard !results.isEmpty else { return }
        for res in results {
            if res.itemProvider.canLoadObject(ofClass: UIImage.self) {
                res.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
                    guard let self = self else { return }
                    if let img = obj as? UIImage {
                        DispatchQueue.main.async {
                            let id = UUID()
                            self.attachments.append(.image(id: id, image: img))
                        }
                    }
                }
            }
        }
    }
}

extension PromptDetailViewControllerSimple: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true) }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        if let img = info[.originalImage] as? UIImage {
            let id = UUID()
            attachments.append(.image(id: id, image: img))
        }
    }
}

extension PromptDetailViewControllerSimple: AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        meterTimer?.invalidate(); meterTimer = nil
        durationTimer?.invalidate(); durationTimer = nil

        if let url = audioFileURL, let player = try? AVAudioPlayer(contentsOf: url) {
            audioDurationSeconds = player.duration
        }

        if pendingSendAfterStop, let url = audioFileURL {
            removeLiveRecordingUI()
            var duration = accumulatedRecordingDuration
            if let player = try? AVAudioPlayer(contentsOf: url) { duration = player.duration }
            finalizeAndAppendRecordedFile(url: url, duration: duration)
        } else {
            audioRecorder = nil
            recordingState = .paused
            removeLiveRecordingUI()
            print("Recorder finished by system -> moved to paused")
        }

        audioRecorder = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playbackTimer?.invalidate(); playbackTimer = nil
        currentPlayingCard?.playButtonSetPlaying(false)
        currentPlayingCard?.stopProgressAnimation()
        currentPlayingCard = nil
        refreshAttachmentsViews()
    }
}
