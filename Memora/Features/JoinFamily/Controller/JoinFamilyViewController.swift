//
//  FamilyMembersViewController.swift
//  Memora
//
//  Created by user@3 on 07/11/25.
//
import UIKit

class JoinFamilyViewController: UIViewController {
    
    @IBOutlet weak var instructionLabel: UILabel!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var codeField1: UITextField!
    @IBOutlet weak var codeField2: UITextField!
    @IBOutlet weak var codeField3: UITextField!
    @IBOutlet weak var codeField4: UITextField!
    @IBOutlet weak var joinButton: UIButton!
    @IBOutlet weak var createFamilyButton: UIButton!
    
    private var fields: [UITextField] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        setupUI()
        setupFields()
    }
    
    private func setupNavigation() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.backward"),
            style: .plain,
            target: self,
            action: #selector(backTapped)
        )
    }
    
    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    private func setupUI() {
        instructionLabel.text = "Enter the code to join the family"
        instructionLabel.textAlignment = .center
        
        joinButton.layer.cornerRadius = 28
        joinButton.backgroundColor = .black
        joinButton.setTitleColor(.white, for: .normal)
        joinButton.setTitle("Join Family", for: .normal)
        
        createFamilyButton.setTitle("Create a new Family", for: .normal)
        createFamilyButton.setTitleColor(.black, for: .normal)
    }
    
    private func setupFields() {
        fields = [codeField1, codeField2, codeField3, codeField4]
        
        for (index, field) in fields.enumerated() {
            field.tag = index
            field.delegate = self
            field.keyboardType = .numberPad
            field.textAlignment = .center
            field.backgroundColor = UIColor(white: 0.9, alpha: 1)
            field.layer.cornerRadius = 10
            field.addTarget(self, action: #selector(textChanged(_:)), for: .editingChanged)
        }
        
        codeField1.becomeFirstResponder()
    }
    
    @objc private func textChanged(_ textField: UITextField) {
        if let text = textField.text, text.count > 1 {
            textField.text = String(text.prefix(1))
        }
        
        if let text = textField.text, !text.isEmpty {
            if textField.tag < fields.count - 1 {
                fields[textField.tag + 1].becomeFirstResponder()
            } else {
                textField.resignFirstResponder()
            }
        }
    }
    
    @IBAction func joinFamilyPressed(_ sender: UIButton) {
        let code = fields.compactMap { $0.text }.joined()
        
        guard code.count == 4 else {
            showAlert("Enter 4-digit code")
            return
        }
        let vc = FamilyMemberViewController(nibName: "FamilyMemberViewController", bundle: nil)
        navigationController?.pushViewController(vc, animated: true)
        print("Joining family with code: \(code)")
        // handle success — move to next screen
        //let vc = HomeViewController(nibName: "JoinFamilyViewController", bundle: nil)
        //navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func createFamilyPressed(_ sender: UIButton) {
        print("Create family tapped")
        // push create family flow
        let vc = CreateFamilyViewController(nibName: "CreateFamilyViewController", bundle: nil)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: "", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension JoinFamilyViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string.isEmpty { return true }
        return (textField.text?.count ?? 0) < 1 && string.allSatisfy({ $0.isNumber })
    }
}
