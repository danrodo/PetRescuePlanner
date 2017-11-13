//
//  PetController+CloudKit.swift
//  PetRescuePlanner
//
//  Created by Daniel Jin on 11/7/17.
//  Copyright © 2017 Daniel Rodosky. All rights reserved.
//

import Foundation
import CloudKit

extension PetController {
    
    // MARK: - Properties
    var isSyncing: Bool {
        get {
            return false
        }
        set {}
    }
    
    // Fetch function to check if a user's swiped animal is already in their favorites list
    func fetchPet(petCKRecord: CKRecord, completion: @escaping (_ petRec: CKRecord?) -> Void) {
        
        guard let pet = Pet(cloudKitRecord: petCKRecord),
            let recordIDString = pet.recordIDString,
            let id = pet.id else {
            completion(nil)
            return
        }
//        let petRecordID = CKRecordID(recordName: recordIDString)
        
        let predicate = NSPredicate(format: "id == %@", id)
        
        cloudKitManager.fetchRecordsWithType(CloudKit.petRecordType, predicate: predicate, recordFetchedBlock: nil) { (records, error) in
            if let error = error {
                    NSLog("Error fetching record with the Pet's Record ID \(error.localizedDescription)" )
                    completion(nil)
                    return
            }
            guard let records = records else { completion(nil);return }
            
            completion(records.first)
            return
        }
    }
    
    // MARK: - Save
    func saveToCK(pet: Pet, completion: @escaping (_ success: Bool) -> Void) {
        
        guard var currentUser = UserController.shared.currentUser else { return }
        
        // Get CK record of the pet to save to CK
        guard let petCKRecord = CKRecord(pet: pet) else {
            NSLog("Error getting pet CK Record")
            completion(false)
            return
        }
        
        fetchPet(petCKRecord: petCKRecord) { (record) in
            
            guard let userRecord = CKRecord(user: currentUser) else { return }
            
            // Need to save to the user's list of CK References for favorite pets
            let petCKRef = CKReference(record: petCKRecord, action: .none)
            currentUser.savedPets.insert(petCKRef, at: 0)
            
            // There is already a pet CK record that you swiped right on
            if record != nil {
                
                // Modify/update CKRecord for user
                self.cloudKitManager.modifyRecords([userRecord], perRecordCompletion: nil) { (record, error) in
                    if let error = error {
                        NSLog("Error updating user record with saved pet \(error.localizedDescription)")
                        return completion(false)
                    }
                    completion(true)
                }
            } else {
                
                // Save to CloudKit
                self.cloudKitManager.save(petCKRecord) { (error) in
                    
                    // Handle error
                    if error != nil {
                        NSLog("Error saving pet to CloudKit")
                        completion(false)
                        return
                    }
                    // Modify/update CKRecord for user
                    self.cloudKitManager.modifyRecords([userRecord], perRecordCompletion: nil) { (record, error) in
                        if let error = error {
                            NSLog("Error updating user record with saved pet \(error.localizedDescription)")
                            return completion(false)
                        }
                    }
                    
                    // If no errors, complete with success as true
                    completion(true)
                }
            }
        }
    }
    
    // MARK: - Delete
    func deleteFromCK(pet: Pet, completion: @escaping (_ success: Bool) -> Void) {
        
        // Get CKRecordID of the pet
        guard let petCKRecordID = pet.cloudKitRecordID else {
            NSLog("Error deleting pet from CloudKit - no CK Record ID")
            completion(false)
            return
        }
        
        // Delete from CloudKit
        self.cloudKitManager.deleteRecordWithID(petCKRecordID) { (recordID, error) in
            
            // Handle error
            if error != nil {
                NSLog("Error deleting pet record from CloudKit")
                completion(false)
                return
            }
            completion(true)
        }
    }
    
    // MARK: - Helper Fetches
    private func recordsOf(type: String) -> [CloudKitSyncable] {
        switch type {
        case "Pet":
            return pets.flatMap{ $0 as CloudKitSyncable }
        case "Shelter":
            return ShelterController.shelterShared.shelters.flatMap { $0 as CloudKitSyncable }
        default:
            return []
        }
    }
    
    func syncedRecordsOf(type: String) -> [CloudKitSyncable] {
        return recordsOf(type: type).filter { $0.isSynced }
    }
    
    func unsyncedRecordsOf(type: String) -> [CloudKitSyncable] {
        return recordsOf(type: type).filter { !$0.isSynced }
    }
    
    // MARK: - Sync
    func performFullSync(completion: @escaping (() -> Void) = { }) {
        
        guard !isSyncing else {
            completion()
            return
        }
        
        isSyncing = true
        
        pushChangesToCloudKit { (success, error) in
            
            self.fetchNewPetRecordsOf(type: "Pet") {
                self.isSyncing = false
                completion()
            }
        }
    }
    
    func fetchNewPetRecordsOf(type: String, completion: @escaping (() -> Void) = { }) {
            
        var referencesToExclude = [CKReference]()
        var predicate: NSPredicate!
        referencesToExclude = self.syncedRecordsOf(type: type).flatMap { $0.cloudKitReference }
        predicate = NSPredicate(format: "NOT(recordID IN %@)", argumentArray: [referencesToExclude])
        
        if referencesToExclude.isEmpty {
            predicate = NSPredicate(value: true)
        }
        
        // TODO: Code sortdescriptors to order by most recently saved/favorited
        /*
        let sortDescriptors: [NSSortDescriptor]?
        let sortDescriptor = NSSortDescriptor(key: "savedDateTime", ascending: true)
        sortDescriptors = [sortDescriptor]
         */
        
        cloudKitManager.fetchRecordsWithType(CloudKit.petRecordType, predicate: predicate, sortDescriptors: nil) { (records, error) in
            
            defer { completion() }
            if let error = error {
                NSLog("Error fetching Pet CloudKit records: \(error)")
                return
            }
            guard let records = records else { return }
            
            records.forEach { Pet(cloudKitRecord: $0, context: CoreDataStack.context) }
            
            self.saveToPersistantStore()
            
        }
    }
    
    func pushChangesToCloudKit(completion: @escaping ((_ success: Bool, _ error: Error?) -> Void) = { _,_ in }) {
        
        let unsavedPets = unsyncedRecordsOf(type: "Pet") as? [Pet] ?? []
        var unsavedObjectsByRecord = [CKRecord: CloudKitSyncable]()
        for pet in unsavedPets {
            guard let record = CKRecord(pet: pet) else {
                NSLog("Error getting CK Record of the pet")
                return
            }
            unsavedObjectsByRecord[record] = pet
        }
        let unsavedRecords = Array(unsavedObjectsByRecord.keys)
        
        cloudKitManager.saveRecords(unsavedRecords, perRecordCompletion: { (record, error) in
            guard let record = record else { return }
            unsavedObjectsByRecord[record]?.cloudKitRecordID = record.recordID
            
        }) { (records, error) in
            
            let success = records != nil
            completion(success, error)
        }
    }
}
