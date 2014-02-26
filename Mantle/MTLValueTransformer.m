//
//  MTLValueTransformer.m
//  Mantle
//
//  Created by Justin Spahr-Summers on 2012-09-11.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "MTLValueTransformer.h"
#import "MTLJSONAdapter.h"
#import "MTLModel.h"

NSString * const MTLBooleanValueTransformerName = @"MTLBooleanValueTransformerName";

//
// Any MTLValueTransformer supporting reverse transformation. Necessary because
// +allowsReverseTransformation is a class method.
//
@interface MTLReversibleValueTransformer : MTLValueTransformer
@end

@interface MTLValueTransformer ()

@property (nonatomic, copy, readonly) id(^forwardBlock)(id);
@property (nonatomic, copy, readonly) id(^reverseBlock)(id);

@end

@implementation MTLValueTransformer

#pragma mark Lifecycle

+ (instancetype)transformerWithBlock:(id(^)(id))transformationBlock {
	return [[self alloc] initWithForwardBlock:transformationBlock reverseBlock:nil];
}

+ (instancetype)reversibleTransformerWithBlock:(id(^)(id))transformationBlock {
	return [self reversibleTransformerWithForwardBlock:transformationBlock reverseBlock:transformationBlock];
}

+ (instancetype)reversibleTransformerWithForwardBlock:(id(^)(id))forwardBlock reverseBlock:(id(^)(id))reverseBlock {
	return [[MTLReversibleValueTransformer alloc] initWithForwardBlock:forwardBlock reverseBlock:reverseBlock];
}

- (id)initWithForwardBlock:(id(^)(id))forwardBlock reverseBlock:(id(^)(id))reverseBlock {
	NSParameterAssert(forwardBlock != nil);

	self = [super init];
	if (self == nil) return nil;

	_forwardBlock = [forwardBlock copy];
	_reverseBlock = [reverseBlock copy];

	return self;
}

#pragma mark NSValueTransformer

+ (BOOL)allowsReverseTransformation {
	return NO;
}

+ (Class)transformedValueClass {
	return [NSObject class];
}

- (id)transformedValue:(id)value {
	return self.forwardBlock(value);
}

@end

@implementation MTLReversibleValueTransformer

#pragma mark Lifecycle

- (id)initWithForwardBlock:(id(^)(id))forwardBlock reverseBlock:(id(^)(id))reverseBlock {
	NSParameterAssert(reverseBlock != nil);
	return [super initWithForwardBlock:forwardBlock reverseBlock:reverseBlock];
}

#pragma mark NSValueTransformer

+ (BOOL)allowsReverseTransformation {
	return YES;
}

- (id)reverseTransformedValue:(id)value {
	return self.reverseBlock(value);
}

@end

#pragma mark Predefined Transformers

@implementation NSValueTransformer (MTLPredefinedTransformerAdditions)

+ (void)load {
	@autoreleasepool {
		MTLValueTransformer *booleanValueTransformer = [MTLValueTransformer
														reversibleTransformerWithBlock:^id(NSNumber *boolean) {
															if (![boolean isKindOfClass:NSNumber.class]) return nil;
															return (boolean.boolValue) ? @YES : @NO;
														}];

		[NSValueTransformer setValueTransformer:booleanValueTransformer forName:MTLBooleanValueTransformerName];
	}
}

@end

@implementation MTLValueTransformer (MTLPredefinedTransformers)

+ (instancetype)booleanValueTransformer
{
	return (MTLValueTransformer *)[NSValueTransformer valueTransformerForName:MTLBooleanValueTransformerName];
}

+ (instancetype)JSONDictionaryTransformerWithModelClass:(Class)modelClass {
	NSParameterAssert([modelClass isSubclassOfClass:MTLModel.class]);
	NSParameterAssert([modelClass conformsToProtocol:@protocol(MTLJSONSerializing)]);

	return [MTLValueTransformer
		reversibleTransformerWithForwardBlock:^ id (id JSONDictionary) {
			if (JSONDictionary == nil) return nil;

			NSAssert([JSONDictionary isKindOfClass:NSDictionary.class], @"Expected a dictionary, got: %@", JSONDictionary);

			return [MTLJSONAdapter modelOfClass:modelClass fromJSONDictionary:JSONDictionary error:NULL];
		}
		reverseBlock:^ id (id model) {
			if (model == nil) return nil;

			NSAssert([model isKindOfClass:MTLModel.class], @"Expected a MTLModel object, got %@", model);
			NSAssert([model conformsToProtocol:@protocol(MTLJSONSerializing)], @"Expected a model object conforming to <MTLJSONSerializing>, got %@", model);

			return [MTLJSONAdapter JSONDictionaryFromModel:model];
		}];
}

+ (instancetype)JSONArrayTransformerWithModelClass:(Class)modelClass {
	NSValueTransformer *dictionaryTransformer = [self JSONDictionaryTransformerWithModelClass:modelClass];

	return [MTLValueTransformer
		reversibleTransformerWithForwardBlock:^ id (NSArray *dictionaries) {
			if (dictionaries == nil) return nil;

			NSAssert([dictionaries isKindOfClass:NSArray.class], @"Expected a array of dictionaries, got: %@", dictionaries);

			NSMutableArray *models = [NSMutableArray arrayWithCapacity:dictionaries.count];
			for (id JSONDictionary in dictionaries) {
				if (JSONDictionary == NSNull.null) {
					[models addObject:NSNull.null];
					continue;
				}

				NSAssert([JSONDictionary isKindOfClass:NSDictionary.class], @"Expected a dictionary or an NSNull, got: %@", JSONDictionary);

				id model = [dictionaryTransformer transformedValue:JSONDictionary];
				if (model == nil) continue;

				[models addObject:model];
			}

			return models;
		}
		reverseBlock:^ id (NSArray *models) {
			if (models == nil) return nil;

			NSAssert([models isKindOfClass:NSArray.class], @"Expected a array of MTLModels, got: %@", models);

			NSMutableArray *dictionaries = [NSMutableArray arrayWithCapacity:models.count];
			for (id model in models) {
				if (model == NSNull.null) {
					[dictionaries addObject:NSNull.null];
					continue;
				}

				NSAssert([model isKindOfClass:MTLModel.class], @"Expected an MTLModel or an NSNull, got: %@", model);

				NSDictionary *dict = [dictionaryTransformer reverseTransformedValue:model];
				if (dict == nil) continue;

				[dictionaries addObject:dict];
			}

			return dictionaries;
		}];
}

+ (instancetype)valueMappingTransformerWithDictionary:(NSDictionary *)dictionary {
	NSParameterAssert(dictionary != nil);
	NSParameterAssert(dictionary.count == [[NSSet setWithArray:dictionary.allValues] count]);

	return [MTLValueTransformer reversibleTransformerWithForwardBlock:^(id<NSCopying> key) {
		return dictionary[key ?: NSNull.null];
	} reverseBlock:^(id object) {
		__block id result = nil;
		[dictionary enumerateKeysAndObjectsUsingBlock:^(id key, id anObject, BOOL *stop) {
			if ([object isEqual:anObject]) {
				result = key;
				*stop = YES;
			}
		}];
		return result;
	}];
}


@end
