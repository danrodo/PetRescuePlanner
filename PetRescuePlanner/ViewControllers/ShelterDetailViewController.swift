//
//  ShelterDetailViewController.swift
//  PetRescuePlanner
//
//  Created by Brian Licea on 11/7/17.
//  Copyright © 2017 Daniel Rodosky. All rights reserved.
//

import UIKit
import MapKit

class ShelterDetailViewController: UIViewController {
    
    var shelter: Shelter? {
        didSet {
            guard let shelter = shelter else { return }
            
            self.updateShelterDetailView(shelter: shelter)
            
            
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ShelterController.shelterShared.fetchShelter(by: "UT183") { (success) in
            if !success {
                NSLog("Error")
                return
                
            }
            self.shelter = ShelterController.shelterShared.shelter
            
        }
    }
    
    
    func updateShelterDetailView(shelter: Shelter){
        
        DispatchQueue.main.async {
            self.shelterNameLabel.text = shelter.name
            self.addressLabel.text = shelter.address
            self.cityLabel.text = shelter.city
            self.stateLabel.text = shelter.state
            self.numberLabel.text = shelter.phone
            self.emailLabel.text = shelter.email
            
            var numerToPhone = self.numberLabel.text
            numerToPhone = shelter.phone
            
            guard let numberUrl = URL(string: "tel://\(String(describing: numerToPhone))") else { return }
            UIApplication.shared.open(numberUrl, options: [:], completionHandler: nil)
            
            
            
            let shelterRequeset = MKLocalSearchRequest()
            shelterRequeset.naturalLanguageQuery = shelter.id
            
            let activeSearch = MKLocalSearch(request: shelterRequeset)
            
            activeSearch.start { (response, error) in
                if response == nil
                {
                    print("Error")
                } else {
                    // Mark: - Remove annotations
                    let annotaions = self.shelterMapView.annotations
                    self.shelterMapView.removeAnnotations(annotaions)
                    
                    // Mark: - Get data
                    let latitude = response?.boundingRegion.center.latitude
                    let longitude = response?.boundingRegion.center.longitude
                    
                    // Mark: - create annotation
                    let annotation = MKPointAnnotation()
                    annotation.title = shelter.name
                    annotation.coordinate = CLLocationCoordinate2DMake(latitude!, longitude!)
                    self.shelterMapView.addAnnotation(annotation)
                    
                    // Mark: - zooming in on the annotaion
                    let coordinate: CLLocationCoordinate2D = CLLocationCoordinate2DMake(latitude!, longitude!)
                    let span = MKCoordinateSpanMake(0.1, 0.1)
                    let region = MKCoordinateRegionMake(coordinate, span)
                    self.shelterMapView.setRegion(region, animated: true)
                    
                }
            }
        }
    }
    @IBOutlet weak var shelterNameLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var cityLabel: UILabel!
    @IBOutlet weak var stateLabel: UILabel!
    @IBOutlet weak var shelterMapView: MKMapView!
    @IBOutlet weak var numberLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    
    @IBAction func directionsButtonTapped(_ sender: Any) {
        
        guard let shelter = shelter else { return }
        
        let mapsDirectionURL = URL(string: "http://maps.apple.com/?daddr=\(shelter.latitude),\(shelter.longitude)")!
        UIApplication.shared.open(mapsDirectionURL, completionHandler: nil)
    }
}



