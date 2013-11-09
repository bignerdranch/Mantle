//
//  MTLModelValidationTestCase.m
//  Mantle
//
//  Created by Robert Böhnke on 7/6/13.
//  Copyright (c) 2013 GitHub. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MTLTestModel.h"

@interface MTLModelValidationTestCase : XCTestCase

@end

@implementation MTLModelValidationTestCase

- (void)testFail
{
	NSString *desc = @"should fail with incorrect values";

	MTLValidationModel *model = [[MTLValidationModel alloc] init];

	NSError *error = nil;
	BOOL success = [model validate:&error];

	XCTAssertFalse(success, @"%@", desc);
	XCTAssertNotNil(error, @"%@", desc);
	XCTAssertEqual(error.domain, MTLTestModelErrorDomain, @"%@", desc);
	XCTAssertEqual(error.code, MTLTestModelNameMissing, @"%@", desc);
}

- (void)testSucceed
{
	NSString *desc = @"should succeed with correct values";

	MTLValidationModel *model = [[MTLValidationModel alloc] initWithDictionary:@{ @"name": @"valid" } error:NULL];

	NSError *error = nil;
	BOOL success = [model validate:&error];

	XCTAssertTrue(success, @"%@", desc);
	XCTAssertNil(error, @"%@", desc);
}

- (void)testApply
{
	NSString *desc = @"should apply values returned from -validateValue:error:";

	MTLSelfValidatingModel *model = [[MTLSelfValidatingModel alloc] init];

	NSError *error = nil;
	BOOL success = [model validate:&error];

	XCTAssertTrue(success, @"%@", desc);
	XCTAssertEqualObjects(model.name, @"foobar", @"%@", desc);
	XCTAssertNil(error, @"%@", desc);
}

@end
