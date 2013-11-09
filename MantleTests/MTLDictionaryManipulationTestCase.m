//
//  MTLDictionaryManipulationTestCase.m
//  Mantle
//
//  Created by Justin Spahr-Summers on 2012-09-24.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSDictionary+MTLManipulationAdditions.h"

@interface MTLDictionaryManipulationTestCase : XCTestCase {
	NSDictionary *dict;
}

@end

@implementation MTLDictionaryManipulationTestCase

- (void)setUp
{
	[super setUp];

	dict = @{ @"foo": @"bar", @(5): NSNull.null };
}

- (void)testDictionaryByAddingEntriesEmpty
{
	NSDictionary *combined = [dict mtl_dictionaryByAddingEntriesFromDictionary:@{}];
	XCTAssertEqualObjects(combined, dict, @"should return the same dictionary when adding from an empty dictionary");
}

- (void)testDictionaryByAddingEntriesNil
{
	NSDictionary *combined = [dict mtl_dictionaryByAddingEntriesFromDictionary:nil];
	XCTAssertEqualObjects(combined, dict, @"should return the same dictionary when adding from nil");
}

- (void)testDictionaryByAddingEntries
{
	NSDictionary *combined = [dict mtl_dictionaryByAddingEntriesFromDictionary:@{ @"buzz": @(10), @"baz": NSNull.null }];
	NSDictionary *expected = @{ @"foo": @"bar", @(5): NSNull.null, @"buzz": @(10), @"baz": NSNull.null };
	XCTAssertEqualObjects(combined, expected, @"should add any new keys");
}

- (void)testDictionaryByAddingEntriesReplace
{
	NSDictionary *combined = [dict mtl_dictionaryByAddingEntriesFromDictionary:@{ @(5): @(10), @"buzz": @"baz" }];
	NSDictionary *expected = @{ @"foo": @"bar", @(5): @(10), @"buzz": @"baz" };
	XCTAssertEqualObjects(combined, expected, @"should replace any existing keys");
}

@end
