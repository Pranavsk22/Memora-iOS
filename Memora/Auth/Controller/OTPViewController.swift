import UIKit

class OTPViewController: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var otpStackView: UIStackView!
    @IBOutlet weak var textField1: UITextField!
    @IBOutlet weak var textField2: UITextField!
    @IBOutlet weak var textField3: UITextField!
    @IBOutlet weak var textField4: UITextField!
    @IBOutlet weak var verifyButton: UIButton!
    @IBOutlet weak var resendButton: UIButton!
    
    // MARK: - Properties
    private var textFields: [UITextField] = []
    private var resendTimer: Timer?
    private var remainingTime: Int = 60
    private let resendTimeInterval: Int = 60
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTextFields()
        setupUI()
        startResendTimer()
    }
    
    // MARK: - Setup
    private func setupTextFields() {
        textFields = [textField1, textField2, textField3, textField4]
        
        for (index, textField) in textFields.enumerated() {
            textField.delegate = self
            textField.textAlignment = .center
            textField.keyboardType = .numberPad
            textField.tag = index
            textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
            
            textField.layer.borderWidth = 1.0
            textField.layer.borderColor = UIColor.lightGray.cgColor
            textField.layer.cornerRadius = 8.0
        }
        
        textField1.becomeFirstResponder()
    }
    
    private func setupUI() {
        updateVerifyButtonState()
        
        verifyButton.layer.cornerRadius = 28.0
        verifyButton.addTarget(self, action: #selector(verifyButtonTapped), for: .touchUpInside)
        
        resendButton.addTarget(self, action: #selector(resendOTPTapped), for: .touchUpInside)
        styleVerifyButtonTitle()
    }
    
    // MARK: - Timer Management
    private func startResendTimer() {
        remainingTime = resendTimeInterval
        resendButton.isEnabled = false
        updateResendButtonTitle()
        
        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
    }
    
    @objc private func updateTimer() {
        remainingTime -= 1
        updateResendButtonTitle()
        
        if remainingTime <= 0 {
            resendTimer?.invalidate()
            resendTimer = nil
            resendButton.isEnabled = true
            resendButton.setTitle("Resend OTP", for: .normal)
        }
    }
    
    private func updateResendButtonTitle() {
        if remainingTime > 0 {
            resendButton.setTitle("Resend OTP in \(remainingTime)s", for: .normal)
        }
    }
    
    // MARK: - Actions
    @objc private func textFieldDidChange(_ textField: UITextField) {
        if let text = textField.text, text.count > 1 {
            textField.text = String(text.prefix(1))
        }
        
        if let text = textField.text, !text.isEmpty {
            if !text.allSatisfy({ $0.isNumber }) {
                textField.text = ""
                return
            }
            
            if textField.tag < textFields.count - 1 {
                textFields[textField.tag + 1].becomeFirstResponder()
            } else {
                textField.resignFirstResponder()
            }
        }
        
        updateVerifyButtonState()
        updateTextFieldBorder(textField)
    }
    
    @objc private func verifyButtonTapped(_ sender: UIButton) {
        guard validateOTP() else {
            showAlert(title: "Error", message: "Please enter a valid 4-digit OTP")
            return
        }
        
        let otp = getOTP()
        print("Verifying OTP: \(otp)")
    }
    
    @objc private func resendOTPTapped(_ sender: UIButton) {
        clearOTPFields()
        startResendTimer()
        showAlert(title: "Success", message: "OTP has been resent to your email")
    }
    
    // MARK: - Validation
    private func validateOTP() -> Bool {
        for textField in textFields {
            guard let text = textField.text, !text.isEmpty, text.count == 1 else {
                return false
            }
        }
        return true
    }
    
    private func getOTP() -> String {
        return textFields.compactMap { $0.text }.joined()
    }
    
    private func updateVerifyButtonState() {
        verifyButton.isEnabled = validateOTP()
        if verifyButton.isEnabled {
            verifyButton.backgroundColor = .black
            verifyButton.setTitleColor(.white, for: .normal)
            verifyButton.alpha = 1.0
            
        } else {
            verifyButton.backgroundColor = .lightGray
            verifyButton.setTitleColor(.black, for: .normal)
            verifyButton.alpha = 0.5
        }
    }
    
    private func updateTextFieldBorder(_ textField: UITextField) {
        if let text = textField.text, !text.isEmpty {
            textField.layer.borderColor = CGColor(genericCMYKCyan: 0, magenta: 0, yellow: 0, black: 100, alpha: 0)
            textField.layer.borderWidth = 2.0
        } else {
            textField.layer.borderColor = UIColor.lightGray.cgColor
            textField.layer.borderWidth = 1.0
        }
    }
    
    private func clearOTPFields() {
        for textField in textFields {
            textField.text = ""
            updateTextFieldBorder(textField)
        }
        updateVerifyButtonState()
        textField1.becomeFirstResponder()
    }
    
    // MARK: - Helper Methods
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
    
    // MARK: - Cleanup
    deinit {
        resendTimer?.invalidate()
    }
}

// MARK: - UITextFieldDelegate
extension OTPViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string.isEmpty {
            return true
        }
        
        let allowedCharacters = CharacterSet.decimalDigits
        let characterSet = CharacterSet(charactersIn: string)
        
        if textField.text?.count ?? 0 >= 1 {
            return false
        }
        
        return allowedCharacters.isSuperset(of: characterSet)
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        updateTextFieldBorder(textField)
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if let text = textField.text, text.isEmpty {
            updateTextFieldBorder(textField)
        }
    }
}

// MARK: - Delete Key Handler
extension OTPViewController {
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let key = presses.first?.key else {
            super.pressesBegan(presses, with: event)
            return
        }
        
        if key.keyCode == .keyboardDeleteOrBackspace {
            handleDeleteKey()
        }
        
        super.pressesBegan(presses, with: event)
    }
    
    private func handleDeleteKey() {
        guard let currentTextField = textFields.first(where: { $0.isFirstResponder }) else {
            return
        }
        
        if let text = currentTextField.text, text.isEmpty {
            let currentIndex = currentTextField.tag
            if currentIndex > 0 {
                let previousTextField = textFields[currentIndex - 1]
                previousTextField.text = ""
                previousTextField.becomeFirstResponder()
                updateTextFieldBorder(previousTextField)
            }
        }
        
        updateVerifyButtonState()
    }
    
    private func styleVerifyButtonTitle() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        let disabledAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: UIColor.black
        ]
        
        verifyButton.setAttributedTitle(NSAttributedString(string: "Verify & Continue", attributes: attributes), for: .normal)
        verifyButton.setAttributedTitle(NSAttributedString(string: "Verify & Continue", attributes: disabledAttributes), for: .disabled)
    }
}
