//
//  MainOnboardingViewController.swift
//  Memora
//
//  Created by user@3 on 06/11/25.
//
import UIKit

class MainOnboardingViewController: UIViewController {

    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet weak var skipButton: UIButton!

    
    weak var pageViewController: Onboardingv3PageViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

     
        for child in children {
            if let pvc = child as? Onboardingv3PageViewController {
                pageViewController = pvc
                break
            }
        }

   
        pageControl.numberOfPages = pageViewController?.pages.count ?? 0
        pageControl.currentPage = pageViewController?.currentIndex ?? 0
        updateContinueButtonTitle()
    }

   
    @IBAction func continueTapped(_ sender: UIButton) {
        guard let pvc = pageViewController else { return }

        let nextIndex = pvc.currentIndex + 1
        if nextIndex < (pvc.pages.count) {
            pvc.setViewControllers([pvc.pages[nextIndex]], direction: .forward, animated: true) { finished in
                if finished {
                    pvc.currentIndex = nextIndex
                    self.pageControl.currentPage = nextIndex
                    self.animateContinueTitleChange()
                }
            }
        } else {
           
            finishedOnboarding()
        }
    }

    @IBAction func skipTapped(_ sender: UIButton) {
        guard let pvc = pageViewController else { return }
        let last = pvc.pages.count - 1
        pvc.setViewControllers([pvc.pages[last]], direction: .forward, animated: true) { finished in
            if finished {
                pvc.currentIndex = last
                self.pageControl.currentPage = last
                self.animateContinueTitleChange()
            }
        }
    }

    @IBAction func pageControlTapped(_ sender: UIPageControl) {
        guard let pvc = pageViewController else { return }
        let target = sender.currentPage
        let direction: UIPageViewController.NavigationDirection = (target > pvc.currentIndex) ? .forward : .reverse
        pvc.setViewControllers([pvc.pages[target]], direction: direction, animated: true) { _ in
            pvc.currentIndex = target
            self.animateContinueTitleChange()
        }
    }

    
    func finishedOnboarding() {
        let signup = AuthViewController(nibName: "AuthViewController", bundle: nil)
        navigationController?.pushViewController(signup, animated: true)
       
    }

   
    func pageDidChange(to index: Int) {
        pageControl.currentPage = index
        animateContinueTitleChange()
        
        if let pvc = pageViewController {
                skipButton.isHidden = (index == pvc.pages.count - 1)
            }
    }

    
    func updateContinueButtonTitle() {
        guard let pvc = pageViewController else { return }
        let boldFont = UIFont.boldSystemFont(ofSize: 18)
        
        if pvc.currentIndex == (pvc.pages.count - 1) {
            let boldTitle = NSAttributedString(string: "Let's Get Started", attributes: [
                .font: boldFont
            ])
            continueButton.setAttributedTitle(boldTitle, for: .normal)
        } else {
            let boldTitle = NSAttributedString(string: "Continue", attributes: [
                .font: boldFont
            ])
            continueButton.setAttributedTitle(boldTitle, for: .normal)
        }
    }

    func animateContinueTitleChange() {
        UIView.transition(with: continueButton, duration: 0.25, options: .transitionCrossDissolve, animations: {
            self.updateContinueButtonTitle()
        }, completion: nil)
    }
   
}
