//
//  CreateFamilyViewController.swift
//  Memora
//
//  Created by user@3 on 07/11/25.
//

import UIKit

class CreateFamilyViewController: UIViewController {

    @IBOutlet weak var familyName: UITextField!
    
    @IBOutlet weak var createFamilyButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        
        
    }

    @IBAction func createFamilyButtonTapped(_ sender: UIButton) {
        let vc = HomeViewController(nibName: "HomeViewController", bundle: nil)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
