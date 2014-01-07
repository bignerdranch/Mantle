//
//  MTLPropertyAttributes.m
//  Mantle
//
//  Created by Zach Waldowski on 11/8/13.
//  Copyright (c) 2013 GitHub. All rights reserved.
//

#import "MTLPropertyAttributes.h"
#import "MTLModel.h"
#import <objc/runtime.h>

@interface MTLPropertyAttributes ()

@property (nonatomic, copy, readwrite) NSString *name;
@property (nonatomic, readwrite, getter = isReadonly) BOOL readonly;
@property (nonatomic, readwrite, getter = isNonatomic) BOOL nonatomic;
@property (nonatomic, readwrite, getter = isDynamic) BOOL dynamic;
@property (nonatomic, readwrite) MTLPropertyMemoryPolicy memoryPolicy;
@property (nonatomic, readwrite) SEL getter;
@property (nonatomic, readwrite) SEL setter;
@property (nonatomic, readwrite) Class objectClass;
@property (nonatomic, copy) NSString *ivarString;
@property (nonatomic, copy) NSString *typeString;

@end

@implementation MTLPropertyAttributes

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@: %p, \"%@\">", NSStringFromClass(self.class), self, self.name];
}

- (NSString *)debugDescription
{
	NSMutableArray *attributeItems = [NSMutableArray array];
	if (self.nonatomic) {
		[attributeItems addObject:@"nonatomic"];
	}

	switch (self.memoryPolicy) {
		case MTLPropertyMemoryPolicyRetain:
			[attributeItems addObject:@"strong"];
			break;
		case MTLPropertyMemoryPolicyCopy:
			[attributeItems addObject:@"copy"];
			break;
		case MTLPropertyMemoryPolicyWeak:
			[attributeItems addObject:@"weak"];
			break;
		default: break;
	}

	if (self.readonly) {
		[attributeItems addObject:@"readonly"];
	}

	if (self.ivarString.length) {
		[attributeItems addObject:[NSString stringWithFormat:@"ivar = %@", self.ivarString]];
	}

	NSString *propertyAttributes = [attributeItems componentsJoinedByString:@", "];
	if (propertyAttributes.length) propertyAttributes = [NSString stringWithFormat:@"(%@) ", propertyAttributes];

	return [NSString stringWithFormat:@"<%@: %p, @property %@(%@) %@;>", NSStringFromClass(self.class), self, propertyAttributes, self.typeString, self.name];
}

+ (NSSet *)namesOfPropertiesInClassHierarchy:(Class)cls untilClass:(Class)endCls passingTest:(BOOL (^)(MTLPropertyAttributes *attributes))block
{
	NSParameterAssert(block);

	NSMutableSet *set = [NSMutableSet set];
	[self enumeratePropertiesOfClass:cls untilClass:endCls usingBlock:^(MTLPropertyAttributes *attributes) {
		if (block(attributes)) {
			[set addObject:attributes.name];
		}
	}];
	return [set copy];
}

+ (void)enumeratePropertiesOfClass:(Class)cls untilClass:(Class)endCls usingBlock:(void (^)(MTLPropertyAttributes *attributes))block
{
	if (endCls == NULL) endCls = [cls superclass];
	if (cls == NULL || cls == endCls || cls == NSObject.class) return;

	unsigned int count = 0;
	objc_property_t *properties = class_copyPropertyList(cls, &count);

	if (properties) {
		for (unsigned int i = 0; i < count; i++) {
			MTLPropertyAttributes *attributes = [[MTLPropertyAttributes alloc] initWithProperty:properties[i]];
			block(attributes);
		}

		free(properties);
	}

	[self enumeratePropertiesOfClass:cls.superclass untilClass:endCls usingBlock:block];
}

+ (void)enumeratePropertiesOfClass:(Class)cls named:(id <NSFastEnumeration>)propertyNames usingBlock:(void (^)(MTLPropertyAttributes *))block
{
	for (NSString *propertyName in propertyNames) {
		block([self propertyOfClass:cls named:propertyName]);
	}
}

+ (void)enumeratePropertiesInProtocolHierarchy:(Protocol *)proto untilProtocol:(Protocol *)endProto usingBlock:(void (^)(MTLPropertyAttributes *attributes))block;
{
	if (protocol_isEqual(proto, @protocol(NSObject)) || protocol_isEqual(proto, endProto)) {
		return;
	}

	unsigned int count = 0;

	objc_property_t *properties = protocol_copyPropertyList(proto, &count);
	if (properties) {
		for (unsigned int i = 0; i < count; i++) {
			MTLPropertyAttributes *attributes = [[MTLPropertyAttributes alloc] initWithProperty:properties[i]];
			block(attributes);
		}

		free(properties);
	}

	Protocol * __unsafe_unretained *protocols = protocol_copyProtocolList(proto, &count);
	if (protocols) {
		for (unsigned int i = 0; i < count; i++) {
			[self enumeratePropertiesInProtocolHierarchy:protocols[i] untilProtocol:endProto usingBlock:block];
		}

		free(protocols);
	}
}

+ (instancetype)propertyOfClass:(Class)cls named:(NSString *)propertyName
{
	objc_property_t property = class_getProperty(cls, propertyName.UTF8String);
	NSAssert(property, @"Could not find property \"%@\" on %@", propertyName, cls);

	MTLPropertyAttributes *attributes = [[MTLPropertyAttributes alloc] initWithProperty:property named:propertyName];
	return attributes;
}

+ (instancetype)propertyOfProtocol:(Protocol *)proto named:(NSString *)propertyName
{
	const char *name = propertyName.UTF8String;
	objc_property_t property = protocol_getProperty(proto, name, YES, YES);
	if (!property) property = protocol_getProperty(proto, name, NO, YES);
	if (!property) property = protocol_getProperty(proto, name, YES, NO);
	if (!property) property = protocol_getProperty(proto, name, NO, NO);
	NSAssert(property, @"Could not find property \"%@\" on %@", propertyName, proto);

	MTLPropertyAttributes *attributes = [[MTLPropertyAttributes alloc] initWithProperty:property named:propertyName];
	return attributes;
}

- (instancetype)initWithProperty:(objc_property_t)property
{
	NSString *propertyName = @(property_getName(property));
	return (self = [self initWithProperty:property named:propertyName]);
}

- (instancetype)initWithProperty:(objc_property_t)property named:(NSString *)propertyName
{
	const char *const attrString = property_getAttributes(property);
	NSAssert(attrString, @"Could not get attribute string from property %@", propertyName);
	NSAssert(attrString[0] == 'T', @"Expected attribute string \"%s\" for property %@ to start with 'T'", attrString, propertyName);

	const char *typeString = attrString + 1;
	const char *next = NSGetSizeAndAlignment(typeString, NULL, NULL);
	NSAssert(next, @"Could not read past type in attribute string \"%s\" for property %@", attrString, propertyName);

	size_t typeLength = next - typeString;
	NSAssert(typeLength, @"Invalid type in attribute string \"%s\" for property %@", attrString, propertyName);

	self = [super init];
	if (self) {
		self.name = propertyName;

		// copy the type string
		self.typeString = [[NSString alloc] initWithBytes:typeString length:typeLength encoding:NSASCIIStringEncoding];

		// if this is an object type, and immediately followed by a quoted string...
		if (typeString[0] == *(@encode(id)) && typeString[1] == '"') {
			// we should be able to extract a class name
			const char *className = typeString + 2;
			next = strchr(className, '"');

			NSAssert(next, @"Could not read class name in attribute string \"%s\" for property %@", attrString, propertyName);

			if (className != next) {
				size_t classNameLength = next - className;
				char trimmedName[classNameLength + 1];

				strncpy(trimmedName, className, classNameLength);
				trimmedName[classNameLength] = '\0';

				// attempt to look up the class in the runtime
				self.objectClass = objc_getClass(trimmedName);
			}
		}

		if (*next != '\0') {
			// skip past any junk before the first flag
			next = strchr(next, ',');
		}

		while (next && *next == ',') {
			char flag = next[1];
			next += 2;

			switch (flag) {
				case '\0': break;

				case 'R':
					self.readonly = YES;
					break;

				case 'C':
					self.memoryPolicy = MTLPropertyMemoryPolicyCopy;
					break;

				case '&':
					self.memoryPolicy = MTLPropertyMemoryPolicyRetain;
					break;

				case 'N':
					self.nonatomic = YES;
					break;

				case 'G':
				case 'S':
				{
					const char *nextFlag = strchr(next, ',');
					SEL name = NULL;

					if (!nextFlag) {
						// assume that the rest of the string is the selector
						const char *selectorString = next;
						next = "";

						name = sel_registerName(selectorString);
					} else {
						size_t selectorLength = nextFlag - next;
						NSAssert(selectorLength, @"Found zero length selector name in attribute string \"%s\" for property %@", attrString, propertyName);

						char selectorString[selectorLength + 1];

						strncpy(selectorString, next, selectorLength);
						selectorString[selectorLength] = '\0';

						name = sel_registerName(selectorString);
						next = nextFlag;
					}

					if (flag == 'G') {
						self.getter = name;
					} else {
						self.setter = name;
					}
				}

					break;

				case 'D':
					self.dynamic = YES;
					self.ivarString = nil;
					break;

				case 'V':
					// assume that the rest of the string (if present) is the ivar name
					if (*next == '\0') {
						// if there's nothing there, let's assume this is dynamic
						self.ivarString = nil;
					} else {
						self.ivarString = @(next);
						next = "";
					}

					break;

				case 'W':
					self.memoryPolicy = MTLPropertyMemoryPolicyWeak;
					break;

				case 'P': break; // can be garbage collected

				case 't':
					NSAssert(0, @"Old-style type encoding is unsupported in attribute string \"%s\" for property %@", attrString, propertyName);

					// skip over this type encoding
					while (*next != ',' && *next != '\0')
						++next;

					break;

				default:
					NSAssert(0, @"Unrecognized attribute string flag '%c' in attribute string \"%s\" for property %@", flag, attrString, propertyName);
			}
		}

		NSAssert(!next || *next == '\0', @"Warning: Unparsed data \"%s\" in attribute string \"%s\" for property %@", next, attrString, propertyName);

		if (!self.getter) {
			// use the property name as the getter by default
			self.getter = NSSelectorFromString(propertyName);
		}

		if (!self.setter) {
			// use the property name to create a set<Foo>: setter
			self.setter = MTLSelectorWithKeyPattern("set", propertyName, ":");
		}
	}
	return self;
}

- (const char *)type
{
	return self.typeString ? self.typeString.UTF8String : NULL;
}

- (const char *)ivar
{
	return self.ivarString ? self.ivarString.UTF8String : NULL;
}

@end
