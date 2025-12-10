//
//  NSManagedObject+.swift
//  Affirmate
//
//  Created by Bri on 10/24/22.
//

import CoreData

extension NSManagedObjectContext {
    
    func entity<T: NSManagedObject>(_ type: T.Type, for id: UUID) throws -> T? {
        guard let entityName = T.entity().name else {
            throw ChatError.nonexistentEntityName
        }
        let fetchRequest = NSFetchRequest<T>(entityName: entityName)
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.includesSubentities = true
        fetchRequest.fetchLimit = 1
        return try fetch(fetchRequest).first
    }
    
    func exists<T: NSManagedObject>(_ object: T.Type, id: UUID) throws -> Bool {
        guard let entityName = T.entity().name else {
            throw ChatError.nonexistentEntityName
        }
        let fetchRequest = NSFetchRequest<T>(entityName: entityName)
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.includesSubentities = false
        let exists = try count(for: fetchRequest) > 0
        return exists
    }
    
    func doesNotExist<T: NSManagedObject>(_ object: T.Type, id: UUID) throws -> Bool {
        return try !exists(T.self, id: id)
    }
}
