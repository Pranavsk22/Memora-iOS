//
//  EnhancedScheduleDatePickerViewController.swift
//  Memora
//
//  Created by user@3 on 06/02/26.
//


// EnhancedScheduleDatePickerViewController.swift
import UIKit

class EnhancedScheduleDatePickerViewController: UIViewController {
    
    var userGroups: [UserGroup] = []
    var selectedGroups: [UserGroup] = []
    var onScheduleComplete: ((Date, [UserGroup]) -> Void)?
    
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let datePicker = UIDatePicker()
    private let scheduleButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    
    private let groupsTableView = UITableView()
    private let groupsLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
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
        
        // Date picker
        datePicker.datePickerMode = .dateAndTime
        datePicker.preferredDatePickerStyle = .wheels
        datePicker.minimumDate = Date().addingTimeInterval(3600)
        datePicker.maximumDate = Date().addingTimeInterval(365 * 86400)
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(datePicker)
        
        // Groups section
        groupsLabel.text = "Select Groups to Share With (Optional)"
        groupsLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        groupsLabel.textColor = .secondaryLabel
        groupsLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(groupsLabel)
        
        groupsTableView.register(GroupSelectionCell.self, forCellReuseIdentifier: "GroupCell")
        groupsTableView.dataSource = self
        groupsTableView.delegate = self
        groupsTableView.rowHeight = 60
        groupsTableView.separatorStyle = .none
        groupsTableView.backgroundColor = .clear
        groupsTableView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(groupsTableView)
        
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
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            datePicker.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            datePicker.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            datePicker.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            datePicker.heightAnchor.constraint(equalToConstant: 200),
            
            groupsLabel.topAnchor.constraint(equalTo: datePicker.bottomAnchor, constant: 20),
            groupsLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            groupsLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            groupsTableView.topAnchor.constraint(equalTo: groupsLabel.bottomAnchor, constant: 10),
            groupsTableView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            groupsTableView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            groupsTableView.heightAnchor.constraint(equalToConstant: min(CGFloat(userGroups.count * 60), 240)),
            
            
            scheduleButton.topAnchor.constraint(equalTo: groupsTableView.bottomAnchor, constant: 24),
            scheduleButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 32),
            scheduleButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -32),
            scheduleButton.heightAnchor.constraint(equalToConstant: 56),
            
            cancelButton.topAnchor.constraint(equalTo: scheduleButton.bottomAnchor, constant: 12),
            cancelButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
        
        let groupsHeight = min(CGFloat(userGroups.count * 60), 240)
        groupsTableViewHeightConstraint = groupsTableView.heightAnchor.constraint(equalToConstant: groupsHeight)
        groupsTableViewHeightConstraint?.isActive = true

        
    }
    private var groupsTableViewHeightConstraint: NSLayoutConstraint?
    
    private func setupActions() {
        scheduleButton.addTarget(self, action: #selector(scheduleTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
    }
    
    @objc private func scheduleTapped() {
        onScheduleComplete?(datePicker.date, selectedGroups)
        dismiss(animated: true)
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
}

// MARK: - UITableView DataSource & Delegate
extension EnhancedScheduleDatePickerViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return userGroups.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "GroupCell", for: indexPath) as! GroupSelectionCell
        let group = userGroups[indexPath.row]
        let isSelected = selectedGroups.contains(where: { $0.id == group.id })
        cell.configure(with: group, isSelected: isSelected)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let group = userGroups[indexPath.row]
        
        if let index = selectedGroups.firstIndex(where: { $0.id == group.id }) {
            selectedGroups.remove(at: index)
        } else {
            selectedGroups.append(group)
        }
        
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
}

// MARK: - Group Selection Cell
class GroupSelectionCell: UITableViewCell {
    private let nameLabel = UILabel()
    private let checkmarkImage = UIImageView()
    private let memberCountLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        
        // Checkmark
        checkmarkImage.image = UIImage(systemName: "circle")
        checkmarkImage.tintColor = .systemGray
        checkmarkImage.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(checkmarkImage)
        
        // Name label
        nameLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        nameLabel.textColor = .label
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)
        
        // Member count
        memberCountLabel.font = UIFont.systemFont(ofSize: 14)
        memberCountLabel.textColor = .secondaryLabel
        memberCountLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(memberCountLabel)
        
        NSLayoutConstraint.activate([
            checkmarkImage.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            checkmarkImage.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkmarkImage.widthAnchor.constraint(equalToConstant: 24),
            checkmarkImage.heightAnchor.constraint(equalToConstant: 24),
            
            nameLabel.leadingAnchor.constraint(equalTo: checkmarkImage.trailingAnchor, constant: 12),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            memberCountLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            memberCountLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
        
        
    }
    
    func configure(with group: UserGroup, isSelected: Bool) {
        nameLabel.text = group.name
        checkmarkImage.image = UIImage(systemName: isSelected ? "checkmark.circle.fill" : "circle")
        checkmarkImage.tintColor = isSelected ? UIColor(hex: "#5AC8FA") : .systemGray
        
        // You could fetch member count here if you want
        memberCountLabel.text = "👥"
    }
}
