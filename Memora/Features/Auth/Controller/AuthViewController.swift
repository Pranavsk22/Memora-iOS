import UIKit

class AuthViewController: UIViewController {
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var confirmPassTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    
    @IBOutlet weak var infoStackView: UIStackView!
    @IBOutlet weak var createAccountButton: UIButton!
    
    @IBOutlet weak var textFieldContainerView: UIView!
    
    private let authState = AuthState.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    

    private func setupUI() {
        
        textFieldContainerView.layer.cornerRadius = 20
        textFieldContainerView.clipsToBounds = true
        textFieldContainerView.backgroundColor = .white
        
        let textFields = [nameTextField, emailTextField, passwordTextField, confirmPassTextField]
        textFields.forEach { textField in
            guard let textField = textField else { return }
            textField.backgroundColor = .clear
            textField.borderStyle = .none
            textField.delegate = self
            textField.layer.sublayerTransform = CATransform3DMakeTranslation(10, 0, 0)
        }
        
        
        infoStackView.arrangedSubviews.forEach { infoStackView.removeArrangedSubview($0); $0.removeFromSuperview() }
        
        
        addFieldWithSeparator(nameTextField)
        addFieldWithSeparator(emailTextField)
        addFieldWithSeparator(passwordTextField)
        
       
        infoStackView.addArrangedSubview(confirmPassTextField)
       
        createAccountButton.layer.cornerRadius = 28
        createAccountButton.clipsToBounds = true
        createAccountButton.backgroundColor = .black
        createAccountButton.setTitleColor(.white, for: .normal)
        createAccountButton.addTarget(self, action: #selector(createAccountButtonTapped), for: .touchUpInside)
    }
    
   
    private func addFieldWithSeparator(_ field: UITextField) {
        infoStackView.addArrangedSubview(field)
        infoStackView.addArrangedSubview(makeSeparator())
    }
    
    
    private func makeSeparator() -> UIView {
        let separator = UIView()
        separator.backgroundColor = UIColor(white: 0.9, alpha: 1)
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return separator
    }
    
    @objc private func createAccountButtonTapped() {
        print("Button tapped - starting validation")
        dismissKeyboard()
        validateAndCreateAccount()
    }
    
    private func validateAndCreateAccount() {
        guard let name = nameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            print("Name validation failed")
            showAlert(title: "Invalid Name", message: "Please enter your name.")
            return
        }
        
        guard name.count >= 2 else {
            print("Name too short")
            showAlert(title: "Invalid Name", message: "Name must be at least 2 characters long.")
            return
        }
        
        guard let email = emailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !email.isEmpty else {
            print("Email validation failed")
            showAlert(title: "Invalid Email", message: "Please enter your email address.")
            return
        }
        
        guard isValidEmail(email) else {
            print("Email format invalid")
            showAlert(title: "Invalid Email", message: "Please enter a valid email address.")
            return
        }
        
        guard let password = passwordTextField.text,
              !password.isEmpty else {
            print("Password validation failed")
            showAlert(title: "Invalid Password", message: "Please enter a password.")
            return
        }
        
        guard password.count >= 8 else {
            print("Password too short")
            showAlert(title: "Weak Password", message: "Password must be at least 8 characters long.")
            return
        }
        
        guard let confirmPassword = confirmPassTextField.text,
              !confirmPassword.isEmpty else {
            print("Confirm password validation failed")
            showAlert(title: "Missing Confirmation", message: "Please confirm your password.")
            return
        }
        
        guard password == confirmPassword else {
            print("Passwords don't match")
            showAlert(title: "Password Mismatch", message: "Passwords do not match. Please try again.")
            return
        }
        
        print("All validations passed - Creating account with Supabase")
        createAccountWithSupabase(name: name, email: email, password: password)
    }

    private func createAccountWithSupabase(name: String, email: String, password: String) {
        // Show loading indicator
        let loadingAlert = UIAlertController(title: nil, message: "Creating account...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true, completion: nil)
        
        Task {
            do {
                // Call SupabaseManager directly instead of through AuthState
                try await SupabaseManager.shared.signUp(name: name, email: email, password: password)
                
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        self.showSuccessAlert(name: name, email: email)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        self.showAlert(title: "Sign Up Failed", message: error.localizedDescription)
                    }
                }
            }
        }
    }

    private func showSuccessAlert(name: String, email: String) {
        let alert = UIAlertController(
            title: "Account Created!",
            message: "Welcome to Memora, \(name)!",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { [weak self] _ in
            self?.navigateToHome()
        })
        
        present(alert, animated: true, completion: nil)
    }

    private func navigateToHome() {
        // Directly navigate to home screen
        let storyboard = UIStoryboard(name: "TabScreens", bundle: nil)
        if let tabBar = storyboard.instantiateInitialViewController() {
            tabBar.modalPresentationStyle = .fullScreen
            
            // Dismiss any presented view controllers first
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: {
                    window.rootViewController = tabBar
                }, completion: nil)
            }
        }
    }
    
    // MARK: - Validation Helper Methods
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    @IBAction func signInPressed(_ sender: Any) {
        let signin = LoginViewController(nibName: "LoginViewController", bundle: nil)
        navigationController?.pushViewController(signin, animated: true)
    }
    
    // MARK: - Alert Methods
    private func showAlert(title: String, message: String) {
        print("Showing alert: \(title) - \(message)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            
            if self.presentedViewController != nil {
                print("Already presenting a view controller")
                self.dismiss(animated: false) {
                    self.present(alert, animated: true, completion: nil)
                }
            } else {
                self.present(alert, animated: true, completion: {
                    print("Alert presented successfully")
                })
            }
        }
    }
}

// MARK: - UITextFieldDelegate
extension AuthViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case nameTextField:
            emailTextField.becomeFirstResponder()
        case emailTextField:
            passwordTextField.becomeFirstResponder()
        case passwordTextField:
            confirmPassTextField.becomeFirstResponder()
        case confirmPassTextField:
            textField.resignFirstResponder()
            createAccountButtonTapped()
        default:
            textField.resignFirstResponder()
        }
        return true
    }
}
