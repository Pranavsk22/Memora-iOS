//
//  MemoryCapsuleView.swift
//  Memora
//
//  Created by user@3 on 03/02/26.
//


// CapsuleScheduleView.swift
import SwiftUI
import UIKit

// SwiftUI View for capsule
struct MemoryCapsuleView: View {
    let memory: ScheduledMemory
    let onTap: () -> Void
    @State private var isPulsing = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                // Animated gift box icon
                ZStack {
                    Circle()
                        .fill(capsuleStyle.accentColor.opacity(0.15))
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .stroke(capsuleStyle.accentColor, lineWidth: 2)
                        .frame(width: 80, height: 80)
                    
                    // Animated glow
                    Circle()
                        .fill(capsuleStyle.glowColor)
                        .frame(width: 80, height: 80)
                        .scaleEffect(isPulsing ? 1.1 : 0.9)
                        .opacity(isPulsing ? 0.5 : 0.2)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true),
                            value: isPulsing
                        )
                    
                    // Gift box icon
                    Image(systemName: memory.isReadyToOpen ? "gift.fill" : "gift")
                        .font(.system(size: 32))
                        .foregroundColor(capsuleStyle.accentColor)
                }
                
                // Title
                Text(memory.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                
                // Timer
                if !memory.isReadyToOpen {
                    VStack(spacing: 4) {
                        // Progress ring
                        ZStack {
                            Circle()
                                .stroke(capsuleStyle.backgroundColor.opacity(0.3), lineWidth: 4)
                                .frame(width: 50, height: 50)
                            
                            Circle()
                                .trim(from: 0, to: memory.progressPercentage)
                                .stroke(
                                    capsuleStyle.accentColor,
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                )
                                .frame(width: 50, height: 50)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 0.3), value: memory.progressPercentage)
                            
                            Text(memory.formattedTimeRemaining)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(capsuleStyle.accentColor)
                        }
                        
                        Text("Until unlock")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                } else {
                    // Ready to open state
                    VStack(spacing: 4) {
                        Text("Ready!")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#FF6B6B"))
                        
                        Text("Tap to open")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#FF6B6B").opacity(0.1))
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: "#FFFFFF"))
                    .shadow(
                        color: capsuleStyle.accentColor.opacity(0.15),
                        radius: 10,
                        x: 0,
                        y: 4
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(capsuleStyle.accentColor.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .onAppear {
            isPulsing = true
        }
    }
    
    private var capsuleStyle: CapsuleStyle {
        let duration = memory.releaseAt.timeIntervalSince(memory.createdAt)
        return CapsuleStyle.styleForDuration(duration)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Fixed MemoryCapsuleCell (Visible Ready State)
class MemoryCapsuleCell: UICollectionViewCell {
    static let reuseId = "CapsuleCell"
    
    // UI Elements
    private let containerView = UIView()
    private let iconCircle = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let timerLabel = UILabel()
    private let statusBadge = UIView()
    private let statusLabel = UILabel()
    
    // Timer Logic
    private var timer: Timer?
    private var releaseDate: Date?
    private var tapHandler: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // 1. Cell Shadow
        backgroundColor = .clear
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 12
        layer.masksToBounds = false
        
        // 2. Main Container
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.layer.cornerRadius = 20
        containerView.layer.cornerCurve = .continuous
        containerView.clipsToBounds = true
        containerView.backgroundColor = .secondarySystemBackground
        contentView.addSubview(containerView)
        
        // 3. Icon Circle
        iconCircle.translatesAutoresizingMaskIntoConstraints = false
        iconCircle.backgroundColor = .systemBackground
        iconCircle.layer.cornerRadius = 24
        iconCircle.layer.shadowColor = UIColor.black.cgColor
        iconCircle.layer.shadowOpacity = 0.05
        iconCircle.layer.shadowOffset = CGSize(width: 0, height: 2)
        iconCircle.layer.shadowRadius = 4
        containerView.addSubview(iconCircle)
        
        // 4. Icon Image
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .systemBlue
        iconCircle.addSubview(iconImageView)
        
        // 5. Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        containerView.addSubview(titleLabel)
        
        // 6. Timer/Date Label
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        timerLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        timerLabel.textColor = .secondaryLabel
        timerLabel.textAlignment = .center
        containerView.addSubview(timerLabel)
        
        // 7. Status Badge
        statusBadge.translatesAutoresizingMaskIntoConstraints = false
        statusBadge.backgroundColor = UIColor.systemGray6
        statusBadge.layer.cornerRadius = 10
        containerView.addSubview(statusBadge)
        
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .systemFont(ofSize: 10, weight: .bold)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusBadge.addSubview(statusLabel)
        
        // Constraints
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            iconCircle.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            iconCircle.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconCircle.widthAnchor.constraint(equalToConstant: 48),
            iconCircle.heightAnchor.constraint(equalToConstant: 48),
            
            iconImageView.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.topAnchor.constraint(equalTo: iconCircle.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            timerLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            timerLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            timerLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            statusBadge.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            statusBadge.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            statusBadge.heightAnchor.constraint(equalToConstant: 20),
            
            statusLabel.leadingAnchor.constraint(equalTo: statusBadge.leadingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(equalTo: statusBadge.trailingAnchor, constant: -8),
            statusLabel.centerYAnchor.constraint(equalTo: statusBadge.centerYAnchor)
        ])
    }
    
    private func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        contentView.addGestureRecognizer(tap)
    }
    
    @objc private func handleTap() {
        UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseOut) {
            self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        } completion: { _ in
            UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseOut) {
                self.transform = .identity
            }
        }
        tapHandler?()
    }
    
    // MARK: - Configuration
    
    func configure(with memory: ScheduledMemory, tapHandler: (() -> Void)?) {
        self.tapHandler = tapHandler
        self.releaseDate = memory.releaseAt
        titleLabel.text = memory.title
        
        stopTimer()
        
        if memory.isReadyToOpen {
            configureReadyState()
        } else {
            configureLockedState()
            startTimer()
        }
    }
    
    private func startTimer() {
        updateCountdown()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCountdown()
        }
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateCountdown() {
        guard let releaseDate = releaseDate else { return }
        let diff = releaseDate.timeIntervalSince(Date())
        
        if diff <= 0 {
            stopTimer()
            configureReadyState()
            return
        }
        
        let days = Int(diff) / 86400
        let hours = Int(diff) / 3600 % 24
        let minutes = Int(diff) / 60 % 60
        let seconds = Int(diff) % 60
        
        if days > 1 {
            timerLabel.text = "\(days) days left"
        } else if days == 1 {
            timerLabel.text = "1 day left"
        } else {
            timerLabel.text = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }
    
    private func configureReadyState() {
        // FIX: Set a solid blue background color so white text is visible
        containerView.backgroundColor = UIColor(hex: "#5AC8FA")
        
        // UI Styling for Ready State
        iconCircle.backgroundColor = .white.withAlphaComponent(0.2)
        iconImageView.image = UIImage(systemName: "gift.fill")
        iconImageView.tintColor = .white
        
        titleLabel.textColor = .white
        
        timerLabel.text = "Tap to open!"
        timerLabel.textColor = .white.withAlphaComponent(0.9)
        
        statusBadge.backgroundColor = .white.withAlphaComponent(0.2)
        statusLabel.text = "READY"
        statusLabel.textColor = .white
        
        // Pulse Animation
        iconCircle.layer.removeAllAnimations()
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.duration = 1.2
        pulse.fromValue = 1.0
        pulse.toValue = 1.05
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        iconCircle.layer.add(pulse, forKey: "pulse")
    }
    
    private func configureLockedState() {
        // Standard Grey Background
        containerView.backgroundColor = .secondarySystemBackground
        
        // UI Styling for Locked State
        iconCircle.backgroundColor = .systemBackground
        iconImageView.image = UIImage(systemName: "lock.fill")
        iconImageView.tintColor = .secondaryLabel
        
        titleLabel.textColor = .label
        timerLabel.textColor = .secondaryLabel
        
        statusBadge.backgroundColor = .systemGray5
        statusLabel.text = "LOCKED"
        statusLabel.textColor = .secondaryLabel
        
        iconCircle.layer.removeAllAnimations()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        stopTimer()
        iconCircle.layer.removeAllAnimations()
        titleLabel.text = nil
        timerLabel.text = nil
    }
}
