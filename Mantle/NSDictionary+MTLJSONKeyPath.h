//
//  NSDictionary+MTLJSONKeyPath.h
//  Mantle
//
//  Created by Robert Böhnke on 19/03/14.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDictionary (MTLJSONKeyPath)

// Looks up the value of a key path in the receiver.
//
// JSONKeyPath - The key path that should be resolved. Every element along this
//               key path needs to be an instance of NSDictionary for the
//               resolving to be successful.
// obj         - On return, this will be set to the value for the key path,
//               which may be nil.
// success     - If not NULL, this will be set to a boolean indicating whether
//               the key path was resolved successfully.
// error       - If not NULL, this may be set to an error that occurs during
//               resolving the value.
//
// Returns a boolean indicating whether the key path was resolved successfully.
// Clients should inspect it to decide if to proceed with the returned object.
- (BOOL)mtl_getObjectValue:(out id *)obj forJSONKeyPath:(NSString *)JSONKeyPath error:(out NSError **)error;

@end
