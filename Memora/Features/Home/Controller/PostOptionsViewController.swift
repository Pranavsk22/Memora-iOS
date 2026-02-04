// PostOptionsViewController.swift
import UIKit
import SwiftUI

extension Notification.Name {
    static let memoriesUpdated = Notification.Name("memoriesUpdated")
}

class ScheduleDatePickerViewController: UIViewController {
    
    var onDateSelected: ((Date) -> Void)?
    
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let datePicker = UIDatePicker()
    private let durationSegments = UISegmentedControl(items: ["1 Week", "1 Month", "3 Months", "6 Months", "1 Year", "Custom"])
    private let scheduleButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    
    private let capsulePreview = UIView()
    private let capsuleIcon = UIImageView()
    private let capsuleLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        updateCapsulePreview(for: datePicker.date)
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(hex: "#F2F2F7")
        
        // Container
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 20
        containerView.clipsToBounds = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        // Title
        titleLabel.text = "Schedule Memory Capsule"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        // Duration segments
        durationSegments.selectedSegmentIndex = 1
        durationSegments.addTarget(self, action: #selector(durationChanged), for: .valueChanged)
        durationSegments.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(durationSegments)
        
        // Date picker
        datePicker.datePickerMode = .dateAndTime
        datePicker.preferredDatePickerStyle = .wheels
        datePicker.minimumDate = Date().addingTimeInterval(3600)
        datePicker.maximumDate = Date().addingTimeInterval(365 * 86400)
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(datePicker)
        
        // Capsule preview
        setupCapsulePreview()
        
        // Schedule button
        scheduleButton.setTitle("Schedule Capsule", for: .normal)
        scheduleButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        scheduleButton.backgroundColor = UIColor(hex: "#5AC8FA")
        scheduleButton.setTitleColor(.white, for: .normal)
        scheduleButton.layer.cornerRadius = 14
        scheduleButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(scheduleButton)
        
        // Cancel button
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.systemRed, for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 17)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(cancelButton)
        
        // Constraints
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 500),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            durationSegments.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            durationSegments.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            durationSegments.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            datePicker.topAnchor.constraint(equalTo: durationSegments.bottomAnchor, constant: 20),
            datePicker.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            datePicker.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            datePicker.heightAnchor.constraint(equalToConstant: 200),
            
            capsulePreview.topAnchor.constraint(equalTo: datePicker.bottomAnchor, constant: 20),
            capsulePreview.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            capsulePreview.widthAnchor.constraint(equalToConstant: 120),
            capsulePreview.heightAnchor.constraint(equalToConstant: 120),
            
            scheduleButton.topAnchor.constraint(equalTo: capsulePreview.bottomAnchor, constant: 24),
            scheduleButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 32),
            scheduleButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -32),
            scheduleButton.heightAnchor.constraint(equalToConstant: 56),
            
            cancelButton.topAnchor.constraint(equalTo: scheduleButton.bottomAnchor, constant: 12),
            cancelButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupCapsulePreview() {
        capsulePreview.backgroundColor = UIColor(hex: "#FFD700").withAlphaComponent(0.1)
        capsulePreview.layer.cornerRadius = 20
        capsulePreview.layer.borderWidth = 2
        capsulePreview.layer.borderColor = UIColor(hex: "#FFD700").withAlphaComponent(0.3).cgColor
        capsulePreview.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(capsulePreview)
        
        capsuleIcon.image = UIImage(systemName: "gift.fill")
        capsuleIcon.tintColor = UIColor(hex: "#FFD700")
        capsuleIcon.contentMode = .scaleAspectFit
        capsuleIcon.translatesAutoresizingMaskIntoConstraints = false
        capsulePreview.addSubview(capsuleIcon)
        
        capsuleLabel.text = "Gold Capsule"
        capsuleLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        capsuleLabel.textColor = UIColor(hex: "#FFD700")
        capsuleLabel.textAlignment = .center
        capsuleLabel.translatesAutoresizingMaskIntoConstraints = false
        capsulePreview.addSubview(capsuleLabel)
        
        NSLayoutConstraint.activate([
            capsuleIcon.centerXAnchor.constraint(equalTo: capsulePreview.centerXAnchor),
            capsuleIcon.centerYAnchor.constraint(equalTo: capsulePreview.centerYAnchor, constant: -10),
            capsuleIcon.widthAnchor.constraint(equalToConstant: 40),
            capsuleIcon.heightAnchor.constraint(equalToConstant: 40),
            
            capsuleLabel.topAnchor.constraint(equalTo: capsuleIcon.bottomAnchor, constant: 8),
            capsuleLabel.centerXAnchor.constraint(equalTo: capsulePreview.centerXAnchor),
            capsuleLabel.leadingAnchor.constraint(equalTo: capsulePreview.leadingAnchor, constant: 8),
            capsuleLabel.trailingAnchor.constraint(equalTo: capsulePreview.trailingAnchor, constant: -8)
        ])
    }
    
    private func setupActions() {
        datePicker.addTarget(self, action: #selector(datePickerChanged), for: .valueChanged)
        scheduleButton.addTarget(self, action: #selector(scheduleTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
    }
    
    @objc private func durationChanged() {
        let now = Date()
        let calendar = Calendar.current
        
        switch durationSegments.selectedSegmentIndex {
        case 0: datePicker.date = calendar.date(byAdding: .weekOfYear, value: 1, to: now) ?? now.addingTimeInterval(7 * 86400)
        case 1: datePicker.date = calendar.date(byAdding: .month, value: 1, to: now) ?? now.addingTimeInterval(30 * 86400)
        case 2: datePicker.date = calendar.date(byAdding: .month, value: 3, to: now) ?? now.addingTimeInterval(90 * 86400)
        case 3: datePicker.date = calendar.date(byAdding: .month, value: 6, to: now) ?? now.addingTimeInterval(180 * 86400)
        case 4: datePicker.date = calendar.date(byAdding: .year, value: 1, to: now) ?? now.addingTimeInterval(365 * 86400)
        default: break
        }
        
        updateCapsulePreview(for: datePicker.date)
    }
    
    @objc private func datePickerChanged() {
        updateCapsulePreview(for: datePicker.date)
    }
    
    private func updateCapsulePreview(for date: Date) {
        let duration = date.timeIntervalSince(Date())
        let days = Int(duration / 86400)
        
        let color: UIColor
        let icon: String
        let label: String
        
        if days >= 365 {
            color = UIColor(hex: "#FFD700")
            icon = "crown.fill"
            label = "Gold Capsule"
        } else if days >= 30 {
            color = UIColor(hex: "#C0C0C0")
            icon = "star.fill"
            label = "Silver Capsule"
        } else {
            color = UIColor(hex: "#CD7F32")
            icon = "heart.fill"
            label = "Bronze Capsule"
        }
        
        UIView.animate(withDuration: 0.3) {
            self.capsulePreview.backgroundColor = color.withAlphaComponent(0.1)
            self.capsulePreview.layer.borderColor = color.withAlphaComponent(0.3).cgColor
            self.capsuleIcon.tintColor = color
            self.capsuleLabel.textColor = color
            self.capsuleLabel.text = label
            self.capsuleIcon.image = UIImage(systemName: icon)
        }
    }
    
    @objc private func scheduleTapped() {
        onDateSelected?(datePicker.date)
        dismiss(animated: true)
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
}

final class PostOptionsViewController: UIViewController {
    weak var delegate: PostOptionsViewControllerDelegate?

    // MARK: — New: optional inputs from caller
    public var autoSaveToLocalStoreIfNoDelegate: Bool = true
    public var bodyText: String? = nil
    public var userImages: [UIImage] = []
    public var userAudioFiles: [(url: URL, duration: TimeInterval)] = []
    public var promptFallbackImageURL: String? = nil
    public var promptText: String? = nil // NEW: Added for prompt text

    // MARK: UI
    private let dimView = UIControl()
    private let container = UIView()
    private let headingLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let titleLabel = UILabel() // CHANGED: From titleField to titleLabel
    private let yearField = UITextField()

    // Visibility dropdown button
    private let visibilityButton = UIButton(type: .system)
    private var selectedVisibility: PostVisibility = .everyone {
        didSet {
            updateVisibilityButtonTitle()
            updateGroupSelectionVisibility()
        }
    }

    // Group selection
    private let groupSelectionStack = UIStackView()
    private let groupSelectionButton = UIButton(type: .system)
    private var selectedGroup: UserGroup?
    private var userGroups: [UserGroup] = []
    private var groupSelectionVisible: Bool = false

    // schedule
    private var selectedScheduleDate: Date = Date()
    private var scheduleChosen: Bool = false

    // buttons
    private let postButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)

    // SAVE loader UI
    private var savingOverlay: UIView?
    private var activityIndicator: UIActivityIndicatorView?

    // constraints for keyboard movement
    private var containerCenterY: NSLayoutConstraint?
    private var groupSelectionHeightConstraint: NSLayoutConstraint?

    // keyboard observers
    private var keyboardObserversAdded = false

    // Local enum for UI - DIFFERENT NAME to avoid conflict
    private enum PostVisibility {
        case everyone, `private`, scheduledPost, group
        var asMemoryVisibility: MemoryVisibility {
            switch self {
            case .everyone: return .everyone
            case .private: return .private
            case .scheduledPost: return MemoryVisibility.scheduled
            case .group: return .group
            }
        }
        var title: String {
            switch self {
            case .everyone: return "Everyone"
            case .private: return "Private"
            case .scheduledPost: return "Schedule"
            case .group: return "Group"
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        modalPresentationStyle = .overFullScreen
        view.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        setupUI()
        setupActions()
        updateVisibilityButtonTitle()
        updatePostButtonState()
        addKeyboardObservers()
        
        // Load user groups
        loadUserGroups()
        
        // NEW: Set prompt as title if available
        updateTitleFromPrompt()
    }

    deinit {
        removeKeyboardObservers()
    }

    // MARK: UI Setup
    private func setupUI() {
        // dim background to dismiss
        dimView.translatesAutoresizingMaskIntoConstraints = false
        dimView.backgroundColor = UIColor(white: 0, alpha: 0.28)
        view.addSubview(dimView)
        NSLayoutConstraint.activate([
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        dimView.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)

        // container
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .systemBackground
        container.layer.cornerRadius = 20
        container.clipsToBounds = true
        view.addSubview(container)

        // heading
        headingLabel.translatesAutoresizingMaskIntoConstraints = false
        headingLabel.text = "Post your memory"
        headingLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        headingLabel.textColor = .label
        container.addSubview(headingLabel)

        // description
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.numberOfLines = 0
        descriptionLabel.text = "A short description should be a short, complete sentence."
        descriptionLabel.font = UIFont.systemFont(ofSize: 15)
        descriptionLabel.textColor = .secondaryLabel
        container.addSubview(descriptionLabel)

        // title label (CHANGED: from text field to label)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Title will be set from prompt"
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        titleLabel.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        titleLabel.layer.cornerRadius = 8
        titleLabel.layer.masksToBounds = true
        titleLabel.isUserInteractionEnabled = true // Allow tap to edit if needed
        container.addSubview(titleLabel)
        
        // Add tap gesture to title label for editing if needed
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(titleLabelTapped))
        titleLabel.addGestureRecognizer(tapGesture)

        // year field
        yearField.translatesAutoresizingMaskIntoConstraints = false
        yearField.placeholder = "Year (e.g. 1999) (required)"
        yearField.borderStyle = .roundedRect
        yearField.keyboardType = .numberPad
        container.addSubview(yearField)

        // visibility capsule button
        visibilityButton.translatesAutoresizingMaskIntoConstraints = false
        visibilityButton.setTitleColor(.label, for: .normal)
        visibilityButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        visibilityButton.backgroundColor = UIColor(white: 0.95, alpha: 1)
        visibilityButton.layer.cornerRadius = 20
        visibilityButton.layer.masksToBounds = true
        visibilityButton.contentEdgeInsets = UIEdgeInsets(top: 14, left: 24, bottom: 14, right: 24)
        container.addSubview(visibilityButton)

        // Group selection stack (initially hidden)
        groupSelectionStack.axis = .vertical
        groupSelectionStack.spacing = 12
        groupSelectionStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(groupSelectionStack)

        // Group selection label
        let groupLabel = UILabel()
        groupLabel.text = "Select Group"
        groupLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        groupLabel.textColor = .secondaryLabel
        groupSelectionStack.addArrangedSubview(groupLabel)

        // Group selection button
        groupSelectionButton.translatesAutoresizingMaskIntoConstraints = false
        groupSelectionButton.setTitle("Tap to select group", for: .normal)
        groupSelectionButton.setTitleColor(.label, for: .normal)
        groupSelectionButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        groupSelectionButton.backgroundColor = UIColor(white: 0.96, alpha: 1)
        groupSelectionButton.layer.cornerRadius = 16
        groupSelectionButton.layer.masksToBounds = true
        groupSelectionButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        groupSelectionButton.contentHorizontalAlignment = .left
        groupSelectionStack.addArrangedSubview(groupSelectionButton)

        // post button
        postButton.translatesAutoresizingMaskIntoConstraints = false
        postButton.setTitle("Post", for: .normal)
        postButton.setTitleColor(.white, for: .normal)
        postButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        postButton.backgroundColor = .black
        postButton.layer.cornerRadius = 28
        postButton.layer.masksToBounds = true
        container.addSubview(postButton)

        // cancel
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.systemRed, for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 17)
        container.addSubview(cancelButton)

        // Layout constraints
        containerCenterY = container.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 0)
        containerCenterY?.isActive = true

        groupSelectionHeightConstraint = groupSelectionStack.heightAnchor.constraint(equalToConstant: 0)
        groupSelectionHeightConstraint?.isActive = true

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.88),
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 400),

            headingLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            headingLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            headingLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 18),

            descriptionLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            descriptionLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            descriptionLabel.topAnchor.constraint(equalTo: headingLabel.bottomAnchor, constant: 8),

            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            titleLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 18),
            titleLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),

            yearField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            yearField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            yearField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            yearField.heightAnchor.constraint(equalToConstant: 46),

            visibilityButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            visibilityButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            visibilityButton.topAnchor.constraint(equalTo: yearField.bottomAnchor, constant: 18),
            visibilityButton.heightAnchor.constraint(equalToConstant: 48),

            groupSelectionStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            groupSelectionStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            groupSelectionStack.topAnchor.constraint(equalTo: visibilityButton.bottomAnchor, constant: 0),

            postButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 36),
            postButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -36),
            postButton.topAnchor.constraint(equalTo: groupSelectionStack.bottomAnchor, constant: 22),
            postButton.heightAnchor.constraint(equalToConstant: 56),

            cancelButton.topAnchor.constraint(equalTo: postButton.bottomAnchor, constant: 12),
            cancelButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -18)
        ])
    }
    
    // MARK: - NEW: Update title from prompt
    private func updateTitleFromPrompt() {
        if let promptText = promptText, !promptText.isEmpty {
            titleLabel.text = promptText
        } else if let bodyText = bodyText, !bodyText.isEmpty {
            // Use body text as fallback
            titleLabel.text = bodyText
        }
    }
    
    // MARK: - NEW: Handle title label tap
    @objc private func titleLabelTapped() {
        // Allow editing title if needed
        let alert = UIAlertController(title: "Edit Title", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = self.titleLabel.text
            textField.placeholder = "Memory title"
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            if let newTitle = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
               !newTitle.isEmpty {
                self.titleLabel.text = newTitle
                self.updatePostButtonState()
            }
        })
        
        present(alert, animated: true)
    }

    // MARK: Setup Actions
    private func setupActions() {
        visibilityButton.addTarget(self, action: #selector(visibilityTapped), for: .touchUpInside)
        groupSelectionButton.addTarget(self, action: #selector(groupSelectionTapped), for: .touchUpInside)
        postButton.addTarget(self, action: #selector(postTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        // text change observers - only for year field now
        yearField.addTarget(self, action: #selector(textDidChange(_:)), for: .editingChanged)

        // navigate between fields
        yearField.delegate = self
    }

    // MARK: Load User Groups
    private func loadUserGroups() {
        Task {
            do {
                let groups = try await SupabaseManager.shared.getMyGroups()
                DispatchQueue.main.async {
                    self.userGroups = groups
                    print("✅ Loaded \(groups.count) groups for user")
                }
            } catch {
                print("❌ Failed to load user groups: \(error)")
            }
        }
    }

    // MARK: Update Group Selection Visibility
    private func updateGroupSelectionVisibility() {
        print("DEBUG: updateGroupSelectionVisibility called")
        
        guard self.view != nil else {
            print("DEBUG: View is nil, skipping animation")
            return
        }
        
        let shouldShow = (selectedVisibility == .group)
        groupSelectionVisible = shouldShow
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                print("DEBUG: self deallocated")
                return
            }
            
            guard self.view.window != nil else {
                print("DEBUG: View not in window hierarchy")
                return
            }
            
            UIView.animate(withDuration: 0.3) {
                self.groupSelectionHeightConstraint?.constant = shouldShow ? 80 : 0
                self.groupSelectionStack.alpha = shouldShow ? 1.0 : 0.0
                self.groupSelectionStack.isHidden = !shouldShow
                
                if self.view.window != nil {
                    self.view.layoutIfNeeded()
                }
            }
            
            self.updatePostButtonState()
        }
    }

    // MARK: Visibility dropdown
    @objc private func visibilityTapped() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: PostVisibility.everyone.title, style: .default, handler: { _ in
            self.selectedVisibility = .everyone
            self.scheduleChosen = false
            self.selectedGroup = nil
            self.updateGroupSelectionButtonTitle()
            self.updatePostButtonState()
        }))
        alert.addAction(UIAlertAction(title: PostVisibility.private.title, style: .default, handler: { _ in
            self.selectedVisibility = .private
            self.scheduleChosen = false
            self.selectedGroup = nil
            self.updateGroupSelectionButtonTitle()
            self.updatePostButtonState()
        }))
        alert.addAction(UIAlertAction(title: PostVisibility.scheduledPost.title, style: .default, handler: { _ in
            self.selectedVisibility = .scheduledPost
            self.selectedGroup = nil
            self.updateGroupSelectionButtonTitle()
            self.presentScheduleDatePicker()
        }))
        alert.addAction(UIAlertAction(title: PostVisibility.group.title, style: .default, handler: { _ in
            self.selectedVisibility = .group
            self.scheduleChosen = false
            self.updatePostButtonState()
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // For iPad
        if let p = alert.popoverPresentationController {
            p.sourceView = visibilityButton
            p.sourceRect = visibilityButton.bounds
        }

        present(alert, animated: true)
    }

    @objc private func groupSelectionTapped() {
        guard !userGroups.isEmpty else {
            showAlert(title: "No Groups", message: "You don't have any groups yet. Create or join a group first.")
            return
        }

        let alert = UIAlertController(title: "Select Group", message: nil, preferredStyle: .actionSheet)
        
        for group in userGroups {
            let isSelected = selectedGroup?.id == group.id
            let title = isSelected ? "✓ \(group.name)" : group.name
            
            alert.addAction(UIAlertAction(title: title, style: .default, handler: { _ in
                self.selectedGroup = group
                self.updateGroupSelectionButtonTitle()
                self.updatePostButtonState()
            }))
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let p = alert.popoverPresentationController {
            p.sourceView = groupSelectionButton
            p.sourceRect = groupSelectionButton.bounds
        }
        
        present(alert, animated: true)
    }

    private func updateGroupSelectionButtonTitle() {
        if let group = selectedGroup {
            groupSelectionButton.setTitle("Selected: \(group.name)", for: .normal)
            groupSelectionButton.setTitleColor(.systemBlue, for: .normal)
        } else {
            groupSelectionButton.setTitle("Tap to select group", for: .normal)
            groupSelectionButton.setTitleColor(.secondaryLabel, for: .normal)
        }
    }

    // MARK: - Schedule Memory Feature
    private func presentScheduleDatePicker() {
        let scheduleVC = ScheduleDatePickerViewController()
        scheduleVC.modalPresentationStyle = .pageSheet
        
        if let sheet = scheduleVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.selectedDetentIdentifier = .medium
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        
        scheduleVC.onDateSelected = { [weak self] date in
            self?.selectedScheduleDate = date
            self?.scheduleChosen = true
            self?.updateVisibilityButtonTitle()
            self?.updatePostButtonState()
            
            self?.showCapsulePreview(for: date)
        }
        
        present(scheduleVC, animated: true)
    }
    
    private func showCapsulePreview(for date: Date) {
        let duration = date.timeIntervalSince(Date())
        let days = Int(duration / 86400)
        
        let icon: String
        let color: UIColor
        
        if days >= 365 {
            icon = "crown.fill"
            color = UIColor(hex: "#FFD700")
        } else if days >= 30 {
            icon = "star.fill"
            color = UIColor(hex: "#C0C0C0")
        } else {
            icon = "heart.fill"
            color = UIColor(hex: "#CD7F32")
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        
        let message = """
        ✨ Memory Capsule Created ✨
        
        📅 Opens: \(dateFormatter.string(from: date))
        ⏳ Duration: \(formatDuration(duration))
        
        Your memory will be locked in a beautiful \(days >= 365 ? "Gold" : days >= 30 ? "Silver" : "Bronze") capsule until then!
        """
        
        let alert = UIAlertController(title: "Capsule Scheduled", message: message, preferredStyle: .alert)
        
        let imageView = UIImageView(image: UIImage(systemName: icon))
        imageView.tintColor = color
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        alert.view.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 45),
            imageView.widthAnchor.constraint(equalToConstant: 40),
            imageView.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        alert.addAction(UIAlertAction(title: "Got it!", style: .default))
        
        present(alert, animated: true)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let days = Int(duration / 86400)
        let hours = Int((duration.truncatingRemainder(dividingBy: 86400)) / 3600)
        
        if days > 0 {
            return "\(days) day\(days > 1 ? "s" : "") \(hours) hour\(hours > 1 ? "s" : "")"
        } else {
            let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours) hour\(hours > 1 ? "s" : "") \(minutes) minute\(minutes > 1 ? "s" : "")"
        }
    }

    private func updateVisibilityButtonTitle() {
        var title = selectedVisibility.title
        if selectedVisibility == .scheduledPost, scheduleChosen {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .short
            title = "Scheduled: \(f.string(from: selectedScheduleDate))"
        }
        let att = NSMutableAttributedString(string: title)
        visibilityButton.setAttributedTitle(att, for: .normal)
    }

    // MARK: Posting
    @objc private func postTapped() {
        guard let titleText = titleLabel.text?.trimmingCharacters(in: .whitespacesAndNewlines), !titleText.isEmpty else {
            showValidationError("Please set a title for your memory.")
            return
        }

        guard let yearText = yearField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !yearText.isEmpty else {
            showValidationError("Please enter the year (required).")
            return
        }

        if yearText.count != 4 || Int(yearText) == nil {
            showValidationError("Please enter a valid 4-digit year (e.g. 1999).")
            return
        }

        if selectedVisibility == .scheduledPost && !scheduleChosen {
            showValidationError("Please choose a schedule date and time.")
            return
        }

        if selectedVisibility == .group && selectedGroup == nil {
            showValidationError("Please select a group to share with.")
            return
        }

        let visibility = selectedVisibility.asMemoryVisibility
        let scheduleDate = selectedVisibility == .scheduledPost ? selectedScheduleDate : nil
        let selectedGroupId = selectedGroup

        if SupabaseManager.shared.isUserLoggedIn() {
            postToSupabaseWithSchedule(
                title: titleText,
                year: Int(yearText) ?? 2024,
                visibility: visibility,
                scheduleDate: scheduleDate,
                group: selectedGroupId
            )
        } else if let d = delegate {
            d.postOptionsViewController(self, didFinishPostingWithTitle: titleText, scheduleDate: scheduleDate, visibility: visibility)
        } else {
            postToLocalStorage(
                title: titleText,
                visibility: visibility,
                scheduleDate: scheduleDate
            )
        }
    }

    // MARK: Post to Supabase with Schedule Support
    private func postToSupabaseWithSchedule(
        title: String,
        year: Int,
        visibility: MemoryVisibility,
        scheduleDate: Date?,
        group: UserGroup?
    ) {
        showSavingOverlay()
        setControlsEnabled(false)
        
        print("DEBUG: Posting to Supabase with:")
        print("  Title: \(title)")
        print("  Year: \(year)")
        print("  Visibility: \(visibility)")
        print("  Schedule Date: \(scheduleDate?.description ?? "None")")
        print("  Group: \(group?.name ?? "None")")
        
        Task {
            do {
                if visibility == .scheduled, let scheduleDate = scheduleDate {
                    print("DEBUG: Creating scheduled memory...")
                    
                    let scheduledMemory = try await SupabaseManager.shared.scheduleMemory(
                        title: title,
                        year: year,
                        category: nil,
                        releaseDate: scheduleDate,
                        images: userImages,
                        audioFiles: userAudioFiles,
                        textContent: bodyText
                    )
                    
                    print("DEBUG: Scheduled memory created: \(scheduledMemory.id)")
                    
                    DispatchQueue.main.async {
                        self.hideSavingOverlay()
                        self.setControlsEnabled(true)
                        
                        let message = "Memory capsule scheduled! 🎁"
                        self.showToastAboveOverlay(message: message)
                        
                        NotificationCenter.default.post(
                            name: .memoriesUpdated,
                            object: nil,
                            userInfo: ["memoryId": scheduledMemory.id.uuidString]
                        )
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.dismiss(animated: true, completion: nil)
                        }
                    }
                    return
                }
                
                let memory: SupabaseMemory
                
                if let group = group, visibility == .group, let groupId = UUID(uuidString: group.id) {
                    print("DEBUG: Creating group-specific memory for group: \(group.name)")
                    
                    memory = try await SupabaseManager.shared.createMemory(
                        title: title,
                        year: year,
                        visibility: visibility,
                        scheduledDate: scheduleDate,
                        images: userImages,
                        audioFiles: userAudioFiles,
                        textContent: bodyText
                    )
                    
                    print("DEBUG: Memory created, now sharing with group...")
                    
                    try await SupabaseManager.shared.shareMemoryWithGroup(
                        memoryId: memory.id,
                        groupId: groupId
                    )
                    
                    print("DEBUG: Group sharing completed")
                    
                } else {
                    print("DEBUG: Creating regular memory")
                    memory = try await SupabaseManager.shared.createMemory(
                        title: title,
                        year: year,
                        visibility: visibility,
                        scheduledDate: scheduleDate,
                        images: userImages,
                        audioFiles: userAudioFiles,
                        textContent: bodyText
                    )
                    
                    print("DEBUG: Regular memory created successfully")
                    
                    if let group = group, let groupId = UUID(uuidString: group.id) {
                        print("DEBUG: Sharing regular memory with group: \(group.name)")
                        try await SupabaseManager.shared.shareMemoryWithGroup(
                            memoryId: memory.id,
                            groupId: groupId
                        )
                    }
                }
                
                DispatchQueue.main.async {
                    self.hideSavingOverlay()
                    self.setControlsEnabled(true)
                    
                    let message: String
                    if group != nil {
                        message = "Memory shared with \(group!.name) group!"
                    } else {
                        message = "Memory posted successfully!"
                    }
                    
                    self.showToastAboveOverlay(message: message)
                    
                    NotificationCenter.default.post(
                        name: .memoriesUpdated,
                        object: nil,
                        userInfo: ["memoryId": memory.id.uuidString]
                    )
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.dismiss(animated: true, completion: nil)
                    }
                }
                
            } catch {
                print("Supabase post failed: \(error)")
                
                let nsError = error as NSError
                print("Error domain: \(nsError.domain)")
                print("Error code: \(nsError.code)")
                print("Error description: \(nsError.localizedDescription)")
                
                DispatchQueue.main.async {
                    self.hideSavingOverlay()
                    self.setControlsEnabled(true)
                    
                    self.showAlertWithFallbackOption(
                        title: "Network Error",
                        message: "Failed to post to server: \(error.localizedDescription)\n\nSave locally instead?",
                        fallbackAction: {
                            self.postToLocalStorage(
                                title: title,
                                visibility: visibility,
                                scheduleDate: scheduleDate
                            )
                        }
                    )
                }
            }
        }
    }

    // MARK: Post to Local Storage (Fallback)
    private func postToLocalStorage(
        title: String,
        visibility: MemoryVisibility,
        scheduleDate: Date?
    ) {
        showSavingOverlay()
        setControlsEnabled(false)
        
        let body = (bodyText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) ? nil : bodyText
        
        let ownerId: String = {
            let raw = Session.shared.currentUser.id
            if let s = raw as? String { return s }
            if let u = raw as? UUID { return u.uuidString }
            return String(describing: raw)
        }()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var memAttachments: [MemoryAttachment] = []
            let group = DispatchGroup()

            for img in self.userImages {
                do {
                    let fname = try MemoryStore.shared.saveImageAttachment(img)
                    let ma = MemoryAttachment(kind: .image, filename: fname)
                    memAttachments.append(ma)
                } catch {
                    print("PostOptions: failed to save image attachment:", error)
                }
            }

            for audio in self.userAudioFiles {
                do {
                    let fname = try MemoryStore.shared.saveAudioAttachment(at: audio.url)
                    let ma = MemoryAttachment(kind: .audio, filename: fname)
                    memAttachments.append(ma)
                } catch {
                    print("PostOptions: failed to save audio attachment:", error)
                }
            }

            if !memAttachments.contains(where: { $0.kind == .image }),
               let fallback = self.promptFallbackImageURL,
               !fallback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let u = URL(string: fallback),
               (u.scheme?.starts(with: "http") ?? false) {
                group.enter()
                self.downloadImage(from: u, timeout: 15.0) { result in
                    switch result {
                    case .success(let img):
                        do {
                            let fname = try MemoryStore.shared.saveImageAttachment(img)
                            let ma = MemoryAttachment(kind: .image, filename: fname)
                            memAttachments.insert(ma, at: 0)
                        } catch {
                            print("PostOptions: failed to save downloaded prompt image:", error)
                        }
                    case .failure(let err):
                        print("PostOptions: couldn't download fallback prompt image:", err)
                    }
                    group.leave()
                }
            }

            let waitResult = group.wait(timeout: .now() + 20)
            if waitResult == .timedOut {
                print("PostOptions: fallback image download timed out")
            }

            MemoryStore.shared.createMemory(
                ownerId: ownerId,
                title: title,
                body: body,
                attachments: memAttachments,
                visibility: visibility,
                scheduledFor: scheduleDate
            ) { result in
                DispatchQueue.main.async {
                    self.hideSavingOverlay()
                    self.setControlsEnabled(true)
                    
                    switch result {
                    case .success(let memory):
                        NotificationCenter.default.post(
                            name: .memoriesUpdated,
                            object: nil,
                            userInfo: ["memoryId": memory.id]
                        )
                        
                        let message = visibility == .scheduled ?
                            "Memory capsule saved locally 🎁" :
                            "Memory saved locally"
                        
                        self.showToastAboveOverlay(message: message)
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                            self.dismiss(animated: true, completion: nil)
                        }
                        
                    case .failure(let err):
                        self.showValidationError("Failed saving memory: \(err.localizedDescription)")
                    }
                }
            }
        }
    }

    // MARK: Alert with Fallback Option
    private func showAlertWithFallbackOption(
        title: String,
        message: String,
        fallbackAction: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Save Locally", style: .default) { _ in
            fallbackAction()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }

    // MARK: Update Post Button State
    private func updatePostButtonState() {
        let titleOK = !(titleLabel.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let yearText = yearField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let yearOK = (yearText.count == 4 && Int(yearText) != nil)

        let visibilityOK: Bool = {
            switch selectedVisibility {
            case .scheduledPost:
                return scheduleChosen
            case .group:
                return selectedGroup != nil
            default:
                return true
            }
        }()

        let enabled = titleOK && yearOK && visibilityOK
        postButton.isEnabled = enabled
        postButton.alpha = enabled ? 1.0 : 0.55
    }

    // MARK: Helper Methods
    private func showValidationError(_ message: String) {
        let a = UIAlertController(title: "Missing info", message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func cancelTapped() {
        delegate?.postOptionsViewControllerDidCancel(self)
    }

    @objc private func dismissTapped() {
        view.endEditing(true)
    }

    @objc private func textDidChange(_ t: UITextField) {
        updatePostButtonState()
    }

    // MARK: Keyboard Handling
    private func addKeyboardObservers() {
        guard !keyboardObserversAdded else { return }
        keyboardObserversAdded = true
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)),
                                               name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)),
                                               name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    private func removeKeyboardObservers() {
        if keyboardObserversAdded {
            NotificationCenter.default.removeObserver(self)
            keyboardObserversAdded = false
        }
    }

    @objc private func keyboardWillShow(_ note: Notification) {
        guard let info = note.userInfo,
              let frameValue = info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curve = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else { return }

        let kbFrame = frameValue.cgRectValue
        let containerFrame = container.convert(container.bounds, to: view)
        let overlap = max(0, (containerFrame.maxY) - (view.bounds.height - kbFrame.height))
        containerCenterY?.constant = -overlap - 12

        let options = UIView.AnimationOptions(rawValue: curve << 16)
        UIView.animate(withDuration: duration, delay: 0, options: options) {
            self.view.layoutIfNeeded()
        }
    }

    @objc private func keyboardWillHide(_ note: Notification) {
        guard let info = note.userInfo,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curve = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else { return }
        containerCenterY?.constant = 0
        let options = UIView.AnimationOptions(rawValue: curve << 16)
        UIView.animate(withDuration: duration, delay: 0, options: options) {
            self.view.layoutIfNeeded()
        }
    }

    // MARK: Loader and Toast Methods
    private func showSavingOverlay() {
        DispatchQueue.main.async {
            if let existing = self.savingOverlay {
                print("[PostOptions] showSavingOverlay: overlay already present: \(existing)")
                return
            }

            guard let host = self.hostWindowView() else {
                print("[PostOptions] showSavingOverlay: no host window/view found")
                return
            }

            let overlay = UIView()
            overlay.backgroundColor = UIColor(white: 0, alpha: 0.35)
            overlay.translatesAutoresizingMaskIntoConstraints = false
            overlay.alpha = 0.0
            overlay.isUserInteractionEnabled = true

            let blur = UIBlurEffect(style: .systemMaterial)
            let blurView = UIVisualEffectView(effect: blur)
            blurView.layer.cornerRadius = 12
            blurView.layer.masksToBounds = true
            blurView.translatesAutoresizingMaskIntoConstraints = false

            let indicator = UIActivityIndicatorView(style: .large)
            indicator.translatesAutoresizingMaskIntoConstraints = false
            indicator.startAnimating()
            self.activityIndicator = indicator

            let lbl = UILabel()
            lbl.translatesAutoresizingMaskIntoConstraints = false
            lbl.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
            lbl.text = "Saving…"
            lbl.textColor = .label

            blurView.contentView.addSubview(indicator)
            blurView.contentView.addSubview(lbl)
            overlay.addSubview(blurView)
            host.addSubview(overlay)

            NSLayoutConstraint.activate([
                overlay.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: host.trailingAnchor),
                overlay.topAnchor.constraint(equalTo: host.topAnchor),
                overlay.bottomAnchor.constraint(equalTo: host.bottomAnchor),

                blurView.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
                blurView.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
                blurView.widthAnchor.constraint(equalToConstant: 160),
                blurView.heightAnchor.constraint(equalToConstant: 120),

                indicator.centerXAnchor.constraint(equalTo: blurView.centerXAnchor),
                indicator.topAnchor.constraint(equalTo: blurView.topAnchor, constant: 18),

                lbl.centerXAnchor.constraint(equalTo: blurView.centerXAnchor),
                lbl.topAnchor.constraint(equalTo: indicator.bottomAnchor, constant: 12)
            ])

            self.savingOverlay = overlay
            host.layoutIfNeeded()
            UIView.animate(withDuration: 0.18) { overlay.alpha = 1.0 }
        }
    }

    private func hideSavingOverlay() {
        DispatchQueue.main.async {
            self.activityIndicator?.stopAnimating()
            self.activityIndicator = nil
            if let overlay = self.savingOverlay {
                UIView.animate(withDuration: 0.18, animations: {
                    overlay.alpha = 0.0
                }, completion: { _ in
                    overlay.removeFromSuperview()
                })
            }
            self.savingOverlay = nil
        }
    }

    private func setControlsEnabled(_ enabled: Bool) {
        DispatchQueue.main.async {
            self.postButton.isEnabled = enabled
            self.cancelButton.isEnabled = enabled
            self.yearField.isEnabled = enabled
            self.visibilityButton.isEnabled = enabled
            self.groupSelectionButton.isEnabled = enabled
            self.postButton.alpha = enabled ? 1.0 : 0.55
        }
    }

    private func showToastAboveOverlay(message: String) {
        DispatchQueue.main.async {
            guard let host = self.hostWindowView() else { return }

            let toast = UILabel()
            toast.translatesAutoresizingMaskIntoConstraints = false
            toast.backgroundColor = UIColor(white: 0, alpha: 0.85)
            toast.textColor = .white
            toast.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
            toast.textAlignment = .center
            toast.text = message
            toast.layer.cornerRadius = 10
            toast.layer.masksToBounds = true
            toast.alpha = 0.0

            host.addSubview(toast)

            let safe = host.safeAreaLayoutGuide
            let centerX = toast.centerXAnchor.constraint(equalTo: host.centerXAnchor)
            let bottom = toast.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: 80)
            NSLayoutConstraint.activate([
                centerX,
                bottom,
                toast.widthAnchor.constraint(lessThanOrEqualToConstant: 340),
                toast.heightAnchor.constraint(equalToConstant: 44)
            ])
            host.layoutIfNeeded()

            bottom.constant = -48
            UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.6, options: [], animations: {
                toast.alpha = 1.0
                host.layoutIfNeeded()
            }, completion: { _ in
                UIView.animate(withDuration: 0.22, delay: 1.0, options: [], animations: {
                    toast.alpha = 0.0
                    bottom.constant = 80
                    host.layoutIfNeeded()
                }, completion: { _ in
                    toast.removeFromSuperview()
                })
            })
        }
    }

    private func hostWindowView() -> UIView? {
        if #available(iOS 13.0, *) {
            if let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) {
                if let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
                    return window
                }
                if let window = windowScene.windows.first(where: { $0.isHidden == false }) {
                    return window
                }
            }
        }

        if let w = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            return w
        }
        if let w = UIApplication.shared.windows.first(where: { $0.isHidden == false }) {
            return w
        }

        if let top = Self.topMostViewController() {
            return top.view
        }

        return self.view
    }

    private static func topMostViewController() -> UIViewController? {
        if #available(iOS 13.0, *) {
            if let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }),
               let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
                var top = window.rootViewController
                while let presented = top?.presentedViewController { top = presented }
                return top
            }
        }
        if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }), let root = window.rootViewController {
            var top = root
            while let presented = top.presentedViewController { top = presented }
            return top
        }
        return nil
    }
}

// MARK: UITextFieldDelegate
extension PostOptionsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - Async image downloader helper
extension PostOptionsViewController {
    private func downloadImage(from url: URL, timeout: TimeInterval = 15.0, completion: @escaping (Result<UIImage, Error>) -> Void) {
        var req = URLRequest(url: url)
        req.timeoutInterval = timeout
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = timeout
        cfg.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: cfg)
        let task = session.dataTask(with: req) { data, response, error in
            if let err = error { completion(.failure(err)); return }
            guard let d = data, let img = UIImage(data: d) else {
                let err = NSError(domain: "PostOptionsDownload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
                completion(.failure(err)); return
            }
            completion(.success(img))
        }
        task.resume()
    }
}
