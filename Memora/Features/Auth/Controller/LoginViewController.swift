import UIKit

class LoginViewController: UIViewController {
    
    @IBOutlet weak var textFieldView: UIView!
    @IBOutlet weak var emailTextFiled: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var infoStackView: UIStackView!
    
    // Add this for the password toggle button
    private let passwordToggleButton = UIButton(type: .custom)
    
    private let authState = AuthState.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupPasswordToggleButton() // Add this line
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    
    // MARK: - Setup UI (matches AuthViewController styling)
    private func setupUI() {
        
        textFieldView.layer.cornerRadius = 20
        textFieldView.clipsToBounds = true
        textFieldView.backgroundColor = .white
        
        infoStackView.arrangedSubviews.forEach { view in
            infoStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        let fields = [emailTextFiled, passwordTextField]
        fields.forEach { tf in
            guard let tf = tf else { return }
            tf.backgroundColor = .clear
            tf.borderStyle = .none
            tf.delegate = self
            tf.layer.sublayerTransform = CATransform3DMakeTranslation(10, 0, 0)
        }
        
        // Make sure password text field is secure by default
        passwordTextField.isSecureTextEntry = true
        
        addFieldWithSeparator(emailTextFiled)
        infoStackView.addArrangedSubview(passwordTextField)
        
        signInButton.layer.cornerRadius = 28
        signInButton.clipsToBounds = true
        signInButton.backgroundColor = .black
        signInButton.setTitleColor(.white, for: .normal)
        signInButton.addTarget(self, action: #selector(signInButtonPressed), for: .touchUpInside)
    }
    
    // MARK: - Password Toggle Button Setup
    private func setupPasswordToggleButton() {
        // Configure the eye button
        passwordToggleButton.tintColor = .lightGray
        passwordToggleButton.setImage(UIImage(systemName: "eye.slash"), for: .normal)
        passwordToggleButton.setImage(UIImage(systemName: "eye"), for: .selected)
        passwordToggleButton.addTarget(self, action: #selector(togglePasswordVisibility), for: .touchUpInside)
        
        // Create a container view for the button with proper padding
        let buttonContainer = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 30))
        passwordToggleButton.frame = CGRect(x: 7, y: 5, width: 24, height: 20)
        buttonContainer.addSubview(passwordToggleButton)
        
        // Set the button as right view of password text field
        passwordTextField.rightView = buttonContainer
        passwordTextField.rightViewMode = .always
    }
    
    @objc private func togglePasswordVisibility() {
        passwordTextField.isSecureTextEntry.toggle()
        passwordToggleButton.isSelected = !passwordTextField.isSecureTextEntry
        
        // This line is important to maintain cursor position
        if let existingText = passwordTextField.text, passwordTextField.isSecureTextEntry {
            passwordTextField.deleteBackward()
            passwordTextField.insertText(existingText)
        }
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
    
    @IBAction func signUpAction(_ sender: Any) {
        let signup = AuthViewController(nibName: "AuthViewController", bundle: nil)
        navigationController?.pushViewController(signup, animated: true)
    }
    
    @IBAction func forgotPasswordClicked(_ sender: Any) {
        let forgotPassword = ForgotPasswordViewController(nibName: "ForgotPasswordViewController", bundle: nil)
        navigationController?.pushViewController(forgotPassword, animated: true)
        print("Forgot password clicked")
    }
    
    // MARK: - Button Action
    @IBAction func signInButtonPressed(_ sender: UIButton) {
        validateAndLogin()
    }
    
    // MARK: - Validation
    
    private func validateAndLogin() {
        guard let email = emailTextFiled.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !email.isEmpty else {
            showAlert("Please enter your email.")
            return
        }
        
        guard isValidEmail(email) else {
            showAlert("Please enter a valid email address.")
            return
        }
        
        guard let password = passwordTextField.text,
              !password.isEmpty else {
            showAlert("Please enter your password.")
            return
        }
        
        if password.count < 6 {
            showAlert("Password must be at least 6 characters long.")
            return
        }
        
        // Show loading indicator
        let loadingAlert = UIAlertController(title: nil, message: "Signing in...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true, completion: nil)
        
        Task {
            let success = await authState.signIn(email: email, password: password)
            
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    if success {
                        // Save login state
                        UserDefaults.standard.set(true, forKey: "isLoggedIn")
                        self.proceedToHomeScreen()
                    } else {
                        self.showAlert("Login failed. Please check your credentials.")
                    }
                }
            }
        }
    }

    private func proceedToHomeScreen() {
        let storyboard = UIStoryboard(name: "TabScreens", bundle: nil)
        if let tabBar = storyboard.instantiateInitialViewController() {
            tabBar.modalPresentationStyle = .fullScreen
            
            // Smooth transition to home
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: {
                    window.rootViewController = tabBar
                }, completion: nil)
            }
        }
    }
    
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        return NSPredicate(format: "SELF MATCHES %@", emailRegEx).evaluate(with: email)
    }
    
    
    // MARK: - Alerts
    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: "Invalid Input", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailTextFiled {
            passwordTextField.becomeFirstResponder()
        } else if textField == passwordTextField {
            textField.resignFirstResponder()
            signInButtonPressed(signInButton)
        }
        return true
    }
}
