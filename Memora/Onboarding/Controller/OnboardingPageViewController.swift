//
//  OnboardingPageViewController.swift
//  Memora
//
//  Created by user@3 on 06/11/25.
//
import UIKit

class OnboardingPageViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {

    lazy var pages: [UIViewController] = {
        return [
            storyboard!.instantiateViewController(withIdentifier: "Screen1v2ViewController"),
            storyboard!.instantiateViewController(withIdentifier: "Screen2v2ViewController"),
            storyboard!.instantiateViewController(withIdentifier: "Screen3v2ViewController"),
            storyboard!.instantiateViewController(withIdentifier: "Screen4v2ViewController"),
        ]
    }()
    
    var currentIndex = 0
    let pageControl = UIPageControl()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.dataSource = self
        self.delegate = self

    
        setViewControllers([pages[0]], direction: .forward, animated: true, completion: nil)

        setupPageControl()
    }

    func setupPageControl() {
        pageControl.numberOfPages = pages.count
        pageControl.currentPage = 0
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.pageIndicatorTintColor = UIColor.lightGray
        pageControl.currentPageIndicatorTintColor = UIColor.black
        view.addSubview(pageControl)

        NSLayoutConstraint.activate([
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50)
        ])
    }

    func updatePageControl() {
        pageControl.currentPage = currentIndex
    }

    func goToNextPage() {
        if currentIndex < pages.count - 1 {
            currentIndex += 1
            setViewControllers([pages[currentIndex]], direction: .forward, animated: true, completion: nil)
            updatePageControl()
        } else {
            print("Onboarding Finished")
        }
    }

    func skipToLastPage() {
        currentIndex = pages.count - 1
        setViewControllers([pages[currentIndex]], direction: .forward, animated: true, completion: nil)
        updatePageControl()
    }

    // MARK: - Swipe support
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let idx = pages.firstIndex(of: viewController), idx > 0 else { return nil }
        return pages[idx - 1]
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let idx = pages.firstIndex(of: viewController), idx < pages.count - 1 else { return nil }
        return pages[idx + 1]
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed,
           let visibleVC = viewControllers?.first,
           let idx = pages.firstIndex(of: visibleVC) {
            currentIndex = idx
            updatePageControl()
        }
    }
}
