//
//  MTLJSONAdapterTestCase.m
//  Mantle
//
//  Created by Justin Spahr-Summers on 2013-02-13.
//  Copyright (c) 2013 GitHub. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MTLJSONAdapter.h"
#import "MTLTestModel.h"

@interface MTLJSONAdapterTestCase : XCTestCase

@end

@implementation MTLJSONAdapterTestCase

- (void)testInitializeFromJSON
{
	NSString *desc = @"should initialize from JSON";

	NSDictionary *values = @{
		@"username": NSNull.null,
		@"count": @5,
	};

	NSError *error = nil;
	MTLJSONAdapter *adapter = [[MTLJSONAdapter alloc] initWithJSONDictionary:values modelClass:MTLTestModel.class error:&error];
	XCTAssertNotNil(adapter, @"%@", desc);
	XCTAssertNil(error, @"%@", desc);

	MTLTestModel *model = (id)adapter.model;
	XCTAssertNotNil(model, @"%@", desc);
	XCTAssertNil(model.name, @"%@", desc);
	XCTAssertEqual(model.count, (NSUInteger)5, @"%@", desc);

	NSDictionary *JSONDictionary = @{
		@"username": NSNull.null,
		@"count": @"5",
		@"nested": @{ @"name": NSNull.null },
	};

	XCTAssertEqualObjects(adapter.JSONDictionary, JSONDictionary, @"should initialize from JSON");
}

- (void)testInitializeFromModel
{
	NSString *desc = @"should initialize from a model";

	MTLTestModel *model = [MTLTestModel modelWithDictionary:@{
		@"name": @"foobar",
		@"count": @5,
	} error:NULL];

	MTLJSONAdapter *adapter = [[MTLJSONAdapter alloc] initWithModel:model];
	XCTAssertNotNil(adapter, @"%@", desc);
	XCTAssertEqual(adapter.model, model, @"%@", desc);

	NSDictionary *JSONDictionary = @{
		@"username": @"foobar",
		@"count": @"5",
		@"nested": @{ @"name": NSNull.null },
	};

	XCTAssertEqualObjects(adapter.JSONDictionary, JSONDictionary, @"should initialize from a model");
}

- (void)testInitializeNestedKeyPathsFromJSON
{
	NSString *desc = @"should initialize nested key paths from JSON";

	NSDictionary *values = @{
		@"username": @"foo",
		@"nested": @{ @"name": @"bar" },
		@"count": @"0"
	};

	NSError *error = nil;
	MTLTestModel *model = [MTLJSONAdapter modelOfClass:MTLTestModel.class fromJSONDictionary:values error:&error];
	XCTAssertNotNil(model, @"%@", desc);
	XCTAssertNil(error, @"%@", desc);

	XCTAssertEqualObjects(model.name, @"foo", @"%@", desc);
	XCTAssertEqual(model.count, (NSUInteger)0, @"%@", desc);
	XCTAssertEqualObjects(model.nestedName, @"bar", @"%@", desc);

	XCTAssertEqualObjects([MTLJSONAdapter JSONDictionaryFromModel:model], values, @"%@", desc);
}

- (void)testNilJSON
{
	NSError *error = nil;
	MTLJSONAdapter *adapter = [[MTLJSONAdapter alloc] initWithJSONDictionary:nil modelClass:MTLTestModel.class error:&error];
	XCTAssertNil(adapter, @"should return no adapter for a nil JSON dictionary");
	XCTAssertNotNil(error, @"should return an error for a nil JSON dictionary");
	XCTAssertEqual(error.domain, MTLJSONAdapterErrorDomain, @"should return an appropriate error for a nil JSON dictionary");
	XCTAssertEqual(error.code, MTLJSONAdapterErrorInvalidJSONDictionary, @"should return an appropriate error for a nil JSON dictionary");
}

- (void)testWrongDataType
{
	NSString *desc = @"should return nil and an error with a wrong data type as dictionary";

	NSError *error = nil;
	id wrongDictionary = [NSString new];
	MTLJSONAdapter *adapter = [[MTLJSONAdapter alloc] initWithJSONDictionary:wrongDictionary modelClass:MTLTestModel.class error:&error];

	XCTAssertNil(adapter, @"%@", desc);
	XCTAssertNotNil(error, @"%@", desc);
	XCTAssertEqualObjects(error.domain, MTLJSONAdapterErrorDomain, @"%@", desc);
	XCTAssertEqual(error.code, MTLJSONAdapterErrorInvalidJSONDictionary, @"%@", desc);
}

- (void)testUnrecognizedJSONKeys
{
	NSString *desc = @"should ignore unrecognized JSON keys";

	NSDictionary *values = @{
		@"foobar": @"foo",
		@"count": @"2",
		@"_": NSNull.null,
		@"username": @"buzz",
		@"nested": @{ @"name": @"bar", @"stuffToIgnore": @5, @"moreNonsense": NSNull.null },
	};

	NSError *error = nil;
	MTLTestModel *model = [MTLJSONAdapter modelOfClass:MTLTestModel.class fromJSONDictionary:values error:&error];
	XCTAssertNotNil(model, @"%@", desc);
	XCTAssertNil(error, @"%@", desc);

	XCTAssertEqualObjects(model.name, @"buzz", @"%@", desc);
	XCTAssertEqual(model.count, (NSUInteger)2, @"%@", desc);
	XCTAssertEqualObjects(model.nestedName, @"bar", @"%@", desc);
}

- (void)testFailedValidation
{
	NSDictionary *values = @{
		@"username": @"this is too long a name",
	};

	NSError *error = nil;
	MTLTestModel *model = [MTLJSONAdapter modelOfClass:MTLTestModel.class fromJSONDictionary:values error:&error];
	XCTAssertNil(model, @"should fail to initialize model if JSON dictionary validation fails");
	XCTAssertNotNil(error, @"should return an error if JSON dictionary validation fails");
	XCTAssertEqual(error.domain, MTLTestModelErrorDomain, @"should return an appropriate error if JSON dictionary validation fails");
	XCTAssertEqual(error.code, MTLTestModelNameTooLong, @"should return an appropriate error if JSON dictionary validation fails");
}

- (void)testDifferentModelClass
{
	NSString *desc = @"should parse a different model class";

	NSDictionary *values = @{
		@"username": @"foo",
		@"nested": @{ @"name": @"bar" },
		@"count": @"0"
	};

	NSError *error = nil;
	MTLTestModel *model = [MTLJSONAdapter modelOfClass:MTLSubstitutingTestModel.class fromJSONDictionary:values error:&error];
	XCTAssertNotNil(model, @"%@", desc);
	XCTAssertEqual(model.class, MTLTestModel.class, @"%@", desc);
	XCTAssertNil(error, @"%@", desc);

	XCTAssertEqualObjects(model.name, @"foo", @"%@", desc);
	XCTAssertEqual(model.count, (NSUInteger)0, @"%@", desc);
	XCTAssertEqualObjects(model.nestedName, @"bar", @"%@", desc);

	XCTAssertEqualObjects([MTLJSONAdapter JSONDictionaryFromModel:model], values, @"%@", desc);
}

- (void)testDifferentModelClassFail
{
	NSError *error = nil;
	MTLTestModel *model = [MTLJSONAdapter modelOfClass:MTLSubstitutingTestModel.class fromJSONDictionary:@{} error:&error];
	XCTAssertNil(model, @"should return no object when no suitable model class is found");
	XCTAssertNotNil(error, @"should return an error when no suitable model class is found");
	XCTAssertEqual(error.domain, MTLJSONAdapterErrorDomain, @"should return an appropriate error when no suitable model class is found");
	XCTAssertEqual(error.code, MTLJSONAdapterErrorNoClassFound, @"should return an appropriate error when no suitable model class is found");
}

@end
