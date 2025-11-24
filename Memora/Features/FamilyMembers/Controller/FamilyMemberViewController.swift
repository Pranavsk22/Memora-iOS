//
//  FamilyMemberViewController.swift
//  Memora
//
//  Created by user@3 on 10/11/25.
//

import UIKit

class FamilyMemberViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var membersCollectionView: UICollectionView!
    @IBOutlet weak var postsCollectionView: UICollectionView!
    @IBOutlet weak var profileButton: UIButton!

    // MARK: - Dummy Data
    let members: [(name: String, imageName: String)] = [
        ("John", "Window"),
        ("Peter", "Window-1"),
        ("Raqual", "Window-2")
    ]

    let posts: [(prompt: String, author: String, imageName: String)] = [
        ("Birthday Celebration", "Mom", "Window-1"),
        ("Trip to Goa", "Dad", "Window-2"),
        ("Graduation Day", "Peter", "Window")
    ]

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Background FIX
        view.backgroundColor = UIColor(red: 242/255, green: 242/255, blue: 247/255, alpha: 1)

        setupMembersCollection()
        setupPostsCollection()
    }

    // MARK: - Members Collection Setup
    private func setupMembersCollection() {
        let nib = UINib(nibName: "FamilyMemberCollectionViewCell", bundle: nil)
        membersCollectionView.register(nib, forCellWithReuseIdentifier: "FamilyMemberCell")

        membersCollectionView.delegate = self
        membersCollectionView.dataSource = self

        membersCollectionView.backgroundColor = .clear  // FIX WHITE BACKGROUND

        if let layout = membersCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .horizontal
            layout.minimumLineSpacing = 12
            layout.itemSize = CGSize(width: 140, height: 190)
            layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        }
    }

    // MARK: - Posts Collection Setup (Home-style Explore More)
    private func setupPostsCollection() {
        let nib = UINib(nibName: "FamilyMemoriesCollectionViewCell", bundle: nil)
        postsCollectionView.register(nib, forCellWithReuseIdentifier: "FamilyMemoriesCell")

        postsCollectionView.delegate = self
        postsCollectionView.dataSource = self
        postsCollectionView.backgroundColor = .clear  // FIX WHITE BACKGROUND
        postsCollectionView.showsVerticalScrollIndicator = false

        if let layout = postsCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .vertical
            layout.minimumLineSpacing = 35
            layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16)
            layout.itemSize = CGSize(
                width: view.bounds.width - 32,
                height: 394
            )
        }
    }

    // MARK: - Navigation actions
    @IBAction func FamilyMemberPressed(_ sender: UIButton) {
        let FamilyList = FamilyMemberListViewController(nibName: "FamilyMemberListViewController", bundle: nil)
        navigationController?.pushViewController(FamilyList, animated: true)
    }

    @IBAction func profileButtonPressed(_ sender: UIButton) {
        let vc = AccountModalViewController()
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        
        if let sheet = nav.sheetPresentationController {
            // Only large detent (full height)
            sheet.detents = [.large()]
            sheet.selectedDetentIdentifier = .large
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            sheet.largestUndimmedDetentIdentifier = .large
        }

        present(nav, animated: true)

    }
}

extension FamilyMemberViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func numberOfSections(in collectionView: UICollectionView) -> Int { return 1 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return collectionView == membersCollectionView ? members.count : posts.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        if collectionView == membersCollectionView {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "FamilyMemberCell",
                for: indexPath
            ) as! FamilyMemberCollectionViewCell

            let member = members[indexPath.item]
            cell.configure(name: member.name, image: UIImage(named: member.imageName))
            return cell
        }

        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "FamilyMemoriesCell",
            for: indexPath
        ) as! FamilyMemoriesCollectionViewCell

        let post = posts[indexPath.item]
        cell.configure(
            prompt: post.prompt,
            author: post.author,
            image: UIImage(named: post.imageName)
        )
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == membersCollectionView {
            print("Tapped Member:", members[indexPath.item].name)
        } else {
            print("Tapped Post:", posts[indexPath.item].prompt)
        }
    }
}
