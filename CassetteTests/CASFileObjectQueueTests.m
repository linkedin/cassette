//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and limitations under the License.

#import <XCTest/XCTest.h>

#import "CASFileObjectQueue.h"

@interface CASFileObjectQueueTests : XCTestCase

@property (nonatomic, nonnull, strong) CASFileObjectQueue<NSNumber *> *queue;

@end

@implementation CASFileObjectQueueTests

#pragma mark - constants

- (NSString *)defaultWritePath {
    return [NSTemporaryDirectory() stringByAppendingPathComponent:@"testing/"];
}

#pragma mark - setup

- (void)setUp {
    NSError *error;
    NSString *testFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"testfile"];

    [[NSFileManager defaultManager] removeItemAtPath:[self defaultWritePath] error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:testFilePath error:nil];

    CASFileObjectQueue<NSNumber *> *queue = [[CASFileObjectQueue alloc] initWithAbsolutePath:testFilePath
                                                                                       error:&error];
    XCTAssertNil(error, @"error during setup: %@", error.localizedDescription);
    self.queue = queue;
}

- (void)tearDown {
    XCTAssertTrue([self.queue clearAndReturnError:NULL]);
}

#pragma mark - tests

- (void)testVariousRelativePaths {
    NSString *basePath = @"testing";
    NSArray<NSString *> *directoryPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSArray <NSString *> *filePaths = @[
                                       @"test",
                                       @"test.tmp",
                                       @"testfile/testfile.tmp",
                                       @"otherplace/test/testfile.tmp"
                                       ];

    for (NSString *path in filePaths) {

        NSError *error = nil;
        NSString *baseLibPath = [directoryPaths[0] stringByAppendingPathComponent:basePath];
        NSString *relativePath = [basePath stringByAppendingPathComponent:path];
        NSString *fullPath = [baseLibPath stringByAppendingPathComponent:path];

        [[NSFileManager defaultManager] removeItemAtPath:directoryPaths[0]
                                                   error:nil];

        [[NSFileManager defaultManager] createDirectoryAtPath:[fullPath stringByDeletingLastPathComponent]
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];

        CASFileObjectQueue<NSNumber *> *queue = [[CASFileObjectQueue alloc] initWithRelativePath:relativePath
                                                                                           error:&error];
        XCTAssertNil(error, @"error creating queue at path: %@\n error: %@",
                     fullPath,
                     error.localizedDescription);

        XCTAssertTrue([queue add:@(1) error:NULL]);
    }
}

- (void)testVariousAbsolutePath {

    NSString *basePath = [self defaultWritePath];

    NSArray <NSString *> *filePaths = @[@"",
                                        @"test",
                                        @"test.tmp",
                                        @"testfile/testfile.tmp",
                                        @"otherplace/test/testfile.tmp"
                                        ];

    for (NSString *path in filePaths) {

        NSError *error = nil;
        NSString *fullPath = [basePath stringByAppendingPathComponent:path];

        [[NSFileManager defaultManager] removeItemAtPath:basePath
                                                   error:nil];

        [[NSFileManager defaultManager] createDirectoryAtPath:[fullPath stringByDeletingLastPathComponent]
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];

        CASFileObjectQueue<NSNumber *> *queue = [[CASFileObjectQueue alloc] initWithAbsolutePath:fullPath
                                                                                           error:&error];
        XCTAssertNil(error, @"error creating queue at path: %@\n error: %@",
                     fullPath,
                     error.localizedDescription);

        XCTAssertTrue([queue add:@(1) error:NULL]);
    }
}

- (void)testSizeReflectsObjectsAdded {
    XCTAssertEqual(self.queue.size, 0);

    for (NSUInteger i = 0; i < 10; i++) {
        XCTAssertTrue([self.queue add:@1 error:NULL]);
    }

    XCTAssertEqual(self.queue.size, 10);
}

- (void)testSizeReflectsObjectsRemoved {
    XCTAssertEqual(self.queue.size, 0);

    for (int i = 0; i < 10; i++) {
        XCTAssertTrue([self.queue add:@1 error:NULL]);
    }

    for (int i = 9; i >= 0; i--) {
        XCTAssertTrue([self.queue pop:1 error:NULL]);
        XCTAssertEqual(self.queue.size, (NSUInteger) i);
    }
}

- (void)testCorrectElementIsRemovedWhenPopped {
    for (int i = 0; i < 3; i++) {
        XCTAssertTrue([self.queue add:[NSNumber numberWithInt:i] error:NULL]);
    }

    XCTAssertTrue([self.queue pop:1 error:NULL]);

    NSArray<NSNumber *> *remainingElements = [self.queue peek:self.queue.size error:NULL];
    NSArray<NSNumber *> *expected = @[@1, @2];
    XCTAssertEqualObjects(remainingElements, expected);
}

- (void)testRemoveDoesNothingWhenQueueIsEmpty {
    XCTAssertTrue(self.queue.isEmpty);
    XCTAssertTrue([self.queue pop:INT_MAX error:NULL]);
    XCTAssertTrue(self.queue.isEmpty);
}

- (void)testIsEmptyReturnsTrueWhenSizeIsZero {
    XCTAssertEqual(self.queue.size, 0);
    XCTAssertTrue(self.queue.isEmpty);
}

- (void)testPeekReturnsEmptyArrayWhenQueueIsEmpty {
    XCTAssertTrue(self.queue.isEmpty);
    XCTAssertEqualObjects([self.queue peek:1 error:NULL], @[]);
}

- (void)testPeekReflectsObjectsAdded {
    NSUInteger amount = 10;
    NSNumber *expectedValue = @1;
    for (NSUInteger i = 0; i < amount; i++) {
        XCTAssertTrue([self.queue add:expectedValue error:NULL]);
    }

    NSArray<NSNumber *> *result = [self.queue peek:amount error:NULL];
    for (NSUInteger i = 0; i < amount; i++) {
        XCTAssertEqualObjects(result[i], expectedValue);
    }
}

- (void)testPeekingGreaterThanSizeCapsToSize {
    XCTAssertTrue([self.queue add:@1 error:NULL]);
    NSArray<id> *result = [self.queue peek:INT_MAX error:NULL];
    XCTAssertEqual(result.count, 1);
}

- (void)testClearRemovesAllObjects {
    XCTAssertEqual(self.queue.size, 0);
    for (NSUInteger i = 0; i < 1000; i++) {
        XCTAssertTrue([self.queue add:@1 error:NULL]);
    }

    XCTAssertTrue([self.queue clearAndReturnError:NULL]);

    XCTAssertEqualObjects([self.queue peek:1 error:NULL], @[]);
    XCTAssertEqual(self.queue.size, 0);
}

@end
