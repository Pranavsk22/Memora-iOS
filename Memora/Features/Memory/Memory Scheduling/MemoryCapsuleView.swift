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

// UIKit wrapper for MemoryViewController
// Simpler UIKit-only MemoryCapsuleCell
class MemoryCapsuleCell: UICollectionViewCell {
    private let titleLabel = UILabel()
    private let dateLabel = UILabel()
    private let giftIcon = UIImageView()
    private var tapHandler: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        setupTapGesture()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
        setupTapGesture()
    }
    
    private func setup() {
        contentView.backgroundColor = UIColor(hex: "#5AC8FA").withAlphaComponent(0.1)
        contentView.layer.cornerRadius = 16
        contentView.layer.borderWidth = 2
        contentView.layer.borderColor = UIColor(hex: "#5AC8FA").cgColor
        contentView.clipsToBounds = true
        
        // Configure gift icon
        giftIcon.image = UIImage(systemName: "gift.fill")
        giftIcon.tintColor = UIColor(hex: "#5AC8FA")
        giftIcon.contentMode = .scaleAspectFit
        giftIcon.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(giftIcon)
        
        // Configure title label
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Configure date label
        dateLabel.font = UIFont.systemFont(ofSize: 12)
        dateLabel.textColor = .secondaryLabel
        dateLabel.textAlignment = .center
        dateLabel.numberOfLines = 2
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dateLabel)
        
        // Constraints
        NSLayoutConstraint.activate([
            giftIcon.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            giftIcon.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            giftIcon.widthAnchor.constraint(equalToConstant: 40),
            giftIcon.heightAnchor.constraint(equalToConstant: 40),
            
            titleLabel.topAnchor.constraint(equalTo: giftIcon.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            
            dateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            dateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            dateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            dateLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        contentView.addGestureRecognizer(tapGesture)
        contentView.isUserInteractionEnabled = true
    }
    
    @objc private func handleTap() {
        tapHandler?()
    }
    
    func configure(with memory: ScheduledMemory, tapHandler: (() -> Void)? = nil) {
        titleLabel.text = memory.title
        self.tapHandler = tapHandler
        
        let releaseDate = memory.releaseAt
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        if memory.isReadyToOpen {
            dateLabel.text = "Ready to open! 🎁"
            dateLabel.textColor = .systemGreen
            contentView.backgroundColor = UIColor(hex: "#5AC8FA").withAlphaComponent(0.3)
        } else {
            dateLabel.text = "Unlocks: \(formatter.string(from: releaseDate))"
            dateLabel.textColor = .secondaryLabel
            contentView.backgroundColor = UIColor(hex: "#5AC8FA").withAlphaComponent(0.1)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        dateLabel.text = nil
        tapHandler = nil
        contentView.backgroundColor = UIColor(hex: "#5AC8FA").withAlphaComponent(0.1)
        dateLabel.textColor = .secondaryLabel
    }
}
