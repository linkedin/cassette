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
@property(nonatomic, strong) NSString *filePath;
@property(nonatomic, strong) QueueFile *queueFile;
@end

@implementation CassetteTests

NSData *randomNSData() {
  NSMutableData *data = [NSMutableData dataWithLength:100000];
  for (unsigned int i = 0; i < 100000 / 4; ++i) {
    u_int32_t randomBits = arc4random();
    [data appendBytes:(void *)&randomBits length:4];
  }
  return data;
}

- (void)setUp {
  [super setUp];

  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                       NSUserDomainMask, YES);
  NSString *documentsDirectory = [paths objectAtIndex:0];
  self.filePath =
      [documentsDirectory stringByAppendingPathComponent:@"QueueFile.test"];
  self.queueFile = [QueueFile queueFileWithPath:self.filePath];
}

- (void)tearDown {
  [[NSFileManager defaultManager] removeItemAtPath:self.filePath error:nil];

  [super tearDown];
}

- (void)testPeek {
  XCTAssert(YES, @"Pass");

  NSData *data = randomNSData();

  [self.queueFile add:data];

  XCTAssertEqual([self.queueFile peek], data);
}

@end
