import UIKit
import Helpers

// Add this protocol at the top
protocol JoinGroupDelegate: AnyObject {
    func didJoinGroupSuccessfully()
    func didSendJoinRequest()
}

class JoinGroupModalViewController: UIViewController {
    
    @IBOutlet weak var codeTextField: UITextField!
    @IBOutlet weak var joinButton: UIButton!
    @IBOutlet weak var cardView: UIView!
    
    // Add delegate property
    weak var delegate: JoinGroupDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Join Group"
        view.backgroundColor = .systemGroupedBackground
        
        setupNavigationBar()
        setupUI()
    }
    
    private func setupNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(close)
        )
        navigationItem.leftBarButtonItem?.tintColor = .label
    }
    
    private func setupUI() {
        cardView.layer.cornerRadius = 20
        cardView.backgroundColor = .secondarySystemGroupedBackground
        cardView.layer.borderWidth = 0.5
        cardView.layer.borderColor = UIColor.separator.withAlphaComponent(0.25).cgColor
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.1
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cardView.layer.shadowRadius = 4
        
        codeTextField.layer.cornerRadius = 12
        codeTextField.layer.borderWidth = 1
        codeTextField.layer.borderColor = UIColor.separator.cgColor
        codeTextField.backgroundColor = .tertiarySystemGroupedBackground
        codeTextField.placeholder = "Enter 6-digit code"
        codeTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: codeTextField.frame.height))
        codeTextField.leftViewMode = .always
        codeTextField.autocapitalizationType = .allCharacters
        codeTextField.clearButtonMode = .whileEditing
        
        joinButton.layer.cornerRadius = 12
        joinButton.backgroundColor = .systemBlue
        joinButton.setTitleColor(.white, for: .normal)
        joinButton.layer.shadowColor = UIColor.black.cgColor
        joinButton.layer.shadowOpacity = 0.15
        joinButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        joinButton.layer.shadowRadius = 4
        
        codeTextField.becomeFirstResponder()
    }
    
    @IBAction func joinPressed(_ sender: UIButton) {
        let code = codeTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
        
        if code.isEmpty {
            showAlert(title: "Error", message: "Please enter a group code")
            return
        }
        
        if code.count != 6 {
            showAlert(title: "Error", message: "Group code must be 6 characters")
            return
        }
        
        processJoinRequest(with: code)
    }
    
    private func processJoinRequest(with code: String) {
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        print("Looking for group with code: '\(cleanCode)'")
        
        let loadingAlert = UIAlertController(title: nil, message: "Finding group...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
        
        Task {
            do {
                // Use .execute() instead of .single() to handle the array response
                let response = try await SupabaseManager.shared.client
                    .from("groups")
                    .select("*")
                    .eq("code", value: cleanCode)
                    .execute()
                
                let jsonString = String(data: response.data, encoding: .utf8) ?? "No data"
                print("Response: \(jsonString)")
                
                // Parse the response as an array
                let groups = try SupabaseManager.shared.jsonDecoder.decode([UserGroup].self, from: response.data)
                
                if groups.isEmpty {
                    DispatchQueue.main.async {
                        loadingAlert.dismiss(animated: true) {
                            self.showAlert(title: "Not Found", message: "No group found with code '\(cleanCode)'")
                        }
                    }
                    return
                }
                
                let group = groups[0]
                print("Found group: \(group.name) (ID: \(group.id))")
                
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        self.checkMembershipAndSendRequest(group: group)
                    }
                }
                
            } catch {
                print("Error finding group: \(error)")
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        self.showAlert(title: "Error", message: "Could not find group: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func checkMembershipAndSendRequest(group: UserGroup) {
        print(" DEBUG: Starting membership check for group: \(group.id)")
        
        let checkingAlert = UIAlertController(title: nil, message: "Checking status...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        checkingAlert.view.addSubview(loadingIndicator)
        present(checkingAlert, animated: true)
        
        Task {
            do {
                print(" DEBUG: Step 1 - Checking if user is member...")
                
                // Check if already a member
                let isMember = try await SupabaseManager.shared.checkIfUserIsMember(groupId: group.id)
                print(" DEBUG: Is member? \(isMember)")
                
                if isMember {
                    DispatchQueue.main.async {
                        checkingAlert.dismiss(animated: true) {
                            self.showAlert(title: "Already Member", message: "You are already a member of this group")
                        }
                    }
                    return
                }
                
                print(" DEBUG: Step 2 - Checking for existing requests...")
                
                // Check if already has pending request
                let hasPendingRequest = try await SupabaseManager.shared.checkExistingJoinRequest(groupId: group.id)
                print(" DEBUG: Has pending request? \(hasPendingRequest)")
                
                if hasPendingRequest {
                    DispatchQueue.main.async {
                        checkingAlert.dismiss(animated: true) {
                            self.showAlert(title: "Request Pending", message: "You already have a pending request to join this group")
                        }
                    }
                    return
                }
                
                print(" DEBUG: Step 3 - Creating join request...")
                
                // Send join request
                try await SupabaseManager.shared.createJoinRequest(groupId: group.id)
                print(" DEBUG: Join request created successfully!")
                
                DispatchQueue.main.async {
                    checkingAlert.dismiss(animated: true) {
                        self.showSuccessAlert(group: group)
                    }
                }
                
            } catch {
                print(" DEBUG: Error in checkMembershipAndSendRequest: \(error)")
                print(" DEBUG: Error details: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    checkingAlert.dismiss(animated: true) {
                        self.showAlert(title: "Error", message: "Could not process request: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func showSuccessAlert(group: UserGroup) {
        let alert = UIAlertController(
            title: "Request Sent!",
            message: "Your request to join '\(group.name)' has been sent to the group admin for approval.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.delegate?.didSendJoinRequest()
            self.dismissViewController()
        })
        
        present(alert, animated: true)
    }
    
    private func dismissViewController() {
        // Delegate already notified, just dismiss
        dismiss(animated: true)
    }
    
    @objc private func close() {
        dismiss(animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
