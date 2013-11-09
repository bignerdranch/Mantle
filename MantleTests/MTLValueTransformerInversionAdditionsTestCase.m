//
//  MTLValueTransformerInversionAdditionsTestCase.m
//  Mantle
//
//  Created by Justin Spahr-Summers on 2013-05-18.
//  Copyright (c) 2013 GitHub. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSValueTransformer+MTLInversionAdditions.h"

@interface TestTransformer : NSValueTransformer
@end

@implementation TestTransformer

+ (BOOL)allowsReverseTransformation {
	return YES;
}

+ (Class)transformedValueClass {
	return NSString.class;
}

- (id)transformedValue:(id)value {
	return @"forward";
}

- (id)reverseTransformedValue:(id)value {
	return @"reverse";
}

@end

@interface MTLValueTransformerInversionAdditionsTestCase : XCTestCase {
	TestTransformer *transformer;
}

@end

@implementation MTLValueTransformerInversionAdditionsTestCase

- (void)setUp
{
	[super setUp];

	transformer = [[TestTransformer alloc] init];
	XCTAssertNotNil(transformer);
}

- (void)testInvert
{
	NSString *desc = @"should invert a transformer";

	NSValueTransformer *inverted = transformer.mtl_invertedTransformer;
	XCTAssertNotNil(inverted, @"%@", desc);

	XCTAssertEqualObjects([inverted transformedValue:nil], @"reverse", @"%@", desc);
	XCTAssertEqualObjects([inverted reverseTransformedValue:nil], @"forward", @"%@", desc);
}

- (void)testInvertInverted
{
	NSString *desc = @"should invert an inverted transformer";

	NSValueTransformer *inverted = transformer.mtl_invertedTransformer.mtl_invertedTransformer;
	XCTAssertNotNil(inverted, @"%@", desc);

	XCTAssertEqualObjects([inverted transformedValue:nil], @"forward", @"%@", desc);
	XCTAssertEqualObjects([inverted reverseTransformedValue:nil], @"reverse", @"%@", desc);
}

@end
