import UIKit

class LoginViewController: UIViewController {
    
    @IBOutlet weak var textFieldView: UIView!
    @IBOutlet weak var emailTextFiled: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var infoStackView: UIStackView!
    
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
        
       
        addFieldWithSeparator(emailTextFiled)
        infoStackView.addArrangedSubview(passwordTextField)
        
   
        signInButton.layer.cornerRadius = 28
        signInButton.clipsToBounds = true
        signInButton.backgroundColor = .black
        signInButton.setTitleColor(.white, for: .normal)
        signInButton.addTarget(self, action: #selector(signInButtonPressed), for: .touchUpInside)
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
    @IBAction func signInButtonPressed(_ sender: UIButton){ // 👉 Save login state
        UserDefaults.standard.set(true, forKey: "isLoggedIn")

        // 👉 Open TabScreens
        let storyboard = UIStoryboard(name: "TabScreens", bundle: nil)
        let tabBar = storyboard.instantiateInitialViewController()!
        tabBar.modalPresentationStyle = .fullScreen
        present(tabBar, animated: true)
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
        
      
        //proceedToHomeScreen()
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
    
    
    // MARK: - Navigation
    private func proceedToHomeScreen() {
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        if let navVC = storyboard.instantiateInitialViewController() {
            navVC.modalPresentationStyle = .fullScreen
            navVC.modalTransitionStyle = .crossDissolve
            present(navVC, animated: true)
        }
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
