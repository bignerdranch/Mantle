//
//  MTLValueTransformerTestCase.m
//  Mantle
//
//  Created by Justin Spahr-Summers on 2012-09-11.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MTLValueTransformer.h"

@interface MTLValueTransformerTestCase : XCTestCase

@end

@implementation MTLValueTransformerTestCase

- (void)testForwardTransformerWithBlock
{
	NSString *desc = @"should return a forward transformer with a block";

	MTLValueTransformer *transformer = [MTLValueTransformer transformerWithBlock:^(NSString *str) {
		return [str stringByAppendingString:@"bar"];
	}];

	XCTAssertNotNil(transformer, @"%@", desc);
	XCTAssertFalse([transformer.class allowsReverseTransformation], @"%@", desc);

	XCTAssertEqualObjects([transformer transformedValue:@"foo"], @"foobar", @"%@", desc);
	XCTAssertEqualObjects([transformer transformedValue:@"bar"], @"barbar", @"%@", desc);
}

- (void)testReversibleTransformerWithBlock
{
	NSString *desc = @"should return a reversible transformer with a block";

	MTLValueTransformer *transformer = [MTLValueTransformer reversibleTransformerWithBlock:^(NSString *str) {
		return [str stringByAppendingString:@"bar"];
	}];

	XCTAssertNotNil(transformer, @"%@", desc);
	XCTAssertTrue([transformer.class allowsReverseTransformation], @"%@", desc);

	XCTAssertEqualObjects([transformer transformedValue:@"foo"], @"foobar", @"%@", desc);
	XCTAssertEqualObjects([transformer reverseTransformedValue:@"foo"], @"foobar", @"%@", desc);
}

- (void)testReversibleTransformerWithForwardAndReverseBlcoks
{
	NSString *desc = @"should return a reversible transformer with forward and reverse blocks";

	MTLValueTransformer *transformer = [MTLValueTransformer
		reversibleTransformerWithForwardBlock:^(NSString *str) {
			return [str stringByAppendingString:@"bar"];
		}
		reverseBlock:^(NSString *str) {
			return [str substringToIndex:str.length - 3];
		}];

	XCTAssertNotNil(transformer, @"%@", desc);
	XCTAssertTrue([transformer.class allowsReverseTransformation], @"%@", desc);

	XCTAssertEqualObjects([transformer transformedValue:@"foo"], @"foobar", @"%@", desc);
	XCTAssertEqualObjects([transformer reverseTransformedValue:@"foobar"], @"foo", @"%@", desc);
}

@end
