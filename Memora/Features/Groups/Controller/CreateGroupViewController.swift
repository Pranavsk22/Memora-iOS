import UIKit

// Add this protocol at the top of the file
protocol CreateGroupDelegate: AnyObject {
    func didCreateGroupSuccessfully()
}

class CreateGroupViewController: UIViewController {
    
    @IBOutlet weak var groupNameTextField: UITextField!
    @IBOutlet weak var createButton: UIButton!
    @IBOutlet weak var cardView: UIView!
    
    // Add delegate property
    weak var delegate: CreateGroupDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupNavigationBar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        groupNameTextField.becomeFirstResponder()
    }
    
    private func setupNavigationBar() {
        title = "Create Group"
        
        // Add close button
        let closeButton = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )
        navigationItem.leftBarButtonItem = closeButton
    }
    
    private func setupUI() {
        // Card view styling
        cardView.layer.cornerRadius = 20
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.1
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cardView.layer.shadowRadius = 8
        
        // Text field styling
        groupNameTextField.layer.cornerRadius = 12
        groupNameTextField.layer.borderWidth = 1
        groupNameTextField.layer.borderColor = UIColor.systemGray4.cgColor
        
        // Add left padding
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: groupNameTextField.frame.height))
        groupNameTextField.leftView = paddingView
        groupNameTextField.leftViewMode = .always
        
        // Button styling
        createButton.layer.cornerRadius = 12
        createButton.layer.masksToBounds = true
    }
    
    @IBAction func createButtonTapped(_ sender: UIButton) {
        createGroup()
    }
    
    private func createGroup() {
        guard let groupName = groupNameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !groupName.isEmpty else {
            showAlert(title: "Error", message: "Please enter a group name")
            return
        }
        
        if groupName.count < 3 {
            showAlert(title: "Error", message: "Group name must be at least 3 characters")
            return
        }
        
        print(" CreateGroupVC: Starting group creation: \(groupName)")
        
        // Disable button and show loading
        createButton.isEnabled = false
        createButton.setTitle("Creating...", for: .normal)
        
        Task {
            do {
                print(" CreateGroupVC: Calling SupabaseManager.createGroup...")
                let group = try await SupabaseManager.shared.createGroup(name: groupName)
                
                DispatchQueue.main.async {
                    print(" CreateGroupVC: Group created successfully: \(group.name)")
                    self.createButton.isEnabled = true
                    self.createButton.setTitle("Create Group", for: .normal)
                    
                    // Notify delegate
                    self.delegate?.didCreateGroupSuccessfully()
                    
                    self.showSuccessAlert(group: group)
                }
            } catch {
                DispatchQueue.main.async {
                    print(" CreateGroupVC: Error: \(error.localizedDescription)")
                    self.createButton.isEnabled = true
                    self.createButton.setTitle("Create Group", for: .normal)
                    self.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func showSuccessAlert(group: UserGroup) {
        let alert = UIAlertController(
            title: "Group Created!",
            message: "Your group '\(group.name)' has been created.\n\nGroup Code: \(group.code)\n\nShare this code with others to join.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Copy Code", style: .default) { _ in
            UIPasteboard.general.string = group.code
            self.dismissViewController()
        })
        
        alert.addAction(UIAlertAction(title: "Share Code", style: .default) { _ in
            self.shareGroupCode(code: group.code, groupName: group.name)
        })
        
        alert.addAction(UIAlertAction(title: "Done", style: .cancel) { _ in
            self.dismissViewController()
        })
        
        present(alert, animated: true)
    }
    
    private func shareGroupCode(code: String, groupName: String) {
        let text = "Join my group '\(groupName)' on Memora!\n\nUse code: \(code)"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        present(activityVC, animated: true)
    }
    
    private func dismissViewController() {
        // Check if we should notify delegate (already notified in createGroup)
        // The delegate might want to refresh immediately
        
        if let navigationController = navigationController {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
    
    @objc private func closeTapped() {
        if let navigationController = navigationController {
            if navigationController.viewControllers.first == self {
                navigationController.dismiss(animated: true)
            } else {
                navigationController.popViewController(animated: true)
            }
        } else {
            dismiss(animated: true)
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
