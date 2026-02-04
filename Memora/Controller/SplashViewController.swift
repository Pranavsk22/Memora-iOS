//
//  SplashViewController.swift
//  Memory
//
//  Created by user@3 on 05/11/25.
//

import UIKit

class SplashViewController: UIViewController {

    @IBOutlet weak var appNameLabel: UILabel!
    @IBOutlet weak var logoImageView: UIImageView!
    override func viewDidLoad() {
        super.viewDidLoad()
        appNameLabel.alpha = 0
    }
    
    override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            animateSplash()
        }
    private func animateSplash() {
            // Reset transform
            logoImageView.transform = .identity

            UIView.animate(withDuration: 2.0, // slower (2 seconds)
                           delay: 0.5,
                           options: [.curveEaseInOut],
                           animations: {
                // Move logo upward smoothly (less distance for a gentle motion)
                self.logoImageView.transform = CGAffineTransform(translationX: 0, y: -80)
            }, completion: { _ in
                // Fade in the app name gently
                UIView.animate(withDuration: 1.5,
                               delay: 0.2,
                               options: [.curveEaseInOut],
                               animations: {
                    self.appNameLabel.alpha = 1.0
                }, completion: { _ in
                    // Wait before navigating away
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.goToOnboarding()
                    }
                })
            })
        }

    private func goToOnboarding() {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)

            // No need for if-let since it returns non-optional
            let onboardingVC = storyboard.instantiateViewController(withIdentifier: "OnboardingViewController")

            onboardingVC.modalTransitionStyle = .crossDissolve
            onboardingVC.modalPresentationStyle = .fullScreen
            present(onboardingVC, animated: true)
        }
}
