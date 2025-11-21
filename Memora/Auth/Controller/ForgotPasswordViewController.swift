//
//  ForgotPasswordViewController.swift
//  Memora
//
//  Created by user@33 on 07/11/25.
//

import UIKit

class ForgotPasswordViewController: UIViewController {

    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var verifyButton: UIButton!
    
    // Error label (you can add this to storyboard or create programmatically)
    private let errorLabel: UILabel = {
        let label = UILabel()
        label.textColor = .systemRed
        label.font = UIFont.systemFont(ofSize: 14)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupEmailField()
    }
    
    private func setupUI() {
        emailField.layer.cornerRadius = 20
        emailField.clipsToBounds = true
        verifyButton.layer.cornerRadius = 28
        verifyButton.clipsToBounds = true
        
        // Add error label to view
        view.addSubview(errorLabel)
        NSLayoutConstraint.activate([
            errorLabel.topAnchor.constraint(equalTo: emailField.bottomAnchor, constant: 8),
            errorLabel.leadingAnchor.constraint(equalTo: emailField.leadingAnchor, constant: 16),
            errorLabel.trailingAnchor.constraint(equalTo: emailField.trailingAnchor, constant: -16)
        ])
    }
    
    private func setupEmailField() {
        emailField.delegate = self
        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none
        emailField.autocorrectionType = .no
        emailField.placeholder = "Enter your email"
        
        // Add padding to text field
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 20, height: emailField.frame.height))
        emailField.leftView = paddingView
        emailField.leftViewMode = .always
        
        // Clear error when user starts typing
        emailField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    }
    
    @objc private func textFieldDidChange() {
        hideError()
    }
    
    @IBAction func verifyButtonTapped(_ sender: UIButton) {
        verifyEmail()
    }
    
    private func verifyEmail() {
        // Dismiss keyboard
        view.endEditing(true)
        
        // Get email text
        guard let email = emailField.text?.trimmingCharacters(in: .whitespaces), !email.isEmpty else {
            showError("Please enter your email address")
            return
        }
        
        // Validate email format
        guard isValidEmail(email) else {
            showError("Please enter a valid email address")
            return
        }
        
        // Show success alert
        showSuccessAlert(email: email)
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func sendPasswordResetEmail(email: String) {
        // TODO: Implement your API call here
        
        // For now, just show success
        showLoading(false)
        showSuccessAlert(email: email)
    }
    
    private func showLoading(_ show: Bool) {
        verifyButton.isEnabled = !show
        emailField.isEnabled = !show
        
        if show {
            verifyButton.setTitle("Sending...", for: .normal)
            verifyButton.alpha = 0.6
        } else {
            verifyButton.setTitle("Verify", for: .normal)
            verifyButton.alpha = 1.0
        }
    }
    
    private func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
        
        // Shake animation
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.6
        animation.values = [-10, 10, -8, 8, -5, 5, 0]
        emailField.layer.add(animation, forKey: "shake")
    }
    
    private func hideError() {
        errorLabel.isHidden = true
    }
    
    private func showSuccessAlert(email: String) {
        let alert = UIAlertController(
            title: "Email Sent",
            message: "A password reset link has been sent to \(email). Please check your inbox and spam folder.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            // Navigate back to login screen
            self?.navigationController?.popViewController(animated: true)
        })
        
        present(alert, animated: true)
    }
}

// MARK: - UITextFieldDelegate
extension ForgotPasswordViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailField {
            verifyEmail()
        }
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Prevent spaces in email
        if string == " " {
            return false
        }
        return true
    }
}
