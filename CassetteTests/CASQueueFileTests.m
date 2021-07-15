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

#import "CASQueueFile.h"

@interface CASQueueFileTests : XCTestCase

@property (nonatomic, copy) NSString *queueFileName;
@property (nonatomic, nullable, strong) CASQueueFile *queueFile;

@end

@implementation CASQueueFileTests

- (void)setUp {
    // Use a unique filename for each test.
    self.queueFileName = [NSString stringWithFormat:@"%@/CASQueueFileTests-storage-%@", NSTemporaryDirectory(), [NSUUID UUID].UUIDString];
    self.queueFile = [self openQueueFile];
}

- (CASQueueFile *)openQueueFile {
    NSError *error;
    CASQueueFile *queueFile = [CASQueueFile queueFileWithPath:self.queueFileName
                                                              error:&error];
    if (error != nil) {
        XCTFail(@"CASQueueFile could not be initialized. error: %@", error);
    }
    return queueFile;
}

- (void)tearDown {
    if (self.queueFile != nil) {
        XCTAssertTrue([self.queueFile clearAndReturnError:NULL]);
        XCTAssertTrue([self.queueFile closeAndReturnError:NULL]);
        XCTAssertTrue([NSFileManager.defaultManager removeItemAtPath:self.queueFileName error:NULL]);
    }
}

- (void)testIsEmpty {
    XCTAssertEqual(self.queueFile.size, 0);
    XCTAssertTrue(self.queueFile.isEmpty);
}

- (void)testItemsAddedAreReadBackCorrectly {
    XCTAssertEqual(self.queueFile.size, 0);
    // Add more than 10 items to make sure items of different sizes work.
    NSUInteger expected = 23;

    NSMutableArray<NSData *> *elements = [NSMutableArray array];
    for (NSUInteger i = 0; i < expected; i++) {
        NSData *data = [[NSString stringWithFormat:@"%zu", i] dataUsingEncoding:NSUTF8StringEncoding];
        XCTAssertTrue([self.queueFile add:data error:NULL]);
        [elements addObject:data];
    }

    // Close and re-open the queue file to make sure its contents are read back correctly.
    XCTAssertTrue([self.queueFile closeAndReturnError:NULL]);
    self.queueFile = [self openQueueFile];

    NSArray<NSData *> *peekedElements = [self.queueFile peek:expected error:NULL];
    XCTAssertEqualObjects(peekedElements, elements);
}

- (void)testSizeReflectsItemsAdded {
    XCTAssertEqual(self.queueFile.size, 0);
    NSData *data = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
    NSUInteger expected = 10;

    for (NSUInteger i = 0; i < expected; i++) {
        XCTAssertTrue([self.queueFile add:data error:NULL]);
    }

    XCTAssertEqual(self.queueFile.size, expected);
}

- (void)testPeekReflectsItemsAdded {
    NSString *expectedFormat = [NSString stringWithFormat:@"test @d"];
    NSUInteger numElements = 10;

    // Store the data
    for (NSUInteger i = 0; i < numElements; i++) {
        NSString *stringToStore = [NSString stringWithFormat:expectedFormat, i];
        NSData *data = [stringToStore dataUsingEncoding:NSUTF8StringEncoding];
        XCTAssertTrue([self.queueFile add:data error:NULL]);
    }

    // Verify the data
    NSArray<NSData *> *elements = [self.queueFile peek:numElements error:NULL];
    XCTAssertEqual(elements.count, numElements);
    for (NSUInteger i = 0; i < numElements; i++) {
        NSData *data = elements[i];
        NSString *coercedData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSString *expectedString = [NSString stringWithFormat:expectedFormat, i];
        XCTAssertEqualObjects(coercedData, expectedString);
    }
}

- (void)testRepeatedPeeksAreConsistent {
    NSData *data = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertTrue([self.queueFile add:data error:NULL]);

    NSArray<NSData *> *array1 = [self.queueFile peek:1 error:NULL];
    NSArray<NSData *> *array2 = [self.queueFile peek:1 error:NULL];

    XCTAssertEqualObjects(array1, array2);
}

- (void)testPeekDoesNotChangeSizeState {
    NSData *data = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertTrue([self.queueFile add:data error:NULL]);

    XCTAssertEqual(self.queueFile.size, 1);
    __unused NSArray<NSData *> *array1 = [self.queueFile peek:1 error:NULL];
    XCTAssertEqual(self.queueFile.size, 1);
}

- (void)testPeekingGreaterThanSizeIsSafe {
    NSArray *result = [self.queueFile peek:INT_MAX error:NULL];
    XCTAssertEqual(result.count, 0);
}

- (void)testPopDoesNothingWhenQueueIsEmpty {
    XCTAssertEqual(self.queueFile.size, 0);
    XCTAssertTrue([self.queueFile pop:INT_MAX error:NULL]);
    XCTAssertEqual(self.queueFile.size, 0);
}

- (void)testSizeReflectsItemsRemoved {
    NSData *data = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
    NSUInteger numElements = 10;
    for (NSUInteger i = 0; i < numElements; i++) {
        XCTAssertTrue([self.queueFile add:data error:NULL]);
    }
    XCTAssertEqual(self.queueFile.size, numElements);

    XCTAssertTrue([self.queueFile pop:5 error:NULL]);

    NSUInteger expected = numElements = 5;
    XCTAssertEqual(self.queueFile.size, expected);
}

- (void)testPopReflectsItemsRemoved {
    NSUInteger numElements = 10;
    for (NSUInteger i = 0; i < numElements; i++) {
        NSData *data = [NSData dataWithBytes:&i length:sizeof(i)];
        XCTAssertTrue([self.queueFile add:data error:NULL]);
    }

    // Remove half the queue, to test whether the correct half was removed
    NSUInteger amountToRemove = 5;
    XCTAssertTrue([self.queueFile pop:amountToRemove error:NULL]);

    // Verify the data
    NSUInteger expectedAmountRemaining = numElements - amountToRemove;
    XCTAssertEqual(self.queueFile.size, expectedAmountRemaining);

    NSArray<NSData *> *elements = [self.queueFile peek:expectedAmountRemaining error:NULL];
    XCTAssertEqual(elements.count, expectedAmountRemaining);
    for (NSUInteger i = 0; i < elements.count; i++) {
        NSUInteger coercedData;
        [elements[i] getBytes:&coercedData length:sizeof(coercedData)];
        XCTAssertEqual(coercedData - amountToRemove, i);
    }
}

- (void)testAddingReallyLargeElements {
    NSData *data = [NSMutableData dataWithLength:4096];
    NSUInteger numElements = 10;
    for (NSUInteger i = 0; i < numElements; i++) {
        XCTAssertTrue([self.queueFile add:data error:NULL]);
    }
    XCTAssertEqual(self.queueFile.size, numElements);
}

- (void)testAddingAndRemovingElementsWhileFragmentedAndFull {
    NSUInteger numElementsToStartWith = 10;
    NSUInteger numElementsToRemove = numElementsToStartWith / 2;
    [self triggerStressedFragmentation:numElementsToStartWith
                                                   numElementsToRemove:numElementsToRemove];
    NSUInteger originalSize = self.queueFile.size;

    NSUInteger numElements = 10;
    for (NSUInteger i = 0; i < numElements; i++) {
        NSData *data = [NSData dataWithBytes:&i length:sizeof(i)];
        XCTAssertTrue([self.queueFile add:data error:NULL]);
    }

    XCTAssertEqual(self.queueFile.size, originalSize + numElements);

    XCTAssertTrue([self.queueFile pop:numElements error:NULL]);
    XCTAssertEqual(self.queueFile.size, numElements);

    NSArray<NSData *> *elements = [self.queueFile peek:numElements error:NULL];
    XCTAssertEqual(elements.count, numElements);
    for (NSUInteger i = 0; i < elements.count; i++) {
        NSUInteger coercedData;
        [elements[i] getBytes:&coercedData length:sizeof(coercedData)];
        XCTAssertEqual(coercedData, i);
    }
}

- (void)testRingReadingElementsMaintainsCorrectness {
    NSUInteger numElementsToStartWith = 10;
    NSUInteger numElementsToRemove = numElementsToStartWith / 2;
    NSArray<NSData *> * dataArray = [self triggerStressedFragmentation:numElementsToStartWith
                                                   numElementsToRemove:numElementsToRemove];
    NSArray<NSData *> *elements = [self.queueFile peek:self.queueFile.size error:NULL];
    XCTAssertEqual(elements.count, self.queueFile.size);
    for (NSUInteger i = 0; i < elements.count; i++) {
        XCTAssertEqualObjects(elements[(i + numElementsToRemove) % numElementsToStartWith],
                              dataArray[i]);
    }
}

- (NSMutableArray<NSData *> *)triggerStressedFragmentation:(NSUInteger)numElementsToStartWith
                                       numElementsToRemove:(NSUInteger)numElementsToRemove {
    // Add just enough elements that it almost fills the storage
    // 4096 - 16 = 4080
    // Assumption: initial file size is 4096 - headerlength(16) = 4080
    // Assumption: element header length = 4
    NSUInteger initialFileLength = 4080;
    NSUInteger elementHeaderLength = 4;
    NSUInteger sizeOfEachElement = (initialFileLength / numElementsToStartWith) - elementHeaderLength;
    NSMutableArray<NSData *> *dataArray = [[NSMutableArray alloc] initWithCapacity:numElementsToStartWith];

    // Add unique elements of data
    for (NSUInteger i = 0; i < numElementsToStartWith; i++) {
        NSMutableData* data = [NSMutableData dataWithCapacity:sizeOfEachElement];
        for (NSUInteger j = 0; j < sizeOfEachElement; j++) {
            [data appendBytes:&i length:1];
        }
        XCTAssertTrue([self.queueFile add:data error:NULL]);
        [dataArray addObject:data];
    }

    // At this point, buffer should be completely full.
    // To trigger fragmentation, let's pop a few elements and add them back in.
    // This will mean the head is now somewhere in the middle of the file, as well as the tail.
    XCTAssertTrue([self.queueFile pop:numElementsToRemove error:NULL]);
    for (NSUInteger i = 0; i < numElementsToRemove; i++) {
        XCTAssertTrue([self.queueFile add:dataArray[i] error:NULL]);
    }

    return dataArray;
}

@end
