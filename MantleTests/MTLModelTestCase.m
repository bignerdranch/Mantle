//
//  MTLModelTestCase.m
//  Mantle
//
//  Created by Justin Spahr-Summers on 2012-09-11.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MTLTestModel.h"

@interface MTLModelTestCase : XCTestCase

@end

@interface MTLModelBasicDictionaryTestCase : XCTestCase {
	MTLEmptyTestModel *emptyModel;
	NSDictionary *values;
	MTLTestModel *model;
}

@end

@implementation MTLModelTestCase

- (void)testNoProperties
{
	XCTAssertEqualObjects(MTLEmptyTestModel.propertyKeys, [NSSet set], @"should not loop infinitely in +propertyKeys without any properties");
}

- (void)testDynamicReadonlyProperties
{
	NSSet *expectedKeys = [NSSet setWithObjects:@"name", @"count", @"nestedName", @"weakModel", nil];
	XCTAssertEqualObjects(MTLTestModel.propertyKeys, expectedKeys, @"should not include dynamic readonly properties in +propertyKeys");
}

- (void)testDefaultValues
{
	NSString *desc = @"should initialize with default values";

	MTLTestModel *model = [[MTLTestModel alloc] init];
	XCTAssertNotNil(model, @"%@", desc);

	XCTAssertNil(model.name, @"%@", desc);
	XCTAssertEqual(model.count, (NSUInteger)1, @"%@", desc);

	NSDictionary *expectedValues = @{
		@"name": NSNull.null,
		@"count": @(1),
		@"nestedName": NSNull.null,
		@"weakModel": NSNull.null,
	};

	XCTAssertEqualObjects(model.dictionaryValue, expectedValues, @"%@", desc);
	XCTAssertEqualObjects([model dictionaryWithValuesForKeys:expectedValues.allKeys], expectedValues, @"%@", desc);
}

- (void)testDefaultValuesNilDictionary
{
	NSError *error = nil;
	MTLTestModel *dictionaryModel = [[MTLTestModel alloc] initWithDictionary:nil error:&error];
	XCTAssertNotNil(dictionaryModel, @"should return object for a nil dictionary");
	XCTAssertNil(error, @"should not return error for a nil dictionary");

	MTLTestModel *defaultModel = [[MTLTestModel alloc] init];
	XCTAssertEqualObjects(dictionaryModel, defaultModel, @"should initialize to default values with a nil dictionary");
}

- (void)testValidationFailure
{
	NSError *error = nil;
	MTLTestModel *model = [[MTLTestModel alloc] initWithDictionary:@{ @"name": @"this is too long a name" } error:&error];
	XCTAssertNil(model, @"should not return model if dictionary validation fails");
	XCTAssertNotNil(error, @"should return error if dictionary validation fails");
	XCTAssertEqual(error.domain, MTLTestModelErrorDomain, @"should return appropriate error if dictionary validation fails");
	XCTAssertEqual(error.code, MTLTestModelNameTooLong, @"should return appropriate error if dictionary validation fails");
}

- (void)testMergeTwoModels
{
	NSString *desc = @"should merge two models together";

	MTLTestModel *target = [[MTLTestModel alloc] initWithDictionary:@{ @"name": @"foo", @"count": @5 } error:NULL];
	XCTAssertNotNil(target,  @"%@", desc);

	MTLTestModel *source = [[MTLTestModel alloc] initWithDictionary:@{ @"name": @"bar", @"count": @3 } error:NULL];
	XCTAssertNotNil(source,  @"%@", desc);

	[target mergeValuesForKeysFromModel:source];

	XCTAssertEqualObjects(target.name, @"bar", @"%@", desc);
	XCTAssertEqual(target.count, (NSUInteger)8, @"%@", desc);
}

@end

@implementation MTLModelBasicDictionaryTestCase

- (void)setUp
{
	[super setUp];

	emptyModel = [[MTLEmptyTestModel alloc] init];
	XCTAssertNotNil(emptyModel);

	values = @{
		@"name": @"foobar",
		@"count": @(5),
		@"nestedName": @"fuzzbuzz",
		@"weakModel": emptyModel,
	};

	NSError *error = nil;
	model = [[MTLTestModel alloc] initWithDictionary:values error:&error];
	XCTAssertNotNil(model);
	XCTAssertNil(error);
}

- (void)testInitializeWithGivenValues
{
	NSString *desc = @"should initialize with the given values";

	XCTAssertEqualObjects(model.name, @"foobar", @"%@", desc);
	XCTAssertEqual(model.count, (NSUInteger)5, @"%@", desc);
	XCTAssertEqualObjects(model.nestedName, @"fuzzbuzz", @"%@", desc);
	XCTAssertEqualObjects(model.weakModel, emptyModel, @"%@", desc);

	XCTAssertEqualObjects(model.dictionaryValue, values, @"%@", desc);
	XCTAssertEqualObjects([model dictionaryWithValuesForKeys:values.allKeys], values, @"%@", desc);
}

- (void)testInitializeWithMatchingModel
{
	NSString *desc = @"should compare equal to a matching model";
	XCTAssertEqualObjects(model, model, @"%@", desc);

	MTLTestModel *matchingModel = [[MTLTestModel alloc] initWithDictionary:values error:NULL];
	XCTAssertEqualObjects(model, matchingModel, @"%@", desc);
	XCTAssertEqual(model.hash, matchingModel.hash, @"%@", desc);
	XCTAssertEqualObjects(model.dictionaryValue, matchingModel.dictionaryValue, @"%@", desc);
}

- (void)testInitializeWithDifferentModel
{
	NSString *desc = @"should not compare equal to different model";
	MTLTestModel *differentModel = [[MTLTestModel alloc] init];
	XCTAssertNotEqualObjects(model, differentModel, @"%@", desc);
	XCTAssertNotEqualObjects(model.dictionaryValue, differentModel.dictionaryValue, @"%@", desc);
}

- (void)testImplementsCopying
{
	NSString *desc = @"should implement <NSCopying>";
	MTLTestModel *copiedModel = [model copy];
	XCTAssertEqualObjects(copiedModel, model, @"%@", desc);
	XCTAssertNotEqual(copiedModel, model, @"%@", desc);
}

@end