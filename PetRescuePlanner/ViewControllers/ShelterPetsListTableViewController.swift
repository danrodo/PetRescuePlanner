//
//  ShelterPetsListTableViewController.swift
//  PetRescuePlanner
//
//  Created by Daniel Rodosky on 11/14/17.
//  Copyright © 2017 Daniel Rodosky. All rights reserved.
//

import UIKit

class ShelterPetsListTableViewController: UITableViewController {
    
    var savedPets: [Pet] = [] {
        didSet{
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 150
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return savedPets.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "shelterPetCell", for: indexPath) as? ShelterPetTableViewCell else {
            return ShelterPetTableViewCell()
        }
        let pet = savedPets[indexPath.row]
        
        cell.pet = pet
        
        return cell
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        // Segue to Detail view with pet and fetch shelter
        if segue.identifier == "shelterPetToDetail" {
            
            guard let indexPath = tableView.indexPathForSelectedRow else { return }
            let pet = savedPets[indexPath.row]
            
            guard let destinationVC = segue.destination as? PetDetailCollectionTableViewController else { return }
            
            destinationVC.pet = pet
            
        }

    }

}
