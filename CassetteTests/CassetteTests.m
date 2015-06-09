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

NSData *dataForString(NSString *text) {
  const char *s = [text UTF8String];
  return [NSData dataWithBytes:s length:strlen(s) + 1];
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

- (void)testAdd {
  [self.queueFile add:dataForString(@"foo")];

  XCTAssertEqual(1, [self.queueFile size]);
}

- (void)testMultipleAdd {
  [self.queueFile add:dataForString(@"foo")];
  [self.queueFile add:dataForString(@"bar")];
  [self.queueFile add:dataForString(@"baz")];

  XCTAssertEqual(3, [self.queueFile size]);
}

- (void)testRemove {
  [self.queueFile add:dataForString(@"foo")];
  
  [self.queueFile remove];
  
  XCTAssertEqual(0, [self.queueFile size]);
}

- (void)testRemoveWithMultipleInQueue {
  [self.queueFile add:dataForString(@"foo")];
  [self.queueFile add:dataForString(@"bar")];
  [self.queueFile add:dataForString(@"baz")];

  [self.queueFile remove];
  
  XCTAssertEqual(2, [self.queueFile size]);
}

- (void)testPeek {
  NSData *data = dataForString(@"bar");

  [self.queueFile add:data];

  XCTAssert([data isEqualToData:[self.queueFile peek]]);
}

- (void)testClear {
  [self.queueFile add:dataForString(@"foo")];
  [self.queueFile add:dataForString(@"bar")];
  [self.queueFile add:dataForString(@"baz")];
  XCTAssertEqual(3, [self.queueFile size]);

  [self.queueFile clear];

  XCTAssertEqual(0, [self.queueFile size]);
}

@end
