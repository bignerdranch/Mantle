//
//  MTLComparisonAdditionsTestCase.m
//  Mantle
//
//  Created by Josh Vera on 10/26/12.
//  Copyright (c) 2012 GitHub. All rights reserved.
//
//  Portions copyright (c) 2011 Bitswift. All rights reserved.
//  See the LICENSE file for more information.
//

#import <XCTest/XCTest.h>
#import "NSObject+MTLComparisonAdditions.h"

@interface MTLComparisonAdditionsTestCase : XCTestCase {
	id obj1;
	id obj2;
}

@end

@implementation MTLComparisonAdditionsTestCase

- (void)setUp
{
	[super setUp];

	obj1 = @"Test1";
	obj2 = @"Test2";
}

- (void)testNils
{
	XCTAssertTrue(MTLEqualObjects(nil, nil), @"returns true when given two values of nil");
}

- (void)testEqualObjects
{
	XCTAssertTrue(MTLEqualObjects(obj1, obj1), @"returns true when given two equal objects");
}

- (void)testInequalObjects
{
	XCTAssertFalse(MTLEqualObjects(obj1, obj2), @"returns false when given two inequal objects");
}

- (void)testObjectAndNil
{
	XCTAssertFalse(MTLEqualObjects(obj1, nil), @"returns false when given an object and nil");
}

- (void)testSymmetric
{
	BOOL result1 = MTLEqualObjects(obj2, obj1);
	BOOL result2 = MTLEqualObjects(obj1, obj2);
	XCTAssertEqual(result1, result2, @"returns the same value when given symmetric arguments");
}

- (void)testMutable
{
	id mutableObj1 = [obj1 mutableCopy];
	id mutableObj2 = [obj1 mutableCopy];

	XCTAssertTrue(MTLEqualObjects(mutableObj1, mutableObj2), @"returns true when given two equal but not identical objects");
}

@end
