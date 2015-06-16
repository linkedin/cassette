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

/*!
 * @define XCTAssertDataEqual(data, expected)
 * Generates a failure when the given data objects are not equal.
 */
#define XCTAssertDataEqual(actual, expected)   \
    XCTAssert([expected isEqualToData:actual], \
              @"Expected %@ to be equal to %@.", expected, actual)


@interface CassetteTests : XCTestCase

@property (nonatomic, strong) NSString *filePath;
@property (nonatomic, strong) QueueFile *queueFile;
@end


@implementation CassetteTests

NSData *dataForString(NSString *text)
{
    const char *s = [text UTF8String];
    return [NSData dataWithBytes:s length:strlen(s) + 1];
}

- (void)setUp
{
    [super setUp];

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                         NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    self.filePath =
        [documentsDirectory stringByAppendingPathComponent:@"QueueFile.test"];
    self.queueFile = [QueueFile queueFileWithPath:self.filePath];
    [self.queueFile clear];
}

- (void)tearDown
{
    [[NSFileManager defaultManager] removeItemAtPath:self.filePath error:nil];

    [super tearDown];
}

- (void)testAddOneElement
{
    NSData *foo = dataForString(@"foo");
    [self.queueFile add:foo];
    XCTAssert([foo isEqualToData:[self.queueFile peek]]);
    XCTAssertEqual(1, [self.queueFile size]);

    self.queueFile = [QueueFile queueFileWithPath:self.filePath];
    XCTAssert([foo isEqualToData:[self.queueFile peek]]);
    XCTAssertEqual(1, [self.queueFile size]);
}

- (void)testMultipleAdd
{
    [self.queueFile add:dataForString(@"foo")];
    [self.queueFile add:dataForString(@"bar")];
    [self.queueFile add:dataForString(@"baz")];

    XCTAssertEqual(3, [self.queueFile size]);
}

- (void)testRemove
{
    [self.queueFile add:dataForString(@"foo")];

    [self.queueFile remove];

    XCTAssertEqual(0, [self.queueFile size]);
}

- (void)testRemoveWithMultipleInQueue
{
    [self.queueFile add:dataForString(@"foo")];
    [self.queueFile add:dataForString(@"bar")];
    [self.queueFile add:dataForString(@"baz")];

    [self.queueFile remove];

    XCTAssertEqual(2, [self.queueFile size]);
}

- (void)testPeek
{
    NSData *bar = dataForString(@"bar");

    [self.queueFile add:bar];

    XCTAssertDataEqual(bar, [self.queueFile peek]);
}

- (void)testClear
{
    [self.queueFile add:dataForString(@"foo")];
    [self.queueFile add:dataForString(@"bar")];
    [self.queueFile add:dataForString(@"baz")];
    XCTAssertEqual(3, [self.queueFile size]);

    [self.queueFile clear];

    XCTAssertEqual(0, [self.queueFile size]);
}

- (void)testClearErasesDataFromFile
{
    NSData *foo = dataForString(@"foo");
    [self.queueFile add:foo];

    // Confirm that the data was in the file before we cleared.
    NSFileHandle *fileHandle =
        [NSFileHandle fileHandleForUpdatingAtPath:self.filePath];
    [fileHandle seekToFileOffset:16 + 4]; // Seek to first element
    XCTAssertDataEqual(foo, [fileHandle readDataOfLength:foo.length]);

    [self.queueFile clear];

    // Should have been erased.
    NSData *empty = [NSMutableData dataWithLength:foo.length];
    [fileHandle seekToFileOffset:16 + 4]; // Seek to first element
    XCTAssertDataEqual(empty, [fileHandle readDataOfLength:foo.length]);
}

- (void)testSuccessivePeekAndRemove
{
    NSData *foo = dataForString(@"foo");
    NSData *bar = dataForString(@"bar");
    NSData *baz = dataForString(@"baz");

    [self.queueFile add:foo];
    [self.queueFile add:bar];
    [self.queueFile add:baz];
    self.queueFile = [QueueFile queueFileWithPath:self.filePath];

    XCTAssertDataEqual(foo, [self.queueFile peek]);
    [self.queueFile remove];
    XCTAssertDataEqual(bar, [self.queueFile peek]);
    [self.queueFile remove];
    XCTAssertDataEqual(baz, [self.queueFile peek]);
}

- (void)testRecoversFromIncompleteWrite
{
    // Add an entry.
    [self.queueFile add:dataForString(@"foo")];

    // Create a dirty commit file.
    [[NSFileManager defaultManager] createFileAtPath:[NSString stringWithFormat:@"%@.commit", _filePath] contents:dataForString(@"bar") attributes:nil];

    // Re-initialize the file.
    self.queueFile = [QueueFile queueFileWithPath:self.filePath];

    // Verify that there are no entries in the file.
    XCTAssertEqual([[self queueFile] size], 0);
}

- (void)testForEach
{
    NSData *foo = dataForString(@"foo");
    NSData *bar = dataForString(@"bar");
    NSData *baz = dataForString(@"baz");
    [self.queueFile add:foo];
    [self.queueFile add:bar];
    [self.queueFile add:baz];

    __block int invoked = 0;
    int visited = [self.queueFile forEach:^(NSData *data) {
      if (invoked == 0) {
          XCTAssertDataEqual(foo, data);
      } else if (invoked == 1) {
          XCTAssertDataEqual(bar, data);
      } else if (invoked == 2) {
          XCTAssertDataEqual(baz, data);
      } else {
          XCTFail("Reader invoked with more elements than available.");
      }
      invoked++;
      return YES;
    }];

    XCTAssertEqual(invoked, 3);
    XCTAssertEqual(visited, 3);
}

@end
