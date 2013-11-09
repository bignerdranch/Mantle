//
//  MTLErrorModelExceptionTestCase.m
//  Mantle
//
//  Created by Robert Böhnke on 7/6/13.
//  Copyright (c) 2013 GitHub. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSError+MTLModelException.h"

@interface MTLErrorModelExceptionTestCase : XCTestCase

@end

@implementation MTLErrorModelExceptionTestCase

- (void)testModalErrorWithException
{
	NSException *exception = [NSException exceptionWithName:@"MTLTestException" reason:@"Just Testing" userInfo:nil];

	NSError *error = [NSError mtl_modelErrorWithException:exception];

	XCTAssertNotNil(error, @"should return a non-nil error for that exception");
	XCTAssertEqualObjects(error.localizedDescription, @"Just Testing", @"should return an appropriate error for that exception");
	XCTAssertEqualObjects(error.localizedFailureReason, @"Just Testing", @"should return an appropriate error for that exception");
}

@end
