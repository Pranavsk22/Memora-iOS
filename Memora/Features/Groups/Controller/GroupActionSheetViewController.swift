//
//  GroupActionSheetViewController.swift
//  Memora
//
//  Created by user@3 on 10/01/26.
//


import UIKit

protocol GroupActionSheetDelegate: AnyObject {
    func didSelectCreateGroup()
    func didSelectJoinGroup()
}

class GroupActionSheetViewController: UIViewController {
    
    weak var delegate: GroupActionSheetDelegate?
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemGroupedBackground
        view.layer.cornerRadius = 24
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.clipsToBounds = true
        return view
    }()
    
    private let grabberView: UIView = {
        let view = UIView()
        view.backgroundColor = .tertiaryLabel
        view.layer.cornerRadius = 2.5
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Create or Join Group"
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textAlignment = .center
        label.textColor = .label
        return label
    }()
    
    private let createButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Create New Group", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 12
        button.contentEdgeInsets = UIEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        button.semanticContentAttribute = .forceLeftToRight
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 10)
        return button
    }()
    
    private let joinButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Join with Code", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.setImage(UIImage(systemName: "person.badge.plus"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = .systemGreen
        button.layer.cornerRadius = 12
        button.contentEdgeInsets = UIEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        button.semanticContentAttribute = .forceLeftToRight
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 10)
        return button
    }()
    
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Cancel", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
        button.setTitleColor(.label, for: .normal)
        button.backgroundColor = .tertiarySystemFill
        button.layer.cornerRadius = 12
        return button
    }()
    
    private let overlayView = UIView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        animatePresentation()
    }
    
    private func setupUI() {
        // Clear background for fade effect
        view.backgroundColor = .clear
        
        // Add dark overlay
        overlayView.backgroundColor = .black.withAlphaComponent(0.35)
        overlayView.alpha = 0
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayView)
        view.sendSubviewToBack(overlayView)
        
        // Add container view
        containerView.transform = CGAffineTransform(translationX: 0, y: 400)
        containerView.alpha = 0
        view.addSubview(containerView)
        
        containerView.addSubview(grabberView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(createButton)
        containerView.addSubview(joinButton)
        containerView.addSubview(cancelButton)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        grabberView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        createButton.translatesAutoresizingMaskIntoConstraints = false
        joinButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Overlay view constraints
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // Container view constraints
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            containerView.heightAnchor.constraint(equalToConstant: 360),
            
            // Grabber
            grabberView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            grabberView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            grabberView.widthAnchor.constraint(equalToConstant: 36),
            grabberView.heightAnchor.constraint(equalToConstant: 5),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: grabberView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Create button
            createButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 32),
            createButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            createButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            createButton.heightAnchor.constraint(equalToConstant: 56),
            
            // Join button
            joinButton.topAnchor.constraint(equalTo: createButton.bottomAnchor, constant: 16),
            joinButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            joinButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            joinButton.heightAnchor.constraint(equalToConstant: 56),
            
            // Cancel button
            cancelButton.topAnchor.constraint(equalTo: joinButton.bottomAnchor, constant: 20),
            cancelButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            cancelButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            cancelButton.heightAnchor.constraint(equalToConstant: 56),
            cancelButton.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -40)
        ])
        
        // Add tap to dismiss on overlay
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapOutside))
        overlayView.addGestureRecognizer(tapGesture)
    }
    
    private func setupActions() {
        createButton.addTarget(self, action: #selector(createGroupTapped), for: .touchUpInside)
        joinButton.addTarget(self, action: #selector(joinGroupTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
    }
    
    private func animatePresentation() {
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            self.overlayView.alpha = 1
            self.containerView.transform = .identity
            self.containerView.alpha = 1
        })
    }
    
    private func animateDismissal(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.2, animations: {
            self.overlayView.alpha = 0
            self.containerView.transform = CGAffineTransform(translationX: 0, y: 400)
            self.containerView.alpha = 0
        }) { _ in
            self.dismiss(animated: false, completion: completion)
        }
    }
    
    @objc private func createGroupTapped() {
        print("Create group tapped")
        animateDismissal {
            self.delegate?.didSelectCreateGroup()
        }
    }
    
    @objc private func joinGroupTapped() {
        print("Join group tapped")
        animateDismissal {
            self.delegate?.didSelectJoinGroup()
        }
    }
    
    @objc private func cancelTapped() {
        print("Cancel tapped")
        animateDismissal()
    }
    
    @objc private func handleTapOutside() {
        animateDismissal()
    }
}
