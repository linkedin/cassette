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
    [self.queue clear];
}

#pragma mark - tests

- (void)testQueueCreationRelativePath {
    NSString *relPath = @"testing";
    NSArray<NSString *> *directoryPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);

    [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@",directoryPaths[0], relPath]
                                               error:nil];
    NSError *error;
    CASFileObjectQueue<NSNumber *> *queue;
    NSString *path;

    error = nil;
    path = relPath;
    queue = [[CASFileObjectQueue alloc] initWithRelativePath:path error:&error];
    XCTAssertNil(error, @"error creating queue at path: %@\n error: %@", path, error.localizedDescription);
    [queue add:@(1)];

    [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@",directoryPaths[0], relPath]
                                               error:nil];

    error = nil;
    path = [relPath stringByAppendingPathComponent:@"otherplace/test"];
    queue = [[CASFileObjectQueue alloc] initWithRelativePath:path error:&error];
    XCTAssertNil(error, @"error creating queue at path: %@\n error: %@", path, error.localizedDescription);
    [queue add:@(1)];

    [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@",directoryPaths[0], relPath]
                                               error:nil];

    error = nil;
    path = [relPath stringByAppendingPathComponent:@"testfile/testfile.tmp"];
    queue = [[CASFileObjectQueue alloc] initWithRelativePath:path error:&error];
    XCTAssertNil(error, @"error creating queue at path: %@\n error: %@", path, error.localizedDescription);
    [queue add:@(1)];

    [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@",directoryPaths[0], relPath]
                                               error:nil];

    error = nil;
    path = [relPath stringByAppendingPathComponent:@"otherplace/test/testfile.tmp"];
    queue = [[CASFileObjectQueue alloc] initWithRelativePath:path error:&error];
    XCTAssertNil(error, @"error creating queue at path: %@\n error: %@", path, error.localizedDescription);
    [queue add:@(1)];
}

- (void)testQueueCreationAbsolutePath {
    NSError *error;
    CASFileObjectQueue<NSNumber *> *queue;
    NSString *path;

    [[NSFileManager defaultManager] removeItemAtPath:[self defaultWritePath]
                                               error:nil];

    error = nil;
    path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"testing/"];
    queue = [[CASFileObjectQueue alloc] initWithAbsolutePath:path error:&error];
    XCTAssertNil(error, @"error creating queue at path: %@\n error: %@", path, error.localizedDescription);
    [queue add:@(1)];

    [[NSFileManager defaultManager] removeItemAtPath:[self defaultWritePath]
                                               error:nil];

    error = nil;
    path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"testing/otherplace/test"];
    queue = [[CASFileObjectQueue alloc] initWithAbsolutePath:path error:&error];
    XCTAssertNil(error, @"error creating queue at path: %@\n error: %@", path, error.localizedDescription);
    [queue add:@(1)];

    [[NSFileManager defaultManager] removeItemAtPath:[self defaultWritePath]
                                               error:nil];

    error = nil;
    path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"testing/testfile/testfile.tmp"];
    queue = [[CASFileObjectQueue alloc] initWithAbsolutePath:path error:&error];
    XCTAssertNil(error, @"error creating queue at path: %@\n error: %@", path, error.localizedDescription);
    [queue add:@(1)];

    [[NSFileManager defaultManager] removeItemAtPath:[self defaultWritePath]
                                               error:nil];
    
    error = nil;
    path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"testing/otherplace/test/testfile.tmp"];
    queue = [[CASFileObjectQueue alloc] initWithAbsolutePath:path error:&error];
    XCTAssertNil(error, @"error creating queue at path: %@\n error: %@", path, error.localizedDescription);
    [queue add:@(1)];
}

- (void)testSizeReflectsObjectsAdded {
    XCTAssertEqual(self.queue.size, 0);

    for (NSUInteger i = 0; i < 10; i++) {
        [self.queue add:@1];
    }

    XCTAssertEqual(self.queue.size, 10);
}

- (void)testSizeReflectsObjectsRemoved {
    XCTAssertEqual(self.queue.size, 0);

    for (int i = 0; i < 10; i++) {
        [self.queue add:@1];
    }

    for (int i = 9; i >= 0; i--) {
        [self.queue pop];
        XCTAssertEqual(self.queue.size, (NSUInteger) i);
    }
}

- (void)testCorrectElementIsRemovedWhenPopped {
    for (int i = 0; i < 3; i++) {
        [self.queue add:[NSNumber numberWithInt:i]];
    }

    [self.queue pop];

    NSArray<NSNumber *> *remainingElements = [self.queue peek:self.queue.size];
    NSArray<NSNumber *> *expected = @[@1, @2];
    XCTAssertEqualObjects(remainingElements, expected);
}

- (void)testRemoveDoesNothingWhenQueueIsEmpty {
    XCTAssertTrue(self.queue.isEmpty);
    [self.queue pop:INT_MAX];
    XCTAssertTrue(self.queue.isEmpty);
}

- (void)testIsEmptyReturnsTrueWhenSizeIsZero {
    XCTAssertEqual(self.queue.size, 0);
    XCTAssertTrue(self.queue.isEmpty);
}

- (void)testPeekReturnsEmptyArrayWhenQueueIsEmpty {
    XCTAssertTrue(self.queue.isEmpty);
    XCTAssertNil([self.queue peek]);
}

- (void)testPeekReflectsObjectsAdded {
    NSUInteger amount = 10;
    NSNumber *expectedValue = @1;
    for (NSUInteger i = 0; i < amount; i++) {
        [self.queue add:expectedValue];
    }

    NSArray<NSNumber *> *result = [self.queue peek:amount];
    for (NSUInteger i = 0; i < amount; i++) {
        XCTAssertEqualObjects(result[i], expectedValue);
    }
}

- (void)testPeekingGreaterThanSizeCapsToSize {
    [self.queue add:@1];
    NSArray<id> *result = [self.queue peek:INT_MAX];
    XCTAssertEqual(result.count, 1);
}

- (void)testClearRemovesAllObjects {
    XCTAssertEqual(self.queue.size, 0);
    for (NSUInteger i = 0; i < 1000; i++) {
        [self.queue add:@1];
    }

    [self.queue clear];

    XCTAssertNil([self.queue peek]);
    XCTAssertEqual(self.queue.size, 0);
}

@end
