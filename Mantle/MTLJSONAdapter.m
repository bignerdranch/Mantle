//
//  MTLJSONAdapter.m
//  Mantle
//
//  Created by Justin Spahr-Summers on 2013-02-12.
//  Copyright (c) 2013 GitHub. All rights reserved.
//

#import <objc/runtime.h>

#import "NSDictionary+MTLJSONKeyPath.h"

#import "MTLJSONAdapter.h"
#import "MTLModel.h"
#import "MTLTransformerErrorHandling.h"
#import "MTLReflection.h"
#import "MTLPropertyAttributes.h"
#import "NSValueTransformer+MTLPredefinedTransformerAdditions.h"
#import "NSDictionary+MTLMappingAdditions.h"

NSString * const MTLJSONAdapterErrorDomain = @"MTLJSONAdapterErrorDomain";
const NSInteger MTLJSONAdapterErrorNoClassFound = 2;
const NSInteger MTLJSONAdapterErrorInvalidJSONDictionary = 3;

// An exception was thrown and caught.
const NSInteger MTLJSONAdapterErrorExceptionThrown = 1;

// Associated with the NSException that was caught.
static NSString * const MTLJSONAdapterThrownExceptionErrorKey = @"MTLJSONAdapterThrownException";

@interface MTLJSONAdapter ()

// The MTLModel subclass being parsed, or the class of `model` if parsing has
// completed.
@property (nonatomic, strong, readonly) Class modelClass;

// Collect all value transformers needed for a given class.
//
// modelClass - The MTLModel subclass to attempt to parse from the JSON.
//              This class must conform to <MTLJSONSerializing>. This argument
//              must not be nil.
//
// Returns a dictionary with the properties of modelClass that need
// transformation as keys and the value transformers as values.
- (NSDictionary *)valueTransformersForModelClass:(Class)modelClass;

@end

@implementation MTLJSONAdapter

#pragma mark Convenience methods

+ (id)modelOfClass:(Class)modelClass fromJSONDictionary:(NSDictionary *)JSONDictionary error:(NSError **)error {
	MTLJSONAdapter *adapter = [[self alloc] initWithModelClass:modelClass];

	return [adapter modelFromJSONDictionary:JSONDictionary error:error];
}

+ (NSDictionary *)JSONDictionaryFromModel:(id<MTLJSONSerializing>)model error:(NSError **)error {
	MTLJSONAdapter *adapter = [[self alloc] initWithModelClass:model.class];

	return [adapter JSONDictionaryFromModel:model error:error];
}

#pragma mark Lifecycle

- (id)init {
	NSAssert(NO, @"%@ must be initialized with a model class", self.class);
	return nil;
}

- (id)initWithModelClass:(Class)modelClass {
	NSParameterAssert(modelClass != nil);
	NSParameterAssert([modelClass conformsToProtocol:@protocol(MTLJSONSerializing)]);

	self = [super init];
	if (self == nil) return nil;

	_modelClass = modelClass;

	return self;
}

#pragma mark Serialization

- (NSDictionary *)JSONDictionaryFromModel:(id<MTLJSONSerializing>)model error:(NSError **)error {
	NSParameterAssert(model != nil);
	NSParameterAssert([model isKindOfClass:self.modelClass]);

	NSDictionary *dictionaryValue = model.dictionaryValue;
	NSMutableDictionary *JSONDictionary = [[NSMutableDictionary alloc] initWithCapacity:dictionaryValue.count];

	NSDictionary *JSONKeyPathsByPropertyKey = [self JSONKeyPathsByPropertyKeyForModelClass:model.class];
	NSDictionary *valueTransformersByPropertyKey = [self valueTransformersForModelClass:model.class];

	__block BOOL success = YES;
	__block NSError *tmpError = nil;

	[dictionaryValue enumerateKeysAndObjectsUsingBlock:^(NSString *propertyKey, id value, BOOL *stop) {
		id JSONKeyPaths = JSONKeyPathsByPropertyKey[propertyKey];

		if (JSONKeyPaths == nil) return;

		NSValueTransformer *transformer = valueTransformersByPropertyKey[propertyKey];
		if ([transformer.class allowsReverseTransformation]) {
			// Map NSNull -> nil for the transformer, and then back for the
			// dictionaryValue we're going to insert into.
			if ([value isEqual:NSNull.null]) value = nil;

			if ([transformer respondsToSelector:@selector(reverseTransformedValue:success:error:)]) {
				id<MTLTransformerErrorHandling> errorHandlingTransformer = (id)transformer;

				value = [errorHandlingTransformer reverseTransformedValue:value success:&success error:&tmpError];

				if (!success) {
					*stop = YES;
					return;
				}
			} else {
				value = [transformer reverseTransformedValue:value] ?: NSNull.null;
			}
		}

		void (^createComponents)(id, NSString *) = ^(id obj, NSString *keyPath) {
			NSArray *keyPathComponents = [keyPath componentsSeparatedByString:@"."];

			// Set up dictionaries at each step of the key path.
			for (NSString *component in keyPathComponents) {
				if ([obj valueForKey:component] == nil) {
					// Insert an empty mutable dictionary at this spot so that we
					// can set the whole key path afterward.
					[obj setValue:[NSMutableDictionary dictionary] forKey:component];
				}

				obj = [obj valueForKey:component];
			}
		};

		if ([JSONKeyPaths isKindOfClass:NSString.class]) {
			createComponents(JSONDictionary, JSONKeyPaths);

			[JSONDictionary setValue:value forKeyPath:JSONKeyPaths];
		}

		if ([JSONKeyPaths isKindOfClass:NSArray.class]) {
			for (NSString *JSONKeyPath in JSONKeyPaths) {
				createComponents(JSONDictionary, JSONKeyPath);

				[JSONDictionary setValue:value[JSONKeyPath] forKeyPath:JSONKeyPath];
			}
		}
	}];

	if (success) {
		return JSONDictionary;
	} else {
		if (error != NULL) *error = tmpError;
		return nil;
	}
}

- (id)modelFromJSONDictionary:(NSDictionary *)JSONDictionary error:(NSError **)error {
	Class modelClass = self.modelClass;

	if ([modelClass respondsToSelector:@selector(classForParsingJSONDictionary:)]) {
		modelClass = [modelClass classForParsingJSONDictionary:JSONDictionary];
		if (modelClass == nil) {
			if (error != NULL) {
				NSDictionary *userInfo = @{
					NSLocalizedDescriptionKey: NSLocalizedString(@"Could not parse JSON", @""),
					NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"No model class could be found to parse the JSON dictionary.", @"")
				};

				*error = [NSError errorWithDomain:MTLJSONAdapterErrorDomain code:MTLJSONAdapterErrorNoClassFound userInfo:userInfo];
			}

			return nil;
		}

		NSAssert([modelClass conformsToProtocol:@protocol(MTLJSONSerializing)], @"Class %@ returned from +classForParsingJSONDictionary: does not conform to <MTLJSONSerializing>", modelClass);
	}

	NSDictionary *JSONKeyPathsByPropertyKey = [self JSONKeyPathsByPropertyKeyForModelClass:modelClass];
	NSDictionary *valueTransformersByPropertyKey = [self valueTransformersForModelClass:modelClass];

	NSDictionary *dictionaryValue = MTLCopyPropertyKeyMapUsingBlock(modelClass, ^id(NSString *propertyKey, BOOL *stop) {
		id JSONKeyPaths = JSONKeyPathsByPropertyKey[propertyKey];

		if (JSONKeyPaths == nil) return nil;

		id value;

		if ([JSONKeyPaths isKindOfClass:NSArray.class]) {
			NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

			for (NSString *keyPath in JSONKeyPaths) {
				if ([JSONDictionary mtl_getObjectValue:&value forJSONKeyPath:keyPath error:error]) {
					if (value != nil) dictionary[keyPath] = value;
				} else {
					*stop = YES;
					return nil;
				}
			}

			value = dictionary;
		} else {
			if (![JSONDictionary mtl_getObjectValue:&value forJSONKeyPath:JSONKeyPaths error:error]) {
				*stop = YES;
				return nil;
			}
		}

		if (value == nil) return nil;

		@try {
			NSValueTransformer *transformer = valueTransformersByPropertyKey[propertyKey];
			if (transformer != nil) {
				// Map NSNull -> nil for the transformer, and then back for the
				// dictionary we're going to insert into.
				if ([value isEqual:NSNull.null]) value = nil;

				if ([transformer respondsToSelector:@selector(transformedValue:success:error:)]) {
					id<MTLTransformerErrorHandling> errorHandlingTransformer = (id)transformer;

					BOOL success = YES;
					value = [errorHandlingTransformer transformedValue:value success:&success error:error];

					if (!success) {
						*stop = YES;
						return nil;
					}
				} else {
					value = [transformer transformedValue:value];
				}

				if (value == nil) value = NSNull.null;
			}

			return value;
		} @catch (NSException *ex) {
			NSLog(@"*** Caught exception %@ parsing JSON key path \"%@\" from: %@", ex, JSONKeyPaths, JSONDictionary);

			// Fail fast in Debug builds.
#if DEBUG
			@throw ex;
#else
			if (error != NULL) {
				NSDictionary *userInfo = @{
										   NSLocalizedDescriptionKey: ex.description,
										   NSLocalizedFailureReasonErrorKey: ex.reason,
										   MTLJSONAdapterThrownExceptionErrorKey: ex
										   };

				*error = [NSError errorWithDomain:MTLJSONAdapterErrorDomain code:MTLJSONAdapterErrorExceptionThrown userInfo:userInfo];
			}

			*stop = YES;
			return nil;
#endif
		}
	});

	if (!dictionaryValue) {
		return nil;
	}

	return [[modelClass alloc] initWithDictionary:dictionaryValue error:error];
}

- (NSDictionary *)valueTransformersForModelClass:(Class)modelClass {
	NSParameterAssert(modelClass != nil);
	NSParameterAssert([modelClass conformsToProtocol:@protocol(MTLJSONSerializing)]);

	__block MTLPropertyAttributes *reusedAttributes = nil;
	return MTLCopyPropertyKeyMapUsingBlock(modelClass, ^id(NSString *key, BOOL *stop) {
		SEL selector = MTLSelectorWithKeyPattern(NULL, key, "JSONTransformer");
		if ([modelClass respondsToSelector:selector]) {
			NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[modelClass methodSignatureForSelector:selector]];
			invocation.target = modelClass;
			invocation.selector = selector;
			[invocation invoke];

			__unsafe_unretained id transformer = nil;
			[invocation getReturnValue:&transformer];
			return transformer;
		}

		if ([modelClass respondsToSelector:@selector(JSONTransformerForKey:)]) {
			return [modelClass JSONTransformerForKey:key];
		}

		MTLPropertyAttributes *attributes = [MTLPropertyAttributes propertyNamed:key class:modelClass reusingAttributes:&reusedAttributes];

		if (attributes == nil) return nil;

		if (*(attributes.type) == *(@encode(id))) {
			Class propertyClass = attributes.objectClass;

			NSValueTransformer *transformer = nil;
			if (propertyClass != nil) {
				transformer = [self transformerForModelPropertiesOfClass:propertyClass];
			}
			return transformer ?: [NSValueTransformer mtl_validatingTransformerForClass:NSObject.class];
		}

		return [self transformerForModelPropertiesOfObjCType:attributes.type] ?: [NSValueTransformer mtl_validatingTransformerForClass:NSValue.class];
	});
}

- (NSDictionary *)JSONKeyPathsByPropertyKeyForModelClass:(Class)modelClass {
	NSParameterAssert(modelClass != nil);
	NSParameterAssert([modelClass conformsToProtocol:@protocol(MTLJSONSerializing)]);

	return [[modelClass JSONKeyPathsByPropertyKey] copy];
}

- (NSValueTransformer *)transformerForModelPropertiesOfClass:(Class)class {
	NSParameterAssert(class != nil);

	SEL selector = MTLSelectorWithKeyPattern(NULL, NSStringFromClass(class), "JSONTransformer");
	if (![self respondsToSelector:selector]) return nil;

	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:selector]];
	invocation.target = self;
	invocation.selector = selector;
	[invocation invoke];

	__unsafe_unretained id result = nil;
	[invocation getReturnValue:&result];
	return result;
}

- (NSValueTransformer *)transformerForModelPropertiesOfObjCType:(const char *)objCType {
	NSParameterAssert(objCType != NULL);

	if (strcmp(objCType, @encode(BOOL)) == 0) {
		return [NSValueTransformer valueTransformerForName:MTLBooleanValueTransformerName];
	}

	return nil;
}

@end

@implementation MTLJSONAdapter (ValueTransformers)

- (NSValueTransformer *)NSURLJSONTransformer {
	return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}

@end
