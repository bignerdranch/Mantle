//
//  MTLManagedObjectAdapterTestCase.m
//  Mantle
//
//  Created by Justin Spahr-Summers on 2013-05-17.
//  Copyright (c) 2013 GitHub. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MTLManagedObjectAdapter.h"
#import "MTLCoreDataTestModels.h"
#import "MTLCoreDataObjects.h"

@interface MTLManagedObjectAdapterTestCase : XCTestCase {
	NSPersistentStoreCoordinator *persistentStoreCoordinator;
}

@end

@implementation MTLManagedObjectAdapterTestCase

- (void)setUp
{
	[super setUp];

	NSManagedObjectModel *model = [NSManagedObjectModel mergedModelFromBundles:@[ [NSBundle bundleForClass:self.class] ]];

	XCTAssertNotNil(model);

	persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
	XCTAssertNotNil(persistentStoreCoordinator);
	XCTAssertNotNil([persistentStoreCoordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:NULL]);
}

@end

#pragma mark - With a confined context

@interface MTLConfinedContextManagedObjectAdapterTestCase : MTLManagedObjectAdapterTestCase {
	NSManagedObjectContext *context;

	NSEntityDescription *parentEntity;
	NSEntityDescription *childEntity;
}

@end

@implementation MTLConfinedContextManagedObjectAdapterTestCase

- (void)setUp
{
	[super setUp];

	context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
	XCTAssertNotNil(context);

	context.undoManager = nil;
	context.persistentStoreCoordinator = persistentStoreCoordinator;

	parentEntity = [NSEntityDescription entityForName:@"Parent" inManagedObjectContext:context];
	XCTAssertNotNil(parentEntity);

	childEntity = [NSEntityDescription entityForName:@"Child" inManagedObjectContext:context];
	XCTAssertNotNil(childEntity);
}

@end

@interface MTLConfinedContextModelFromManagedObjectAdapterTestCase : MTLConfinedContextManagedObjectAdapterTestCase {
	MTLParent *parent;

	NSDate *date;
	NSString *numberString;
	NSString *requiredString;
}

@end

@implementation MTLConfinedContextModelFromManagedObjectAdapterTestCase

- (void)setUp
{
	[super setUp];

	date = [NSDate date];
	numberString = @"123";
	requiredString = @"foobar";

	parent = [MTLParent insertInManagedObjectContext:context];
	XCTAssertNotNil(parent);

	for (NSUInteger i = 0; i < 3; i++) {
		MTLChild *child = [MTLChild insertInManagedObjectContext:context];
		XCTAssertNotNil(child);

		child.childID = @(i);
		[parent addOrderedChildrenObject:child];
	}

	for (NSUInteger i = 3; i < 6; i++) {
		MTLChild *child = [MTLChild insertInManagedObjectContext:context];
		XCTAssertNotNil(child);

		child.childID = @(i);
		[parent addUnorderedChildrenObject:child];
	}

	parent.string = requiredString;

	__block NSError *error = nil;
	XCTAssertTrue([context save:&error]);
	XCTAssertNil(error);

	// Make sure that pending changes are picked up too.
	[parent setValue:@(numberString.integerValue) forKey:@"number"];
	[parent setValue:date forKey:@"date"];
}

- (void)testInitializeWithChildren
{
	NSString *desc = @"+modelOfClass:fromManagedObject:error: should initialize a MTLParentTestModel with children";

	NSError *error = nil;
	MTLParentTestModel *parentModel = [MTLManagedObjectAdapter modelOfClass:MTLParentTestModel.class fromManagedObject:parent error:&error];
	XCTAssertTrue([parentModel isKindOfClass:MTLParentTestModel.class], @"%@", desc);
	XCTAssertNil(error, @"%@", desc);

	XCTAssertEqualObjects(parentModel.date, date, @"%@", desc);
	XCTAssertEqualObjects(parentModel.numberString, numberString, @"%@", desc);
	XCTAssertEqualObjects(parentModel.requiredString, requiredString, @"%@", desc);

	XCTAssertEqual(parentModel.orderedChildren.count, (NSUInteger)3, @"%@", desc);
	XCTAssertEqual(parentModel.unorderedChildren.count, (NSUInteger)3, @"%@", desc);

	for (NSUInteger i = 0; i < 3; i++) {
		MTLChildTestModel *child = parentModel.orderedChildren[i];
		XCTAssertTrue([child isKindOfClass:MTLChildTestModel.class], @"%@", desc);

		XCTAssertEqual(child.childID, i, @"%@", desc);
		XCTAssertNil(child.parent1, @"%@", desc);
		XCTAssertEqual(child.parent2, parentModel, @"%@", desc);
	}

	for (MTLChildTestModel *child in parentModel.unorderedChildren) {
		XCTAssertTrue([child isKindOfClass:MTLChildTestModel.class], @"%@", desc);

		XCTAssertTrue(child.childID >= 3, @"%@", desc);
		XCTAssertTrue(child.childID < 6, @"%@", desc);

		XCTAssertEqual(child.parent1, parentModel, @"%@", desc);
		XCTAssertNil(child.parent2, @"%@", desc);
	}
}

@end

@interface MTLConfinedContextManagedObjectFromModelAdapterTestCase : MTLConfinedContextManagedObjectAdapterTestCase {
	MTLParentTestModel *parentModel;
}

@end

@implementation MTLConfinedContextManagedObjectFromModelAdapterTestCase

- (void)setUp
{
	[super setUp];

	parentModel = [MTLParentTestModel modelWithDictionary:@{
		@"date": [NSDate date],
		@"numberString": @"1234",
		@"requiredString": @"foobar"
	} error:NULL];
	XCTAssertNotNil(parentModel);

	NSMutableArray *orderedChildren = [NSMutableArray array];
	NSMutableSet *unorderedChildren = [NSMutableSet set];

	for (NSUInteger i = 0; i < 3; i++) {
		MTLChildTestModel *child = [MTLChildTestModel modelWithDictionary:@{
			@"childID": @(i),
			@"parent2": parentModel
		} error:NULL];
		XCTAssertNotNil(child);

		[orderedChildren addObject:child];
	}

	for (NSUInteger i = 3; i < 6; i++) {
		MTLChildTestModel *child = [MTLChildTestModel modelWithDictionary:@{
			@"childID": @(i),
			@"parent1": parentModel
		} error:NULL];
		XCTAssertNotNil(child);

		[unorderedChildren addObject:child];
	}

	parentModel.orderedChildren = orderedChildren;
	parentModel.unorderedChildren = unorderedChildren;
}

- (void)testInsertManagedObjectWithChildren
{
	NSString *desc = @"should insert a managed object with children";

	NSError *error = nil;
	MTLParent *parent = [MTLManagedObjectAdapter managedObjectFromModel:parentModel insertingIntoContext:context error:&error];
	XCTAssertNotNil(parent, @"%@", desc);
	XCTAssertTrue([parent isKindOfClass:MTLParent.class], @"%@", desc);
	XCTAssertNil(error, @"%@", desc);

	XCTAssertEqualObjects(parent.entity, parent.entity, @"%@", desc);

	XCTAssertTrue([context.insertedObjects containsObject:parent], @"%@", desc);

	XCTAssertEqualObjects(parent.date, parentModel.date, @"%@", desc);
	XCTAssertEqualObjects(parent.number.stringValue, parentModel.numberString, @"%@", desc);
	XCTAssertEqualObjects(parent.string, parentModel.requiredString, @"%@", desc);

	XCTAssertEqual(parent.orderedChildren.count, (NSUInteger)3, @"%@", desc);
	XCTAssertEqual(parent.unorderedChildren.count, (NSUInteger)3, @"%@", desc);

	for (NSUInteger i = 0; i < 3; i++) {
		MTLChild *child = parent.orderedChildren[i];
		XCTAssertTrue([child isKindOfClass:MTLChild.class], @"%@", desc);

		XCTAssertEqualObjects(child.entity, childEntity, @"%@", desc);
		XCTAssertTrue([context.insertedObjects containsObject:child], @"%@", desc);

		XCTAssertEqualObjects(child.childID, @(i), @"%@", desc);
		XCTAssertNil(child.parent1, @"%@", desc);
		XCTAssertEqualObjects(child.parent2, parent, @"%@", desc);
	}

	for (MTLChild *child in parent.unorderedChildren) {
		XCTAssertTrue([child isKindOfClass:MTLChild.class], @"%@", desc);

		XCTAssertEqualObjects(child.entity, childEntity, @"%@", desc);
		XCTAssertTrue([context.insertedObjects containsObject:parent], @"%@", desc);

		XCTAssertTrue([child.childID unsignedIntegerValue] >= 3, @"%@", desc);
		XCTAssertTrue([child.childID unsignedIntegerValue] < 6, @"%@", desc);

		XCTAssertEqual(child.parent1, parent, @"%@", desc);
		XCTAssertNil(child.parent2, @"%@", desc);
	}

	XCTAssertTrue([context save:&error], @"%@", desc);
	XCTAssertNil(error, @"%@", desc);
}

- (void)testInsertModelObjectFail
{
	NSString *desc = @"should return an error if a model object could not be inserted";

	MTLFailureModel *failureModel = [MTLFailureModel modelWithDictionary:@{
		@"notSupported": @"foobar"
	} error:NULL];

	__block NSError *error = nil;
	NSManagedObject *failure = [MTLManagedObjectAdapter managedObjectFromModel:failureModel insertingIntoContext:context error:&error];

	XCTAssertNil(failure, @"%@", desc);
	XCTAssertNotNil(error, @"%@", desc);
}

- (void)testUniquenessConstraint
{
	NSString *desc = @"should respect the uniqueness constraint";

	NSError *errorOne;
	MTLParent *parentOne = [MTLManagedObjectAdapter managedObjectFromModel:parentModel insertingIntoContext:context error:&errorOne];
	XCTAssertNotNil(parentOne, @"%@", desc);
	XCTAssertNil(errorOne, @"%@", desc);

	NSError *errorTwo;
	MTLParent *parentTwo = [MTLManagedObjectAdapter managedObjectFromModel:parentModel insertingIntoContext:context error:&errorTwo];
	XCTAssertNotNil(parentTwo, @"%@", desc);
	XCTAssertNil(errorTwo, @"%@", desc);

	XCTAssertEqualObjects(parentOne.objectID, parentTwo.objectID, @"%@", desc);
}

- (void)testUpdateRelationships
{
	NSString *desc = @"should update relationships for an existing object";

	NSError *error;
	MTLParent *parentOne = [MTLManagedObjectAdapter managedObjectFromModel:parentModel insertingIntoContext:context error:&error];
	XCTAssertNotNil(parentOne, @"%@", desc);
	XCTAssertNil(error, @"%@", desc);
	XCTAssertEqual(parentOne.orderedChildren.count, (NSUInteger)3, @"%@", desc);
	XCTAssertEqual(parentOne.unorderedChildren.count, (NSUInteger)3, @"%@", desc);

	MTLChild *child1Parent1 = parentOne.orderedChildren[0];
	MTLChild *child2Parent1 = parentOne.orderedChildren[1];
	MTLChild *child3Parent1 = parentOne.orderedChildren[2];

	MTLParentTestModel *parentModelCopy = [parentModel copy];
	[[parentModelCopy mutableOrderedSetValueForKey:@"orderedChildren"] removeObjectAtIndex:1];

	MTLChildTestModel *childToDeleteModel = [parentModelCopy.unorderedChildren anyObject];
	[[parentModelCopy mutableSetValueForKey:@"unorderedChildren"] removeObject:childToDeleteModel];

	MTLParent *parentTwo = [MTLManagedObjectAdapter managedObjectFromModel:parentModelCopy insertingIntoContext:context error:&error];
	XCTAssertNotNil(parentTwo, @"%@", desc);
	XCTAssertNil(error, @"%@", desc);
	XCTAssertEqual(parentTwo.orderedChildren.count, (NSUInteger)2, @"%@", desc);
	XCTAssertEqual(parentTwo.unorderedChildren.count, (NSUInteger)2, @"%@", desc);

	for (MTLChild *child in parentTwo.orderedChildren) {
		XCTAssertNotEqualObjects(child.childID, child2Parent1.childID, @"%@", desc);
	}

	for (MTLChild *child in parentTwo.unorderedChildren) {
		XCTAssertNotEqualObjects(child.childID, @(childToDeleteModel.childID), @"%@", desc);
	}

	MTLChild *child1Parent2 = parentTwo.orderedChildren[0];
	MTLChild *child2Parent2 = parentTwo.orderedChildren[1];
	XCTAssertEqualObjects(child1Parent2, child1Parent1, @"%@", desc);
	XCTAssertEqualObjects(child2Parent2, child3Parent1, @"%@", desc);
}

@end

#pragma mark - With a main context

@interface MTLMainContextManagedObjectAdapterTestCase : MTLManagedObjectAdapterTestCase {
	NSManagedObjectContext *context;
}

@end

@implementation MTLMainContextManagedObjectAdapterTestCase

- (void)setUp
{
	[super setUp];

	context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
	XCTAssertNotNil(context);

	context.undoManager = nil;
	context.persistentStoreCoordinator = persistentStoreCoordinator;
}

- (void)testDeadlockOnMainThread
{
	NSString *desc = @"should not deadlock on the main thread";

	MTLParent *parent = [MTLParent insertInManagedObjectContext:context];
	XCTAssertNotNil(parent, @"%@", desc);

	parent.string = @"foobar";

	NSError *error = nil;
	MTLParentTestModel *parentModel = [MTLManagedObjectAdapter modelOfClass:MTLParentTestModel.class fromManagedObject:parent error:&error];
	XCTAssertTrue([parentModel isKindOfClass:MTLParentTestModel.class], @"%@", desc);
	XCTAssertNil(error, @"%@", desc);
}

@end

#pragma mark - With a failing child

@interface MTLFailingManagedObjectAdapterTestCase : MTLManagedObjectAdapterTestCase {
	NSManagedObjectContext *context;

	NSEntityDescription *parentEntity;
	NSEntityDescription *childEntity;
	MTLParentTestModel *parentModel;
}

@end

@implementation MTLFailingManagedObjectAdapterTestCase

- (void)setUp
{
	[super setUp];

	context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
	XCTAssertNotNil(context);

	context.undoManager = nil;
	context.persistentStoreCoordinator = persistentStoreCoordinator;

	parentEntity = [NSEntityDescription entityForName:@"Parent" inManagedObjectContext:context];
	XCTAssertNotNil(parentEntity);

	childEntity = [NSEntityDescription entityForName:@"BadChild" inManagedObjectContext:context];
	XCTAssertNotNil(childEntity);

	parentModel = [MTLParentTestModel modelWithDictionary:@{
		@"date": [NSDate date],
		@"numberString": @"1234",
		@"requiredString": @"foobar"
	} error:NULL];
	XCTAssertNotNil(parentModel);

	NSMutableArray *orderedChildren = [NSMutableArray array];

	for (NSUInteger i = 3; i < 6; i++) {
		MTLBadChildTestModel *child = [MTLBadChildTestModel modelWithDictionary:@{
			@"childID": @(i)
		} error:NULL];
		XCTAssertNotNil(child);

		[orderedChildren addObject:child];
	}

	parentModel.orderedChildren = orderedChildren;
}

- (void)testInsertManagedObjectWithChildren
{
	NSString *desc = @"should not insert a managed object with children when a child fails serialization";

	NSError *error = nil;
	MTLParent *parent = [MTLManagedObjectAdapter managedObjectFromModel:parentModel insertingIntoContext:context error:&error];
	XCTAssertNil(parent, @"%@", desc);
	XCTAssertNotNil(error, @"%@", desc);
	XCTAssertTrue([context save:&error], @"%@", desc);
	XCTAssertNotNil(error, @"%@", desc);
}

@end