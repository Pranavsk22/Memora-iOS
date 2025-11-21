//
//  ViewController.swift
//  Memora
//
//  Created by user@33 on 04/11/25.
//

import UIKit


class ViewController: UIViewController {

    @IBOutlet weak var clickMe: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
 

    @IBAction func tapped(_ sender: Any) {
        let signup = LoginViewController(nibName: "LoginViewController", bundle: nil)
        navigationController?.pushViewController(signup, animated: true)
    }
    
}

