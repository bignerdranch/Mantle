//
//  MTLArrayManipulationTestCase.m
//  Mantle
//
//  Created by Josh Abernathy on 9/19/12.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSArray+MTLManipulationAdditions.h"

@interface MTLArrayManipulationTestCase : XCTestCase

@end

@implementation MTLArrayManipulationTestCase

- (void)testArrayByRemovingObject
{
	NSArray *array = @[ @1, @2, @3 ];
	NSArray *expected = @[ @2, @3 ];
	XCTAssertEqualObjects([array mtl_arrayByRemovingObject:@1], expected, @"should return a new array without the object");
}

- (void)testArrayByRemovingObjectMany
{
	NSArray *array = @[ @1, @2, @3, @1, @1 ];
	NSArray *expected = @[ @2, @3 ];
	XCTAssertEqualObjects([array mtl_arrayByRemovingObject:@1], expected, @"should return a new array without all occurrences of the object");
}

- (void)testArrayByRemovingObjectNone
{
	NSArray *array = @[ @1, @2, @3 ];
	XCTAssertEqualObjects([array mtl_arrayByRemovingObject:@42], array, @"should return an equivalent array if it doesn't contain the object");
}

- (void)testArrayByRemovingFirstObject
{
	NSArray *array = @[ @1, @2, @3 ];
	NSArray *expected = @[ @2, @3 ];
	XCTAssertEqualObjects([array mtl_arrayByRemovingFirstObject], expected, @"should return the array without the first object");
}

- (void)testArrayByRemovingFirstObjectEmpty
{
	NSArray *array = @[];
	XCTAssertEqualObjects([array mtl_arrayByRemovingFirstObject], array, @"should return the same array if it's empty");
}

- (void)testArrayByRemovingLastObject
{
	NSArray *array = @[ @1, @2, @3 ];
	NSArray *expected = @[ @1, @2 ];
	XCTAssertEqualObjects([array mtl_arrayByRemovingLastObject], expected, @"should return the array without the last object");
}

- (void)testArrayByRemovingLastObjectEmpty
{
	NSArray *array = @[];
	XCTAssertEqualObjects([array mtl_arrayByRemovingLastObject], array, @"should return the same array if it's empty");
}

@end
