//
//  MTLModelNSCodingTestCase.m
//  Mantle
//
//  Created by Justin Spahr-Summers on 2013-02-13.
//  Copyright (c) 2013 GitHub. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MTLModel+NSCoding.h"
#import "MTLTestModel.h"

@interface MTLModelNSCodingTestCase : XCTestCase

@end

@interface MTLModelNSCodingAchivingTestCase : XCTestCase {
	MTLEmptyTestModel *emptyModel;
	MTLTestModel *model;
	NSDictionary *values;

	MTLTestModel * (^archiveAndUnarchiveModel)(void);
}

@end

@implementation MTLModelNSCodingTestCase

- (void)testDefaultEncodingBehaviors
{
	NSString *desc = @"should have default encoding behaviors";

	NSDictionary *behaviors = MTLTestModel.encodingBehaviorsByPropertyKey;
	XCTAssertNotNil(behaviors, @"%@", desc);

	XCTAssertEqualObjects(behaviors[@"name"], @(MTLModelEncodingBehaviorUnconditional), @"%@", desc);
	XCTAssertEqualObjects(behaviors[@"count"], @(MTLModelEncodingBehaviorUnconditional), @"%@", desc);
	XCTAssertEqualObjects(behaviors[@"weakModel"], @(MTLModelEncodingBehaviorConditional), @"%@", desc);
	XCTAssertNil(behaviors[@"dynamicName"], @"%@", desc);
}

- (void)testDefaultAllowedClasses
{
	NSString *desc = @"should have default allowed classes";

	NSDictionary *allowedClasses = MTLTestModel.allowedSecureCodingClassesByPropertyKey;
	XCTAssertNotNil(allowedClasses, @"%@", desc);

	XCTAssertEqualObjects(allowedClasses[@"name"], @[ NSString.class ], @"%@", desc);
	XCTAssertEqualObjects(allowedClasses[@"count"], @[ NSValue.class ], @"%@", desc);
	XCTAssertEqualObjects(allowedClasses[@"weakModel"], @[ MTLEmptyTestModel.class ], @"%@", desc);

	// Not encoded into archives.
	XCTAssertNil(allowedClasses[@"nestedName"], @"%@", desc);
	XCTAssertNil(allowedClasses[@"dynamicName"], @"%@", desc);
}

- (void)testVersion
{
	XCTAssertEqual(MTLEmptyTestModel.modelVersion, (NSUInteger)0, @"should default to version 0");
}

@end

@implementation MTLModelNSCodingAchivingTestCase

- (void)setUp
{
	[super setUp];

	emptyModel = [[MTLEmptyTestModel alloc] init];
	XCTAssertNotNil(emptyModel);

	values = @{
		@"name": @"foobar",
		@"count": @5,
	};

	NSError *error = nil;
	model = [[MTLTestModel alloc] initWithDictionary:values error:&error];
	XCTAssertNotNil(model);
	XCTAssertNil(error);


	__weak MTLModelNSCodingAchivingTestCase *blockSelf = self;
	archiveAndUnarchiveModel = [^{
		MTLModelNSCodingAchivingTestCase *self = blockSelf;

		NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self->model];
		XCTAssertNotNil(data);

		MTLTestModel *unarchivedModel = [NSKeyedUnarchiver unarchiveObjectWithData:data];
		XCTAssertNotNil(data);

		return unarchivedModel;
	} copy];
}

- (void)testUnconditionalProperties
{
	XCTAssertEqualObjects(archiveAndUnarchiveModel(), model, @"archiving should archive unconditional properties");
}

- (void)testExcludedProperties
{
	NSString *desc = @"archiving should not archive excluded properties";

	model.nestedName = @"foobar";

	MTLTestModel *unarchivedModel = archiveAndUnarchiveModel();
	XCTAssertNil(unarchivedModel.nestedName, @"%@", desc);
	XCTAssertNotEqualObjects(unarchivedModel, model, @"%@", desc);

	model.nestedName = nil;
	XCTAssertEqualObjects(unarchivedModel, model, @"%@", desc);
}

- (void)testConditionalPropertiesFail
{
	model.weakModel = emptyModel;

	MTLTestModel *unarchivedModel = archiveAndUnarchiveModel();
	XCTAssertNil(unarchivedModel.weakModel, @"archiving should not archive conditional properties if not encoded elsewhere");
}

- (void)testConditionalPropertiesSuccess
{
	NSString *desc = @"archiving should archive conditional properties if encoded elsewhere";

	model.weakModel = emptyModel;

	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:@[ model, emptyModel ]];
	XCTAssertNotNil(data);

	NSArray *objects = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	XCTAssertEqual(objects.count, (NSUInteger)2, @"%@", desc);
	XCTAssertEqualObjects(objects[1], emptyModel, @"%@", desc);

	MTLTestModel *unarchivedModel = objects[0];
	XCTAssertEqualObjects(unarchivedModel, model, @"%@", desc);
	XCTAssertEqualObjects(unarchivedModel.weakModel, emptyModel, @"%@", desc);
}

- (void)testCustomLogic
{
	NSString *desc = @"archiving should invoke custom decoding logic";

	MTLTestModel.modelVersion = 0;

	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:model];
	XCTAssertNotNil(data, @"%@", desc);

	MTLTestModel.modelVersion = 1;

	MTLTestModel *unarchivedModel = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	XCTAssertNotNil(unarchivedModel, @"%@", desc);
	XCTAssertEqualObjects(unarchivedModel.name, @"M: foobar", @"%@", desc);
	XCTAssertEqual(unarchivedModel.count, (NSUInteger)5, @"%@", desc);
}

- (void)testExternalRepresentation
{
	NSString *desc = @"archiving should unarchive an external representation from the old model format";

	NSURL *archiveURL = [[NSBundle bundleForClass:self.class] URLForResource:@"MTLTestModel-OldArchive" withExtension:@"plist"];
	XCTAssertNotNil(archiveURL, @"%@", desc);

	MTLTestModel *unarchivedModel = [NSKeyedUnarchiver unarchiveObjectWithFile:archiveURL.path];
	XCTAssertNotNil(unarchivedModel, @"%@", desc);

	NSDictionary *expectedValues = @{
		@"name": @"foobar",
		@"count": @5,
		@"nestedName": @"fuzzbuzz",
		@"weakModel": NSNull.null,
	};

	XCTAssertEqualObjects(unarchivedModel.dictionaryValue, expectedValues, @"%@", desc);
}

@end
