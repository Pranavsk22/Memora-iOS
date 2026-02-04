import UIKit
import AVFoundation

class GroupMemoryViewController: UIViewController {
    
    // MARK: - Properties
    private var memory: GroupMemory
    private var mediaItems: [SupabaseMemoryMedia] = []
    
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
    
    private var audioPlayer: AVAudioPlayer?
    private let audioButton = UIButton(type: .system)
    
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
        
        // Audio button setup
        audioButton.translatesAutoresizingMaskIntoConstraints = false
        audioButton.setTitle("Play Audio", for: .normal)
        audioButton.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
        audioButton.tintColor = .systemBlue
        audioButton.addTarget(self, action: #selector(toggleAudio), for: .touchUpInside)
        audioButton.isHidden = true
        
        // Add all views to content view
        [titleLabel, yearLabel, userLabel, dateLabel,
         imageScrollView, textContentLabel, audioButton].forEach {
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
            
            // Audio button
            audioButton.topAnchor.constraint(equalTo: textContentLabel.bottomAnchor, constant: 20),
            audioButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            audioButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30)
        ])
    }
    
    // MARK: - Configuration
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
        
        // FIX: Extract text content from mediaItems
        var textContent = memory.content // Use existing content if available
        
        // If no content in memory object, check mediaItems for text content
        if (textContent?.isEmpty ?? true) {
            // Find first text media item
            if let textMedia = mediaItems.first(where: { $0.mediaType == "text" }) {
                textContent = textMedia.textContent
            }
        }
        
        // Set text content
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
            // No images, hide image scroll view
            imageScrollView.isHidden = true
            // Update text content position
            NSLayoutConstraint.activate([
                textContentLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 20)
            ])
            return
        }
        
        // Show image scroll view
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
            
            // FIRST: Add the imageView to the stack view
            imageStackView.addArrangedSubview(imageView)
            imageViews.append(imageView)
            
            // THEN: Set constraints AFTER adding to hierarchy
            // Use a reference to self.view for width
            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(equalTo: view.widthAnchor),
                imageView.heightAnchor.constraint(equalToConstant: 300)
            ])
            
            // Load image asynchronously
            loadImage(from: media.mediaUrl, for: imageView, activityIndicator: activityIndicator)
        }
        
        // Setup page control if multiple images
        if imageMedia.count > 1 {
            setupPageControl(totalPages: imageMedia.count)
        }
        
        // Check for audio
        let audioMedia = mediaItems.first { $0.mediaType == "audio" }
        if let audioUrl = audioMedia?.mediaUrl {
            setupAudioPlayer(url: audioUrl)
            audioButton.isHidden = false
        } else {
            audioButton.isHidden = true
        }
    }
    
    private func loadImage(from urlString: String, for imageView: UIImageView, activityIndicator: UIActivityIndicatorView) {
        guard let url = URL(string: urlString) else {
            print("Invalid image URL: \(urlString)")
            activityIndicator.stopAnimating()
            imageView.image = UIImage(systemName: "photo")
            imageView.tintColor = .systemGray
            return
        }
        
        // Use URLSession for better async loading
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                activityIndicator.stopAnimating()
                
                if let error = error {
                    print("Failed to load image: \(error)")
                    imageView.image = UIImage(systemName: "photo")
                    imageView.tintColor = .systemGray
                    return
                }
                
                if let data = data, let image = UIImage(data: data) {
                    imageView.image = image
                } else {
                    imageView.image = UIImage(systemName: "photo")
                    imageView.tintColor = .systemGray
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
    
    private func setupAudioPlayer(url: String) {
        guard let audioURL = URL(string: url) else {
            print("Invalid audio URL: \(url)")
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let audioData = try Data(contentsOf: audioURL)
                let player = try AVAudioPlayer(data: audioData)
                player.prepareToPlay()
                
                DispatchQueue.main.async {
                    self?.audioPlayer = player
                    self?.audioButton.isHidden = false
                }
            } catch {
                print("Failed to setup audio player: \(error)")
            }
        }
    }
    
    // MARK: - Actions
    @objc private func toggleAudio() {
        guard let player = audioPlayer else { return }
        
        if player.isPlaying {
            player.pause()
            audioButton.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
            audioButton.setTitle("Play Audio", for: .normal)
        } else {
            player.play()
            audioButton.setImage(UIImage(systemName: "pause.circle.fill"), for: .normal)
            audioButton.setTitle("Pause Audio", for: .normal)
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
