//
// MemoryEditViewController.swift
// Programmatic Memory edit page (edit existing Memory, update in-place)
//

import UIKit
import PhotosUI
import AVFoundation
import DSWaveformImage
import DSWaveformImageViews

// Note: this file assumes your project defines: Memory, MemoryAttachment, MemoryVisibility,
// MemoryStore, ImageLoader, Session, MemoryDetailViewController elsewhere in the project.

final class MemoryEditViewController: UIViewController {

    // MARK: - Models / Attachment representation used in editor
    enum Attachment {
        case image(id: UUID, image: UIImage)
        case audio(url: URL, duration: TimeInterval)
    }

    private let memory: Memory

    // MARK: - State
    private var attachments: [Attachment] = [] {
        didSet { refreshAttachmentsViews() }
    }

    // Recording state
    private enum RecordingState { case idle, recording, paused }
    private var recordingState: RecordingState = .idle { didSet { DispatchQueue.main.async { self.syncToolbarToRecordingState() } } }

    private var audioRecorder: AVAudioRecorder?
    private var audioFileURL: URL?
    private var recordingStartDate: Date?
    private var accumulatedRecordingDuration: TimeInterval = 0
    private var pendingSendAfterStop: Bool = false

    private var meterTimer: Timer?
    private var durationTimer: Timer?
    private var playbackTimer: Timer?
    private var audioPlayer: AVAudioPlayer?

    // playback orchestration for audio cards (renamed to avoid collisions)
    private weak var currentPlayingCard: EditAudioCardView?

    // waveform drawer (kept for compatibility)
    private let waveformDrawer = WaveformImageDrawer()

    // MARK: - Views
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let avatarImageView = UIImageView()
    private let titleTextField = UITextField()
    private let bodyTextView = UITextView()
    private let placeholderLabel = UILabel()
    private let attachmentsStack = UIStackView()

    // Toolbar
    private let toolbarEffectView: UIVisualEffectView = {
        let v = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialLight))
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 32
        v.layer.masksToBounds = true
        return v
    }()

    private let cameraButton = UIButton(type: .system)
    private let galleryButton = UIButton(type: .system)
    private let micButton = UIButton(type: .system)
    private let pauseButton = UIButton(type: .system)
    private let trashButton = UIButton(type: .system)
    private let sendButton = UIButton(type: .system)

    private var toolbarBottomConstraint: NSLayoutConstraint!
    private var titleHeightConstraint: NSLayoutConstraint!
    private var bodyHeightConstraint: NSLayoutConstraint!

    // Live recording UI handles (renamed bars view)
    private var liveRecordingContainer: UIView?
    private var liveBarsView: EditLiveBarsView?
    private var liveDurationLabel: UILabel?

    // MARK: - Init
    init(memory: Memory) {
        self.memory = memory
        super.init(nibName: nil, bundle: nil)
        self.title = "Edit Memory"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 242/255, green: 242/255, blue: 247/255, alpha: 1)
        setupNav()
        setupViews()
        wireActions()
        prefillFromMemory()
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

    // MARK: - Nav
    private func setupNav() {
        // Removed top-left delete button as requested.
        // Right: Done/checkmark
        let done = UIBarButtonItem(image: UIImage(systemName: "checkmark"), style: .done, target: self, action: #selector(didTapDone))
        navigationItem.rightBarButtonItem = done
    }

    @objc private func didTapDone() {
        // Save/update memory (update in-place)
        saveChanges()
    }

    // MARK: - Setup Views
    private func setupViews() {
        // Scroll
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
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        // Avatar
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.layer.cornerRadius = 20
        avatarImageView.clipsToBounds = true
        avatarImageView.contentMode = .scaleAspectFill
        contentView.addSubview(avatarImageView)
        NSLayoutConstraint.activate([
            avatarImageView.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 16),
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            avatarImageView.widthAnchor.constraint(equalToConstant: 40),
            avatarImageView.heightAnchor.constraint(equalToConstant: 40)
        ])

        // Title text field
        titleTextField.translatesAutoresizingMaskIntoConstraints = false
        titleTextField.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleTextField.placeholder = "Title"
        contentView.addSubview(titleTextField)
        NSLayoutConstraint.activate([
            titleTextField.topAnchor.constraint(equalTo: avatarImageView.topAnchor),
            titleTextField.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            titleTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
        ])
        titleHeightConstraint = titleTextField.heightAnchor.constraint(equalToConstant: 36)
        titleHeightConstraint.isActive = true

        // Body text view
        bodyTextView.translatesAutoresizingMaskIntoConstraints = false
        bodyTextView.font = UIFont.systemFont(ofSize: 16)
        bodyTextView.isScrollEnabled = false
        bodyTextView.backgroundColor = .clear
        bodyTextView.textContainerInset = .zero
        bodyTextView.textContainer.lineFragmentPadding = 0
        bodyTextView.delegate = self
        contentView.addSubview(bodyTextView)

        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.text = "Write something..."
        placeholderLabel.textColor = .systemGray
        placeholderLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        contentView.addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: titleTextField.bottomAnchor, constant: 8),
            placeholderLabel.leadingAnchor.constraint(equalTo: titleTextField.leadingAnchor),
            placeholderLabel.trailingAnchor.constraint(equalTo: titleTextField.trailingAnchor),

            bodyTextView.topAnchor.constraint(equalTo: titleTextField.bottomAnchor, constant: 8),
            bodyTextView.leadingAnchor.constraint(equalTo: titleTextField.leadingAnchor),
            bodyTextView.trailingAnchor.constraint(equalTo: titleTextField.trailingAnchor),
        ])
        bodyHeightConstraint = bodyTextView.heightAnchor.constraint(equalToConstant: 88)
        bodyHeightConstraint.isActive = true

        // attachments stack — reduced gap to 8 (was 16)
        attachmentsStack.axis = .vertical
        attachmentsStack.spacing = 16
        attachmentsStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(attachmentsStack)

        NSLayoutConstraint.activate([
            attachmentsStack.topAnchor.constraint(equalTo: bodyTextView.bottomAnchor, constant: 8), // reduced gap
            attachmentsStack.leadingAnchor.constraint(equalTo: bodyTextView.leadingAnchor),
            attachmentsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            attachmentsStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -180)
        ])

        // toolbar
        view.addSubview(toolbarEffectView)
        toolbarEffectView.contentView.addSubview(cameraButton)
        toolbarEffectView.contentView.addSubview(galleryButton)
        toolbarEffectView.contentView.addSubview(trashButton)
        toolbarEffectView.contentView.addSubview(pauseButton)
        toolbarEffectView.contentView.addSubview(sendButton)
        toolbarEffectView.contentView.addSubview(micButton)

        cameraButton.translatesAutoresizingMaskIntoConstraints = false
        galleryButton.translatesAutoresizingMaskIntoConstraints = false
        micButton.translatesAutoresizingMaskIntoConstraints = false
        pauseButton.translatesAutoresizingMaskIntoConstraints = false
        trashButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.translatesAutoresizingMaskIntoConstraints = false

        cameraButton.setImage(UIImage(systemName: "camera"), for: .normal)
        galleryButton.setImage(UIImage(systemName: "photo.on.rectangle.angled"), for: .normal)
        micButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        pauseButton.setImage(UIImage(systemName: "pause.circle"), for: .normal)
        trashButton.setImage(UIImage(systemName: "trash"), for: .normal)
        sendButton.setTitle("Send", for: .normal)

        // color/tint changes per request:
        let adaptiveTint: UIColor = .label
        cameraButton.tintColor = adaptiveTint
        galleryButton.tintColor = adaptiveTint
        micButton.tintColor = adaptiveTint
        pauseButton.tintColor = adaptiveTint
        sendButton.setTitleColor(adaptiveTint, for: .normal)
        // trash red
        trashButton.tintColor = .systemRed

        NSLayoutConstraint.activate([
            toolbarEffectView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            toolbarEffectView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            toolbarEffectView.heightAnchor.constraint(equalToConstant: 64)
        ])
        toolbarBottomConstraint = toolbarEffectView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        toolbarBottomConstraint.isActive = true

        NSLayoutConstraint.activate([
            cameraButton.leadingAnchor.constraint(equalTo: toolbarEffectView.contentView.leadingAnchor, constant: 18),
            cameraButton.centerYAnchor.constraint(equalTo: toolbarEffectView.contentView.centerYAnchor),

            galleryButton.leadingAnchor.constraint(equalTo: cameraButton.trailingAnchor, constant: 18),
            galleryButton.centerYAnchor.constraint(equalTo: toolbarEffectView.contentView.centerYAnchor),

            micButton.trailingAnchor.constraint(equalTo: toolbarEffectView.contentView.trailingAnchor, constant: -18),
            micButton.centerYAnchor.constraint(equalTo: toolbarEffectView.contentView.centerYAnchor),

            pauseButton.centerXAnchor.constraint(equalTo: toolbarEffectView.contentView.centerXAnchor),
            pauseButton.centerYAnchor.constraint(equalTo: toolbarEffectView.contentView.centerYAnchor),

            trashButton.leadingAnchor.constraint(equalTo: toolbarEffectView.contentView.leadingAnchor, constant: 18),
            trashButton.centerYAnchor.constraint(equalTo: toolbarEffectView.contentView.centerYAnchor),

            sendButton.trailingAnchor.constraint(equalTo: toolbarEffectView.contentView.trailingAnchor, constant: -18),
            sendButton.centerYAnchor.constraint(equalTo: toolbarEffectView.contentView.centerYAnchor),
        ])

        [cameraButton, galleryButton, trashButton, pauseButton, micButton].forEach { btn in
            btn.widthAnchor.constraint(equalToConstant: 34).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 34).isActive = true
        }
    }

    // MARK: - Prefill
    private func prefillFromMemory() {
        // Avatar from session
        let sessionUser = Session.shared.currentUser
        if let avatar = sessionUser.avatarName, let img = UIImage(named: avatar) {
            avatarImageView.image = img
        } else {
            avatarImageView.image = UIImage(systemName: "person.crop.circle.fill")
            avatarImageView.tintColor = .systemBlue
        }

        titleTextField.text = memory.title
        bodyTextView.text = memory.body
        placeholderLabel.isHidden = !bodyTextView.text.isEmpty

        // Convert Memory attachments into editor attachments
        attachments.removeAll()
        for att in memory.attachments {
            switch att.kind {
            case .image:
                // try load local image from MemoryStore
                let filename = att.filename.trimmingCharacters(in: .whitespacesAndNewlines)
                let url = MemoryStore.shared.urlForAttachment(filename: filename)
                if FileManager.default.fileExists(atPath: url.path), let image = UIImage(contentsOfFile: url.path) {
                    attachments.append(.image(id: UUID(), image: image))
                } else if let urlObj = URL(string: filename), (urlObj.scheme?.hasPrefix("http") == true) {
                    // remote: download into memory (async) and insert when loaded
                    let placeholderID = UUID()
                    attachments.append(.image(id: placeholderID, image: UIImage())) // placeholder
                    ImageLoader.shared.loadImage(from: filename) { [weak self] img in
                        guard let self = self, let img = img else { return }
                        DispatchQueue.main.async {
                            if let idx = self.attachments.firstIndex(where: {
                                if case let .image(id, _) = $0 { return id == placeholderID } else { return false }
                            }) {
                                self.attachments[idx] = .image(id: placeholderID, image: img)
                            }
                        }
                    }
                } else {
                    // fallback blank placeholder
                    attachments.append(.image(id: UUID(), image: UIImage()))
                }
            case .audio:
                let filename = att.filename.trimmingCharacters(in: .whitespacesAndNewlines)
                let url = MemoryStore.shared.urlForAttachment(filename: filename)
                if FileManager.default.fileExists(atPath: url.path) {
                    if let player = try? AVAudioPlayer(contentsOf: url) {
                        attachments.append(.audio(url: url, duration: player.duration))
                    } else {
                        attachments.append(.audio(url: url, duration: 0))
                    }
                }
            case .unknown:
                continue
            }
        }
    }

    // MARK: - Actions wiring
    private func wireActions() {
        cameraButton.addTarget(self, action: #selector(cameraTapped), for: .touchUpInside)
        galleryButton.addTarget(self, action: #selector(galleryTapped), for: .touchUpInside)
        micButton.addTarget(self, action: #selector(micToggleTapped), for: .touchUpInside)
        pauseButton.addTarget(self, action: #selector(micToggleTapped), for: .touchUpInside)
        sendButton.addTarget(self, action: #selector(onSendTap), for: .touchUpInside)
        trashButton.addTarget(self, action: #selector(onTrashTap), for: .touchUpInside)
    }

    // MARK: - Attachments UI rendering
    private func refreshAttachmentsViews() {
        attachmentsStack.arrangedSubviews.forEach { attachmentsStack.removeArrangedSubview($0); $0.removeFromSuperview() }

        // images
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
            // horizontal scroller of thumbs
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

        // audio cards
        for att in attachments {
            if case let .audio(url, duration) = att {
                let card = EditAudioCardView(url: url, duration: duration, playHandler: { [weak self] card in
                    self?.playCard(card)
                }, deleteHandler: { [weak self] card in
                    self?.deleteAudioCard(card)
                })
                attachmentsStack.addArrangedSubview(card)
            }
        }

        view.layoutIfNeeded()
    }

    // MARK: - Builders (image UI)
    private func attachmentImageView(id: UUID, image: UIImage, large: Bool) -> UIView {
        let container = UIView(); container.translatesAutoresizingMaskIntoConstraints = false
        let imgView = UIImageView(image: image); imgView.translatesAutoresizingMaskIntoConstraints = false
        imgView.contentMode = .scaleAspectFill; imgView.clipsToBounds = true; imgView.layer.cornerRadius = 12
        let delete = UIButton(type: .system); delete.translatesAutoresizingMaskIntoConstraints = false
        delete.setImage(UIImage(systemName: "trash"), for: .normal); delete.tintColor = .systemRed
        delete.addAction(UIAction { [weak self] _ in self?.removeImageAttachment(id: id) }, for: .touchUpInside)
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
        delete.addAction(UIAction { [weak self] _ in self?.removeImageAttachment(id: id) }, for: .touchUpInside)
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

    private func removeImageAttachment(id: UUID) {
        attachments.removeAll { att in
            switch att {
            case .image(let aid, _): return aid == id
            default: return false
            }
        }
    }

    // MARK: - Image picking
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

    // MARK: - Recording flow
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
        // finish recording and append
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
        // stop playback if any playing card
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

            meterTimer?.invalidate()
            meterTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in self?.updateMeters() }
            if let mt = meterTimer { RunLoop.main.add(mt, forMode: .common) }

            durationTimer?.invalidate()
            durationTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.updateLiveDuration() }
            if let dt = durationTimer { RunLoop.main.add(dt, forMode: .common) }

            showLiveRecordingCard()
            recordingState = .recording
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

        recordingState = .paused
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

        recordingState = .recording
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
        case .paused:
            if let url = audioFileURL { try? FileManager.default.removeItem(at: url) }
            audioFileURL = nil
            accumulatedRecordingDuration = 0
            removeLiveRecordingUI()
            recordingState = .idle
            pendingSendAfterStop = false
        case .idle:
            break
        }
    }

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
        DispatchQueue.main.async { [weak self] in
            self?.liveDurationLabel?.text = self?.timeString(for: seconds)
        }
    }

    private func showLiveRecordingCard() {
        removeLiveRecordingUI()

        let container = UIView(); container.translatesAutoresizingMaskIntoConstraints = false
        container.layer.cornerRadius = 12
        container.backgroundColor = UIColor { trait in trait.userInterfaceStyle == .dark ? UIColor(white: 0.08, alpha: 1) : UIColor(white: 1, alpha: 1) }

        let waveContainer = UIView(); waveContainer.translatesAutoresizingMaskIntoConstraints = false
        waveContainer.layer.cornerRadius = 8
        waveContainer.backgroundColor = UIColor(white: 0.96, alpha: 1)

        let bars = EditLiveBarsView(); bars.translatesAutoresizingMaskIntoConstraints = false
        bars.layer.cornerRadius = 8
        bars.clipsToBounds = true

        waveContainer.addSubview(bars)

        // Make bars fill the waveContainer so push(amplitude:) will update visuals
        NSLayoutConstraint.activate([
            bars.leadingAnchor.constraint(equalTo: waveContainer.leadingAnchor, constant: 6),
            bars.trailingAnchor.constraint(equalTo: waveContainer.trailingAnchor, constant: -6),
            bars.topAnchor.constraint(equalTo: waveContainer.topAnchor, constant: 6),
            bars.bottomAnchor.constraint(equalTo: waveContainer.bottomAnchor, constant: -6)
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

    private func finalizeAndAppendRecordedFile(url: URL, duration: TimeInterval) {
        // Append to attachments array (ensure there is no duplicate)
        let already = attachments.contains { att in
            if case .audio(let u, _) = att { return u == url } else { return false }
        }
        if !already {
            attachments.append(.audio(url: url, duration: duration))
        }
        removeLiveRecordingUI()
        audioFileURL = nil
        accumulatedRecordingDuration = 0
        pendingSendAfterStop = false
        recordingState = .idle
    }

    // MARK: - Playback per-card orchestration (EditAudioCardView)
    private func playCard(_ card: EditAudioCardView) {
        if let current = currentPlayingCard, current !== card {
            stopPlayback()
            current.playButtonSetPlaying(false)
            current.stopProgressAnimation()
            currentPlayingCard = nil
        }

        // toggle
        if let player = audioPlayer, player.isPlaying, currentPlayingCard === card {
            stopPlayback()
            card.playButtonSetPlaying(false)
            currentPlayingCard = nil
            return
        }

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
            print("playCard error:", error)
        }
    }

    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func deleteAudioCard(_ card: EditAudioCardView) {
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
                }
                return false
            default: return false
            }
        }
    }

    // MARK: - Helpers: toolbar sync / temp URL / time formatting
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

    private func tempAudioURL() -> URL {
        let name = "memory_edit_\(UUID().uuidString).m4a"
        return FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }

    private func timeString(for seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "00:00" }
        let s = Int(max(0, round(seconds)))
        let mm = s / 60
        let ss = s % 60
        return String(format: "%02d:%02d", mm, ss)
    }

    // MARK: - Save changes back to MemoryStore (update existing memory)
    private func saveChanges() {
        // Collect attachments: save images and audio to MemoryStore, build [MemoryAttachment]
        let titleText = titleTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let bodyText = bodyTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines)

        // Show HUD on main
        let hud = UIActivityIndicatorView(style: .large)
        hud.translatesAutoresizingMaskIntoConstraints = false
        hud.color = .secondaryLabel
        view.addSubview(hud)
        NSLayoutConstraint.activate([
            hud.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hud.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        hud.startAnimating()

        // Create a DispatchWorkItem to avoid overload ambiguity with DispatchQueue.async
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else {
                // Ensure HUD removal on main if self was deallocated
                DispatchQueue.main.async {
                    hud.stopAnimating()
                    hud.removeFromSuperview()
                }
                return
            }

            var memAttachments: [MemoryAttachment] = []

            // Save images
            for att in self.attachments {
                switch att {
                case .image(_, let img):
                    do {
                        let filename = try MemoryStore.shared.saveImageAttachment(img)
                        memAttachments.append(MemoryAttachment(kind: .image, filename: filename))
                    } catch {
                        print("Failed saving image attachment:", error)
                    }
                case .audio:
                    continue
                }
            }

            // Save audio
            for att in self.attachments {
                switch att {
                case .audio(let url, _):
                    do {
                        let filename = try MemoryStore.shared.saveAudioAttachment(at: url)
                        memAttachments.append(MemoryAttachment(kind: .audio, filename: filename))
                    } catch {
                        print("Failed saving audio attachment:", error)
                    }
                default:
                    continue
                }
            }

            // Build update parameters (ensure non-nil title)
            let newTitle: String = {
                if let t = titleText, !t.isEmpty { return t }
                return "Untitled"
            }()

            let newBody: String? = {
                if let b = bodyText, !b.isEmpty { return b }
                return nil
            }()

            // Stop HUD on main (we've finished file I/O)
            DispatchQueue.main.async {
                hud.stopAnimating()
                hud.removeFromSuperview()
            }

            // Attempt update (wait for completion)
            var updateError: Error?
            let semaphore = DispatchSemaphore(value: 0)

            // Call update API (adjust if your MemoryStore uses a different signature)
            MemoryStore.shared.updateMemory(id: self.memory.id,
                                            title: newTitle,
                                            body: newBody,
                                            attachments: memAttachments) { result in
                switch result {
                case .success:
                    NotificationCenter.default.post(name: .memoriesUpdated, object: nil)
                case .failure(let err):
                    updateError = err
                }
                semaphore.signal()
            }

            // Wait for MemoryStore callback
            _ = semaphore.wait(timeout: .distantFuture)

            // Finish on main thread: navigate to updated detail
            // Finish on main thread: navigate to updated detail
            // Finish on main thread: navigate to updated detail (safe replacement)
            DispatchQueue.main.async {
                if let err = updateError {
                    let a = UIAlertController(title: "Save failed", message: "Could not update memory: \(err.localizedDescription)", preferredStyle: .alert)
                    a.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(a, animated: true)
                    return
                }

                // Find updated memory record
                guard let updatedMemory = MemoryStore.shared.allMemories().first(where: { $0.id == self.memory.id }) else {
                    // fallback: just pop/dismiss
                    if let nav = self.navigationController {
                        // remove self and pop to previous
                        var vcs = nav.viewControllers
                        vcs.removeAll { $0 === self }
                        nav.setViewControllers(vcs, animated: true)
                    } else {
                        self.dismiss(animated: true)
                    }
                    return
                }

                let detailVC = MemoryDetailViewController(memory: updatedMemory)
                detailVC.hidesBottomBarWhenPushed = true

                if let nav = self.navigationController {
                    // Build new viewControllers array:
                    //   - remove any MemoryDetailViewController showing the same memory id (old detail)
                    //   - remove this editor (self)
                    //   - keep the rest in order
                    var newStack: [UIViewController] = []

                    for vc in nav.viewControllers {
                        // drop the old detail if it shows same memory id
                        if let md = vc as? MemoryDetailViewController {
                            // Assuming MemoryDetailViewController exposes its memory id or memory; we compare by memory.id
                            // If MemoryDetailViewController.memory is private, use a helper property or compare in another way.
                            // Here we try to inspect using mirror-pattern: safer approach is to check the class and skip all detail VCs
                            // that match the same id. If you can't access memory.id on the VC, skip all MemoryDetailViewController
                            // instances that aren't the one we want to keep.
                            if let existing = (vc as? MemoryDetailViewController) {
                                // If MemoryDetailViewController has a public/accessible `memory` property, compare:
                                // if existing.memory.id == updatedMemory.id { continue } // skip old one
                                // But if memory is private, we'll fallback to skipping detail VCs whose memory id matches by introspection.
                            }

                            // We'll attempt a safe check by using Mirror (non-ideal but works when property is present)
                            let mirror = Mirror(reflecting: vc)
                            if let memChild = mirror.children.first(where: { $0.label == "memory" }),
                               let mem = memChild.value as? Memory,
                               mem.id == updatedMemory.id {
                                // skip the old detail VC for same memory
                                continue
                            }
                        }

                        // remove the editor itself if present
                        if vc === self { continue }

                        newStack.append(vc)
                    }

                    // Append our fresh detail VC
                    newStack.append(detailVC)

                    // Finally set the new stack (animated)
                    nav.setViewControllers(newStack, animated: true)
                } else {
                    // Not in navigation controller — present modally and ensure editor doesn't remain underneath
                    let navController = UINavigationController(rootViewController: detailVC)
                    navController.modalPresentationStyle = .automatic

                    // Present the new nav controller, then dismiss self if needed
                    self.present(navController, animated: true) {
                        // If the editor was presented modally, dismiss it so user cannot return to it
                        if self.presentingViewController != nil {
                            self.dismiss(animated: false, completion: nil)
                        }
                    }
                }
            }
        }

        // Dispatch the work item on a background queue
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }

    // MARK: - Keyboard
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
}

// MARK: - PHPicker delegate
extension MemoryEditViewController: PHPickerViewControllerDelegate {
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

// MARK: - UIImagePickerController delegate
extension MemoryEditViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true) }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        if let img = info[.originalImage] as? UIImage {
            let id = UUID()
            attachments.append(.image(id: id, image: img))
        }
    }
}

// MARK: - AVAudioRecorder / AVAudioPlayer delegates
extension MemoryEditViewController: AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        meterTimer?.invalidate(); meterTimer = nil
        durationTimer?.invalidate(); durationTimer = nil

        if let url = audioFileURL, let player = try? AVAudioPlayer(contentsOf: url) {
            accumulatedRecordingDuration = player.duration
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

// MARK: - UITextView delegate (dynamic height)
extension MemoryEditViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        let width = textView.bounds.width > 0 ? textView.bounds.width : (view.bounds.width - 20 - 40 - 12 - 20)
        let targetSize = CGSize(width: width, height: .greatestFiniteMagnitude)
        let size = textView.sizeThatFits(targetSize)
        let newH = min(max(size.height, 44), 360)
        bodyHeightConstraint?.constant = newH
        UIView.animate(withDuration: 0.12) { self.view.layoutIfNeeded() }
    }
}

// MARK: - EditAudioCardView (renamed to avoid collisions)
final class EditAudioCardView: UIView {
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
    private let playHandler: (EditAudioCardView) -> Void
    private let deleteHandler: (EditAudioCardView) -> Void

    // external seek callback
    public var onSeek: ((TimeInterval) -> Void)?

    init(url: URL,
         duration: TimeInterval,
         playHandler: @escaping (EditAudioCardView) -> Void,
         deleteHandler: @escaping (EditAudioCardView) -> Void) {
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

        pillBackground.translatesAutoresizingMaskIntoConstraints = false
        pillBackground.backgroundColor = UIColor { trait in
            return trait.userInterfaceStyle == .dark ? UIColor(white: 0.06, alpha: 1) : UIColor(white: 1, alpha: 1)
        }
        pillBackground.layer.cornerRadius = 32
        pillBackground.layer.masksToBounds = true
        addSubview(pillBackground)

        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playButton.tintColor = .label
        playButton.widthAnchor.constraint(equalToConstant: 44).isActive = true
        playButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        pillBackground.addSubview(playButton)

        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
        deleteButton.tintColor = .systemRed
        deleteButton.widthAnchor.constraint(equalToConstant: 40).isActive = true
        deleteButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        pillBackground.addSubview(deleteButton)

        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        durationLabel.textColor = .secondaryLabel
        durationLabel.text = formattedTime(duration)
        durationLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        pillBackground.addSubview(durationLabel)

        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumValue = 0
        slider.maximumValue = Float(max(0.0001, duration))
        slider.value = 0
        slider.isContinuous = true
        let thumbDiameter: CGFloat = 14
        let thumb = UIImage.circle(diameter: thumbDiameter, color: .black)
        slider.setThumbImage(thumb, for: .normal)
        slider.minimumTrackTintColor = UIColor.black
        slider.maximumTrackTintColor = UIColor(white: 0.92, alpha: 1)
        pillBackground.addSubview(slider)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.text = "Voice note"
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            pillBackground.leadingAnchor.constraint(equalTo: leadingAnchor),
            pillBackground.trailingAnchor.constraint(equalTo: trailingAnchor),
            pillBackground.topAnchor.constraint(equalTo: topAnchor),
            pillBackground.heightAnchor.constraint(equalToConstant: 72),

            playButton.leadingAnchor.constraint(equalTo: pillBackground.leadingAnchor, constant: 12),
            playButton.centerYAnchor.constraint(equalTo: pillBackground.centerYAnchor),

            deleteButton.trailingAnchor.constraint(equalTo: pillBackground.trailingAnchor, constant: -12),
            deleteButton.centerYAnchor.constraint(equalTo: pillBackground.centerYAnchor),

            durationLabel.centerYAnchor.constraint(equalTo: pillBackground.centerYAnchor),
            durationLabel.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -12),

            slider.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: 12),
            slider.trailingAnchor.constraint(equalTo: durationLabel.leadingAnchor, constant: -12),
            slider.centerYAnchor.constraint(equalTo: pillBackground.centerYAnchor),

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

        slider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        slider.addTarget(self, action: #selector(sliderTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    @objc private func sliderValueChanged(_ s: UISlider) {
        let current = TimeInterval(s.value)
        let remaining = max(0, duration - current)
        updateRemaining(remaining)
    }

    @objc private func sliderTouchUp(_ s: UISlider) {
        let current = TimeInterval(s.value)
        onSeek?(current)
    }

    func playButtonSetPlaying(_ playing: Bool) {
        let name = playing ? "pause.fill" : "play.fill"
        playButton.setImage(UIImage(systemName: name), for: .normal)
    }

    func updateRemaining(_ remaining: TimeInterval) {
        durationLabel.text = formattedTime(remaining)
    }

    func updateProgress(percent: CGFloat) {
        guard duration > 0 else { slider.value = 0; return }
        let clamped = max(0, min(1, percent))
        let value = Float(clamped) * Float(duration)
        slider.value = value
        let remaining = max(0, duration - TimeInterval(value))
        updateRemaining(remaining)
    }

    func startProgressAnimation(totalDuration: TimeInterval, startOffset: TimeInterval) {
        slider.minimumValue = 0
        slider.maximumValue = Float(max(0.0001, totalDuration))
        slider.value = Float(startOffset)
        updateRemaining(max(0, totalDuration - startOffset))
    }

    func stopProgressAnimation() {}

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

// MARK: - EditLiveBarsView (renamed to avoid collisions)
final class EditLiveBarsView: UIView {
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
