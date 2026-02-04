import UIKit

final class MemoryContainerViewController: UIViewController {
    private var memoryFromXib: MemoryViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        embedMemoryXIB()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        title = "Memories"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always

        let profileItem = UIBarButtonItem(
            image: UIImage(systemName: "person.circle"),
            style: .plain,
            target: self,
            action: #selector(didTapProfile)
        )
        profileItem.tintColor = .label
        navigationItem.rightBarButtonItem = profileItem
    }

    private func embedMemoryXIB() {
        let memory = MemoryViewController(nibName: "MemoryViewController", bundle: nil)
        addChild(memory)
        view.addSubview(memory.view)
        memory.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            memory.view.topAnchor.constraint(equalTo: view.topAnchor),
            memory.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            memory.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            memory.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        memory.didMove(toParent: self)
        self.memoryFromXib = memory
    }

    @objc private func didTapProfile() {
        let vc = AccountModalViewController()
        vc.title = "Account"

        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
        nav.navigationBar.prefersLargeTitles = true

        present(nav, animated: true)
    }
}
