import UIKit
import AVFoundation

class GroupMemoryViewController: UIViewController {
    
    // MARK: - Properties
    private var memory: GroupMemory
    private var mediaItems: [SupabaseMemoryMedia] = []
    
    // MARK: - Audio Properties
    private var audioPlayer: AVAudioPlayer?
    private var audioURL: URL?
    private var isAudioPreparing = false
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        label.textColor = .label
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let yearLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let userLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = .tertiaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = .tertiaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let imageScrollView = UIScrollView()
    private let imageStackView = UIStackView()
    private var imageViews: [UIImageView] = []
    private var pageControl: UIPageControl?
    
    private let textContentLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = .label
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Audio UI Components
    private let audioContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let audioPlayButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
        button.tintColor = .systemBlue
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let audioSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.value = 0
        slider.translatesAutoresizingMaskIntoConstraints = false
        return slider
    }()
    
    private let audioTimeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel
        label.text = "00:00 / 00:00"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let audioLoadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private var audioTimer: Timer?
    private var wasPlayingBeforeScrub = false
    
    // MARK: - Initializer
    init(memory: GroupMemory, mediaItems: [SupabaseMemoryMedia] = []) {
        self.memory = memory
        self.mediaItems = mediaItems
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureWithMemory()
        loadImages()
        setupAudio()
        
        // Configure audio session for playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session: \(error)")
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        audioTimer?.invalidate()
        audioPlayer?.stop()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Memory Details"
        
        // Setup scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Image scroll view setup
        imageScrollView.translatesAutoresizingMaskIntoConstraints = false
        imageScrollView.showsHorizontalScrollIndicator = false
        imageScrollView.isPagingEnabled = true
        
        imageStackView.translatesAutoresizingMaskIntoConstraints = false
        imageStackView.axis = .horizontal
        imageStackView.spacing = 0
        imageScrollView.addSubview(imageStackView)
        
        // Setup audio container
        audioContainerView.addSubview(audioPlayButton)
        audioContainerView.addSubview(audioSlider)
        audioContainerView.addSubview(audioTimeLabel)
        audioContainerView.addSubview(audioLoadingIndicator)
        
        audioPlayButton.addTarget(self, action: #selector(toggleAudio), for: .touchUpInside)
        audioSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        audioSlider.addTarget(self, action: #selector(sliderTouchDown), for: .touchDown)
        audioSlider.addTarget(self, action: #selector(sliderTouchUp), for: [.touchUpInside, .touchUpOutside])
        
        // Add all views to content view
        [titleLabel, yearLabel, userLabel, dateLabel,
         imageScrollView, textContentLabel, audioContainerView].forEach {
            contentView.addSubview($0)
        }
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Year
            yearLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            yearLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            yearLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // User
            userLabel.topAnchor.constraint(equalTo: yearLabel.bottomAnchor, constant: 4),
            userLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            userLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Date
            dateLabel.topAnchor.constraint(equalTo: userLabel.bottomAnchor, constant: 4),
            dateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            dateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Image scroll view
            imageScrollView.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 20),
            imageScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageScrollView.heightAnchor.constraint(equalToConstant: 300),
            
            // Image stack view
            imageStackView.topAnchor.constraint(equalTo: imageScrollView.topAnchor),
            imageStackView.leadingAnchor.constraint(equalTo: imageScrollView.leadingAnchor),
            imageStackView.trailingAnchor.constraint(equalTo: imageScrollView.trailingAnchor),
            imageStackView.bottomAnchor.constraint(equalTo: imageScrollView.bottomAnchor),
            imageStackView.heightAnchor.constraint(equalTo: imageScrollView.heightAnchor),
            
            // Text content
            textContentLabel.topAnchor.constraint(equalTo: imageScrollView.bottomAnchor, constant: 20),
            textContentLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            textContentLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Audio container
            audioContainerView.topAnchor.constraint(equalTo: textContentLabel.bottomAnchor, constant: 20),
            audioContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            audioContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            audioContainerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30),
            audioContainerView.heightAnchor.constraint(equalToConstant: 80),
            
            // Audio button
            audioPlayButton.leadingAnchor.constraint(equalTo: audioContainerView.leadingAnchor, constant: 16),
            audioPlayButton.centerYAnchor.constraint(equalTo: audioContainerView.centerYAnchor),
            audioPlayButton.widthAnchor.constraint(equalToConstant: 44),
            audioPlayButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Audio slider
            audioSlider.leadingAnchor.constraint(equalTo: audioPlayButton.trailingAnchor, constant: 12),
            audioSlider.trailingAnchor.constraint(equalTo: audioTimeLabel.leadingAnchor, constant: -12),
            audioSlider.centerYAnchor.constraint(equalTo: audioContainerView.centerYAnchor),
            
            // Audio time label
            audioTimeLabel.trailingAnchor.constraint(equalTo: audioContainerView.trailingAnchor, constant: -16),
            audioTimeLabel.centerYAnchor.constraint(equalTo: audioContainerView.centerYAnchor),
            
            // Loading indicator
            audioLoadingIndicator.centerXAnchor.constraint(equalTo: audioContainerView.centerXAnchor),
            audioLoadingIndicator.centerYAnchor.constraint(equalTo: audioContainerView.centerYAnchor)
        ])
    }
    
    // MARK: - Configuration
    private func configureWithMemory() {
        titleLabel.text = memory.title
        userLabel.text = "Shared by: \(memory.userName ?? "Unknown")"
        
        if let year = memory.year {
            yearLabel.text = "Year: \(year)"
        } else {
            yearLabel.isHidden = true
        }
        
        // Format date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        dateLabel.text = "Created: \(dateFormatter.string(from: memory.createdAt))"
        
        // Extract text content from mediaItems
        var textContent = memory.content
        
        if (textContent?.isEmpty ?? true) {
            if let textMedia = mediaItems.first(where: { $0.mediaType == "text" }) {
                textContent = textMedia.textContent
            }
        }
        
        textContentLabel.text = textContent
        textContentLabel.isHidden = (textContent?.isEmpty ?? true)
    }
    
    private func loadImages() {
        // Clear existing images
        imageStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        imageViews.removeAll()
        
        // Remove existing page control
        pageControl?.removeFromSuperview()
        pageControl = nil
        
        // Filter image media items
        let imageMedia = mediaItems.filter { $0.mediaType == "photo" }
        
        if imageMedia.isEmpty {
            imageScrollView.isHidden = true
            return
        }
        
        imageScrollView.isHidden = false
        
        // Create image views
        for (index, media) in imageMedia.enumerated() {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageView.clipsToBounds = true
            imageView.backgroundColor = .secondarySystemBackground
            imageView.translatesAutoresizingMaskIntoConstraints = false
            
            // Add loading indicator
            let activityIndicator = UIActivityIndicatorView(style: .medium)
            activityIndicator.translatesAutoresizingMaskIntoConstraints = false
            activityIndicator.startAnimating()
            imageView.addSubview(activityIndicator)
            
            NSLayoutConstraint.activate([
                activityIndicator.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
                activityIndicator.centerYAnchor.constraint(equalTo: imageView.centerYAnchor)
            ])
            
            // Add to stack view
            imageStackView.addArrangedSubview(imageView)
            imageViews.append(imageView)
            
            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(equalTo: view.widthAnchor),
                imageView.heightAnchor.constraint(equalToConstant: 300)
            ])
            
            // Load image
            loadImage(from: media.mediaUrl, for: imageView, activityIndicator: activityIndicator)
        }
        
        // Setup page control if multiple images
        if imageMedia.count > 1 {
            setupPageControl(totalPages: imageMedia.count)
        }
    }
    
    private func loadImage(from urlString: String, for imageView: UIImageView, activityIndicator: UIActivityIndicatorView) {
        guard let url = URL(string: urlString) else {
            activityIndicator.stopAnimating()
            imageView.image = UIImage(systemName: "photo")
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                activityIndicator.stopAnimating()
                
                if let error = error {
                    print("Failed to load image: \(error)")
                    imageView.image = UIImage(systemName: "photo")
                    return
                }
                
                if let data = data, let image = UIImage(data: data) {
                    imageView.image = image
                } else {
                    imageView.image = UIImage(systemName: "photo")
                }
            }
        }
        task.resume()
    }
    
    private func setupPageControl(totalPages: Int) {
        let pageControl = UIPageControl()
        pageControl.numberOfPages = totalPages
        pageControl.currentPage = 0
        pageControl.pageIndicatorTintColor = .systemGray
        pageControl.currentPageIndicatorTintColor = .systemBlue
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(pageControl)
        
        NSLayoutConstraint.activate([
            pageControl.topAnchor.constraint(equalTo: imageScrollView.bottomAnchor, constant: 8),
            pageControl.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
        ])
        
        self.pageControl = pageControl
        imageScrollView.delegate = self
    }
    
    // MARK: - Audio Setup
    private func setupAudio() {
        // Find audio media
        guard let audioMedia = mediaItems.first(where: { $0.mediaType == "audio" }),
              let audioURLString = audioMedia.mediaUrl as String?,
              let url = URL(string: audioURLString) else {
            audioContainerView.isHidden = true
            return
        }
        
        audioContainerView.isHidden = false
        audioLoadingIndicator.startAnimating()
        audioPlayButton.isEnabled = false
        
        // Download audio file first (important for m4a files)
        downloadAudio(from: url)
    }
    
    private func downloadAudio(from url: URL) {
        let task = URLSession.shared.downloadTask(with: url) { [weak self] localURL, response, error in
            guard let self = self, let localURL = localURL, error == nil else {
                DispatchQueue.main.async {
                    self?.audioLoadingIndicator.stopAnimating()
                    self?.audioContainerView.isHidden = true
                    print("Failed to download audio: \(error?.localizedDescription ?? "unknown error")")
                }
                return
            }
            
            do {
                // Move to a permanent location in documents directory
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let destinationURL = documentsURL.appendingPathComponent(localURL.lastPathComponent)
                
                // Remove existing file if needed
                try? FileManager.default.removeItem(at: destinationURL)
                try FileManager.default.moveItem(at: localURL, to: destinationURL)
                
                // Setup audio player with the local file
                try self.setupAudioPlayer(with: destinationURL)
                
            } catch {
                print("Failed to setup audio: \(error)")
                
                // Fallback: Try streaming with AVPlayer
                DispatchQueue.main.async {
                    self.setupStreamingPlayer(with: url)
                }
            }
        }
        task.resume()
    }
    
    private func setupAudioPlayer(with url: URL) throws {
        // For m4a files, we need to use AVAudioPlayer with the correct file type
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.prepareToPlay()
        audioPlayer?.delegate = self
        
        DispatchQueue.main.async {
            self.audioLoadingIndicator.stopAnimating()
            self.audioPlayButton.isEnabled = true
            self.updateAudioTimeDisplay()
        }
    }
    
    private func setupStreamingPlayer(with url: URL) {
        // For streaming, use AVPlayer which handles more formats
        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        
        // We need to adapt this to work with our AVAudioPlayer-based UI
        // For simplicity, we'll use AVPlayer and update UI accordingly
        // This requires more changes - let me know if you need streaming support
        print("Streaming not implemented in this version")
        audioContainerView.isHidden = true
    }
    
    // MARK: - Audio Actions
    @objc private func toggleAudio() {
        guard let player = audioPlayer else { return }
        
        if player.isPlaying {
            player.pause()
            audioPlayButton.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
            stopAudioTimer()
        } else {
            player.play()
            audioPlayButton.setImage(UIImage(systemName: "pause.circle.fill"), for: .normal)
            startAudioTimer()
        }
    }
    
    private func startAudioTimer() {
        stopAudioTimer()
        audioTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateAudioTimeDisplay()
        }
    }
    
    private func stopAudioTimer() {
        audioTimer?.invalidate()
        audioTimer = nil
    }
    
    private func updateAudioTimeDisplay() {
        guard let player = audioPlayer else { return }
        
        let current = player.currentTime
        let duration = player.duration
        
        if duration > 0 {
            audioSlider.value = Float(current / duration)
            
            let currentMinutes = Int(current) / 60
            let currentSeconds = Int(current) % 60
            let totalMinutes = Int(duration) / 60
            let totalSeconds = Int(duration) % 60
            
            audioTimeLabel.text = String(format: "%02d:%02d / %02d:%02d",
                                         currentMinutes, currentSeconds,
                                         totalMinutes, totalSeconds)
        }
    }
    
    @objc private func sliderChanged(_ sender: UISlider) {
        guard let player = audioPlayer, player.duration > 0 else { return }
        player.currentTime = Double(sender.value) * player.duration
        updateAudioTimeDisplay()
    }
    
    @objc private func sliderTouchDown(_ sender: UISlider) {
        wasPlayingBeforeScrub = audioPlayer?.isPlaying ?? false
        if wasPlayingBeforeScrub {
            audioPlayer?.pause()
            stopAudioTimer()
            audioPlayButton.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
        }
    }
    
    @objc private func sliderTouchUp(_ sender: UISlider) {
        if wasPlayingBeforeScrub {
            audioPlayer?.play()
            startAudioTimer()
            audioPlayButton.setImage(UIImage(systemName: "pause.circle.fill"), for: .normal)
        }
    }
}

// MARK: - UIScrollViewDelegate
extension GroupMemoryViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == imageScrollView, let pageControl = pageControl {
            let pageIndex = round(scrollView.contentOffset.x / scrollView.frame.width)
            pageControl.currentPage = Int(pageIndex)
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension GroupMemoryViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        audioPlayButton.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
        audioSlider.value = 0
        stopAudioTimer()
        updateAudioTimeDisplay()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio decode error: \(error?.localizedDescription ?? "unknown")")
        audioContainerView.isHidden = true
    }
}
