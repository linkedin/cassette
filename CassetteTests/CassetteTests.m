//
//  CassetteTests.m
//  CassetteTests
//
//  Created by Prateek Srivastava on 2015-06-03.
//  Copyright (c) 2015 Segment. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "QueueFile.h"

@interface CassetteTests : XCTestCase

@end

@implementation CassetteTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each
    // test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each
    // test method in the class.
    [super tearDown];
}

static void writeInt(NSMutableData *buffer, int offset, int value) {
    [buffer replaceBytesInRange:NSMakeRange(offset, 4) withBytes:&value];
}

static int readInt(NSData *data, int offset) {
    int value;
    [data getBytes:&value range:NSMakeRange(offset, 4)];
    return value;
}

- (void)testExample {
    // This is an example of a functional test case.
    XCTAssert(YES, @"Pass");

    NSMutableData *headerBuffer = [NSMutableData dataWithLength:16];
    writeInt(headerBuffer, 0, 4096);
    writeInt(headerBuffer, 4, 1024);
    // NSLog(@"wrote at 4: %@", headerBuffer.bytes);
    XCTAssertEqual(4096, readInt(headerBuffer, 0));
    XCTAssertEqual(1024, readInt(headerBuffer, 4));
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
