//
//  MTLValueTransformerTestCase.m
//  Mantle
//
//  Created by Justin Spahr-Summers on 2012-09-11.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MTLValueTransformer.h"
#import "MTLTestModel.h"

#pragma mark - MTLValueTransformer

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

- (void)testPredefinedBooleanTransformer
{
	NSString *desc = @"should define an NSNumber boolean value transformer";
	// Back these NSNumbers with ints, rather than booleans,
	// to ensure that the value transformers are actually transforming.
	NSNumber *booleanYES = @(1);
	NSNumber *booleanNO = @(0);

	NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName:MTLBooleanValueTransformerName];
	XCTAssertNotNil(transformer, @"%@", desc);
	XCTAssertTrue([transformer.class allowsReverseTransformation], @"%@", desc);

	XCTAssertEqualObjects([transformer transformedValue:booleanYES], [NSNumber numberWithBool:YES], @"%@", desc);
	XCTAssertEqualObjects([transformer transformedValue:booleanYES], (id)kCFBooleanTrue, @"%@", desc);

	XCTAssertEqualObjects([transformer reverseTransformedValue:booleanYES], [NSNumber numberWithBool:YES], @"%@", desc);
	XCTAssertEqualObjects([transformer reverseTransformedValue:booleanYES], (id)kCFBooleanTrue, @"%@", desc);

	XCTAssertEqualObjects([transformer transformedValue:booleanNO], [NSNumber numberWithBool:NO], @"%@", desc);
	XCTAssertEqualObjects([transformer transformedValue:booleanNO], (id)kCFBooleanFalse, @"%@", desc);

	XCTAssertEqualObjects([transformer reverseTransformedValue:booleanNO], [NSNumber numberWithBool:NO], @"%@", desc);
	XCTAssertEqualObjects([transformer reverseTransformedValue:booleanNO], (id)kCFBooleanFalse, @"%@", desc);

	XCTAssertNil([transformer transformedValue:nil], @"%@", desc);
	XCTAssertNil([transformer reverseTransformedValue:nil], @"%@", desc);
}

@end

#pragma mark - JSON Dictionary

@interface MTLJSONDictionaryTransformerTestCase : XCTestCase {
	NSValueTransformer *transformer;

	MTLTestModel *model;
	NSDictionary *JSONDictionary;
}

@end

@implementation MTLJSONDictionaryTransformerTestCase

- (void)setUp
{
	[super setUp];

	model = [[MTLTestModel alloc] init];
	JSONDictionary = [MTLJSONAdapter JSONDictionaryFromModel:model];

	transformer = [MTLValueTransformer JSONDictionaryTransformerWithModelClass:MTLTestModel.class];
	XCTAssertNotNil(transformer);
}

- (void)testDictionaryToModel
{
	NSString *desc = @"dictionary JSON transformer should transform a JSON dictionary into a model";

	XCTAssertEqualObjects([transformer transformedValue:JSONDictionary], model, @"%@", desc);
}

- (void)testModelToDictionary
{
	NSString *desc = @"dictionary JSON transformer should transform a model into a JSON dictionary";

	XCTAssertTrue([transformer.class allowsReverseTransformation], @"%@", desc);
	XCTAssertEqualObjects([transformer reverseTransformedValue:model], JSONDictionary, @"%@", desc);
}

@end

#pragma mark - External array transformer

@interface MTLJSONExternalArrayTransformerTestCase : XCTestCase {
	NSValueTransformer *transformer;

	NSArray *models;
	NSArray *JSONDictionaries;
}

@end

@implementation MTLJSONExternalArrayTransformerTestCase

- (void)setUp
{
	[super setUp];

	NSMutableArray *uniqueModels = [NSMutableArray array];
	NSMutableArray *mutableDictionaries = [NSMutableArray array];

	for (NSUInteger i = 0; i < 10; i++) {
		MTLTestModel *model = [[MTLTestModel alloc] init];
		model.count = i;

		[uniqueModels addObject:model];

		NSDictionary *dict = [MTLJSONAdapter JSONDictionaryFromModel:model];
		XCTAssertNotNil(dict);

		[mutableDictionaries addObject:dict];
	}

	uniqueModels[2] = NSNull.null;
	mutableDictionaries[2] = NSNull.null;

	models = [uniqueModels copy];
	JSONDictionaries = [mutableDictionaries copy];

	transformer = [MTLValueTransformer JSONArrayTransformerWithModelClass:MTLTestModel.class];
	XCTAssertNotNil(transformer);
}

- (void)testDictionariesToModels
{
	NSString *desc = @"external representation array JSON transformer should transform JSON dictionaries into models";

	XCTAssertEqualObjects([transformer transformedValue:JSONDictionaries], models, @"%@", desc);
}

- (void)testModelsToDictionaries
{
	NSString *desc = @"external representation array JSON transformer should transform models into JSON dictionaries";

	XCTAssertTrue([transformer.class allowsReverseTransformation], @"%@", desc);
	XCTAssertEqualObjects([transformer reverseTransformedValue:models], JSONDictionaries, @"%@", desc);
}

@end

#pragma mark - Value mapping

enum : NSInteger {
	MTLPredefinedTransformerAdditionsSpecEnumNegative = -1,
	MTLPredefinedTransformerAdditionsSpecEnumZero = 0,
	MTLPredefinedTransformerAdditionsSpecEnumPositive = 1,
} MTLPredefinedTransformerAdditionsSpecEnum;

@interface MTLValueMappingTransformersTestCase : XCTestCase {
	NSValueTransformer *transformer;
}

@end

@implementation MTLValueMappingTransformersTestCase

- (void)setUp
{
	[super setUp];

	NSDictionary *dictionary = @{
								 @"negative": @(MTLPredefinedTransformerAdditionsSpecEnumNegative),
								 @[ @"zero" ]: @(MTLPredefinedTransformerAdditionsSpecEnumZero),
								 @"positive": @(MTLPredefinedTransformerAdditionsSpecEnumPositive),
								 };

	transformer = [MTLValueTransformer valueMappingTransformerWithDictionary:dictionary];
}

- (void)testEnumToString
{
	NSString *desc = @"value mapping transformer should transform enum values into strings";

	XCTAssertEqualObjects([transformer transformedValue:@"negative"], @(MTLPredefinedTransformerAdditionsSpecEnumNegative), @"%@", desc);
	XCTAssertEqualObjects([transformer transformedValue:@[ @"zero" ]], @(MTLPredefinedTransformerAdditionsSpecEnumZero), @"%@", desc);
	XCTAssertEqualObjects([transformer transformedValue:@"positive"], @(MTLPredefinedTransformerAdditionsSpecEnumPositive), @"%@", desc);
}

- (void)testStringToEnum
{
	NSString *desc = @"value mapping transformer should transform strings into enum values";

	XCTAssertTrue([transformer.class allowsReverseTransformation], @"%@", desc);

	XCTAssertEqualObjects([transformer reverseTransformedValue:@(MTLPredefinedTransformerAdditionsSpecEnumNegative)], @"negative", @"%@", desc);
	XCTAssertEqualObjects([transformer reverseTransformedValue:@(MTLPredefinedTransformerAdditionsSpecEnumZero)], @[ @"zero" ], @"%@", desc);
	XCTAssertEqualObjects([transformer reverseTransformedValue:@(MTLPredefinedTransformerAdditionsSpecEnumPositive)], @"positive", @"%@", desc);
}

@end
