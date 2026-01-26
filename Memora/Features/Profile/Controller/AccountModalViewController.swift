import UIKit

class AccountModalViewController: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var nameCardView: UIView!
    @IBOutlet weak var notificationView: UIView!
    @IBOutlet weak var inviteView: UIView!
    @IBOutlet weak var helpView: UIView!
    @IBOutlet weak var logoutView: UIView!
    @IBOutlet weak var personalPrivacyContainerView: UIView!
    @IBOutlet weak var userNameLabel: UILabel!
    
    @IBOutlet weak var personalInfoButton: UIButton!
    @IBOutlet weak var privacyButton: UIButton!
    
    // MARK: - Properties
    private var activityIndicator: UIActivityIndicatorView?
    private var userProfile: UserProfile?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupNavBar()
        setupUI()
        setupActions()
        
        // Listen for auth state changes
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(handleLogout),
                                             name: NSNotification.Name("UserDidLogout"),
                                             object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateUserInfo()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup Methods
    private func setupNavBar() {
        title = "Account"
        navigationController?.navigationBar.prefersLargeTitles = false
        
        let closeButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closePressed)
        )
        navigationItem.rightBarButtonItem = closeButton
    }

    private func setupUI() {
        let elements = [
            nameCardView,
            notificationView,
            inviteView,
            helpView,
            logoutView,
            personalPrivacyContainerView
        ]

        elements.forEach { v in
            v?.layer.cornerRadius = 22
            v?.backgroundColor = .white
            v?.layer.masksToBounds = true
        }

        view.backgroundColor = UIColor.systemGray6
        
        // Style logout view differently
        logoutView.backgroundColor = UIColor.white
        logoutView.layer.borderColor = UIColor.red.cgColor
        logoutView.layer.borderWidth = 1.0
        
        // Create logout label inside logoutView
        if let logoutLabel = logoutView.subviews.first(where: { $0 is UILabel }) as? UILabel {
            logoutLabel.textColor = .red
            logoutLabel.text = "Log Out"
        }
    }
    
    private func updateUserInfo() {
        Task {
            do {
                userProfile = try await SupabaseManager.shared.getUserProfile()
                DispatchQueue.main.async {
                    self.userNameLabel?.text = self.userProfile?.name ?? "User"
                }
            } catch {
                print("Error loading user profile: \(error)")
                DispatchQueue.main.async {
                    self.userNameLabel?.text = "User"
                }
            }
        }
    }

    private func setupActions() {
        personalInfoButton.addTarget(self, action: #selector(openPersonalInfo), for: .touchUpInside)
        privacyButton.addTarget(self, action: #selector(openPrivacy), for: .touchUpInside)
        
        notificationView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openNotifications)))
        inviteView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openInvite)))
        helpView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openHelp)))
        
        // Add tap gesture to logout view
        let logoutTap = UITapGestureRecognizer(target: self, action: #selector(handleLogoutConfirmation))
        logoutView.addGestureRecognizer(logoutTap)
        logoutView.isUserInteractionEnabled = true
    }
    
    // MARK: - Logout Methods
    @objc private func handleLogoutConfirmation() {
        showLogoutConfirmationAlert()
    }
    
    private func showLogoutConfirmationAlert() {
        let alert = UIAlertController(
            title: "Log Out",
            message: "Are you sure you want to log out of Memora?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Log Out", style: .destructive, handler: { [weak self] _ in
            self?.performLogout()
        }))
        
        present(alert, animated: true, completion: nil)
    }
    
    private func performLogout() {
        showLoadingIndicator()
        
        Task {
            do {
                try await SupabaseManager.shared.signOut()
                
                DispatchQueue.main.async {
                    self.hideLoadingIndicator()
                    self.showLogoutSuccessAlert()
                    self.navigateToLoginScreen()
                }
            } catch {
                DispatchQueue.main.async {
                    self.hideLoadingIndicator()
                    self.showAlert(title: "Logout Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func handleLogout() {
        navigateToLoginScreen()
    }
    
    private func navigateToLoginScreen() {
        self.dismiss(animated: true) {
            let loginVC = LoginViewController(nibName: "LoginViewController", bundle: nil)
            let navController = UINavigationController(rootViewController: loginVC)
            navController.modalPresentationStyle = .fullScreen
            
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                return
            }
            
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: {
                window.rootViewController = navController
            }, completion: nil)
        }
    }
    
    // MARK: - Loading Indicator
    private func showLoadingIndicator() {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .systemRed
        indicator.center = view.center
        indicator.startAnimating()
        view.addSubview(indicator)
        activityIndicator = indicator
        
        // Disable user interaction during logout
        view.isUserInteractionEnabled = false
    }
    
    private func hideLoadingIndicator() {
        activityIndicator?.stopAnimating()
        activityIndicator?.removeFromSuperview()
        activityIndicator = nil
        view.isUserInteractionEnabled = true
    }
    
    private func showLogoutSuccessAlert() {
        let alert = UIAlertController(
            title: "Logged Out",
            message: "You have been successfully logged out.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            if let presentedVC = rootVC.presentedViewController {
                presentedVC.present(alert, animated: true, completion: nil)
            } else {
                rootVC.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Other Actions
    @objc func openNotifications() {
        let vc = NotificationsViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc func openPersonalInfo() {
        let vc = PersonalInformationViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc func openPrivacy() {
        let vc = PrivacyandSecurityViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc func openInvite() {
        showComingSoonAlert(feature: "Invite Friends")
    }
    
    @objc func openHelp() {
        showComingSoonAlert(feature: "Help & Support")
    }
    
    @objc func closePressed() {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Helper Methods
    private func showComingSoonAlert(feature: String) {
        let alert = UIAlertController(
            title: "Coming Soon",
            message: "\(feature) feature will be available soon!",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}
