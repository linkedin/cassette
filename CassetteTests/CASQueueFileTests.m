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

@interface CASQueueFile (ExposeMethods)
void writeInt(NSMutableData *buffer, NSUInteger offset, uint32_t value);
NSUInteger readUnsignedInt(NSData *buffer, NSUInteger offset);
@end

@interface CASQueueFileTests : XCTestCase

@property (nonatomic, nullable, strong) CASQueueFile *queueFile;

@end

@implementation CASQueueFileTests

- (void)setUp {
    NSError *error;
    CASQueueFile *queueFile = [CASQueueFile queueFileWithPath:[NSString stringWithFormat:@"%@/CASQueueFileTests-storage", NSTemporaryDirectory()]
                                                              error:&error];
    if (error != nil) {
        XCTFail(@"CASQueueFile could not be initialized. error: %@", error);
    }
    self.queueFile = queueFile;
}

- (void)tearDown {
    if (self.queueFile != nil) {
        [self.queueFile clear];
    }
}

- (void)testIsEmpty {
    XCTAssertEqual(self.queueFile.size, 0);
    XCTAssertTrue(self.queueFile.isEmpty);
}

- (void)testSizeReflectsItemsAdded {
    XCTAssertEqual(self.queueFile.size, 0);
    NSData *data = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
    NSUInteger expected = 10;

    for (NSUInteger i = 0; i < expected; i++) {
        [self.queueFile add:data];
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
        [self.queueFile add:data];
    }

    // Verify the data
    NSArray<NSData *> *elements = [self.queueFile peek:numElements];
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
    [self.queueFile add:data];

    NSArray<NSData *> *array1 = [self.queueFile peek:1];
    NSArray<NSData *> *array2 = [self.queueFile peek:1];

    XCTAssertEqualObjects(array1, array2);
}

- (void)testPeekDoesNotChangeSizeState {
    NSData *data = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
    [self.queueFile add:data];

    XCTAssertEqual(self.queueFile.size, 1);
    __unused NSArray<NSData *> *array1 = [self.queueFile peek:1];
    XCTAssertEqual(self.queueFile.size, 1);
}

- (void)testPeekingGreaterThanSizeIsSafe {
    NSArray *result = [self.queueFile peek:INT_MAX];
    XCTAssertEqual(result.count, 0);
}

- (void)testPopDoesNothingWhenQueueIsEmpty {
    XCTAssertEqual(self.queueFile.size, 0);
    [self.queueFile pop:INT_MAX];
    XCTAssertEqual(self.queueFile.size, 0);
}

- (void)testSizeReflectsItemsRemoved {
    NSData *data = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
    NSUInteger numElements = 10;
    for (NSUInteger i = 0; i < numElements; i++) {
        [self.queueFile add:data];
    }
    XCTAssertEqual(self.queueFile.size, numElements);

    [self.queueFile pop:5];

    NSUInteger expected = numElements = 5;
    XCTAssertEqual(self.queueFile.size, expected);
}

- (void)testPopReflectsItemsRemoved {
    NSUInteger numElements = 10;
    for (NSUInteger i = 0; i < numElements; i++) {
        NSData *data = [NSData dataWithBytes:&i length:sizeof(i)];
        [self.queueFile add:data];
    }

    // Remove half the queue, to test whether the correct half was removed
    NSUInteger amountToRemove = 5;
    [self.queueFile pop:amountToRemove];

    // Verify the data
    NSUInteger expectedAmountRemaining = numElements - amountToRemove;
    XCTAssertEqual(self.queueFile.size, expectedAmountRemaining);

    NSArray<NSData *> *elements = [self.queueFile peek:expectedAmountRemaining];
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
        [self.queueFile add:data];
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
        [self.queueFile add:data];
    }

    XCTAssertEqual(self.queueFile.size, originalSize + numElements);

    [self.queueFile pop:numElements];
    XCTAssertEqual(self.queueFile.size, numElements);

    NSArray<NSData *> *elements = [self.queueFile peek:numElements];
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
    NSArray<NSData *> *elements = [self.queueFile peek:self.queueFile.size];
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
        [self.queueFile add:data];
        [dataArray addObject:data];
    }

    // At this point, buffer should be completely full.
    // To trigger fragmentation, let's pop a few elements and add them back in.
    // This will mean the head is now somewhere in the middle of the file, as well as the tail.
    [self.queueFile pop:numElementsToRemove];
    for (NSUInteger i = 0; i < numElementsToRemove; i++) {
        [self.queueFile add:dataArray[i]];
    }

    return dataArray;
}

- (void)testReadInt {
    NSUInteger value = readUnsignedInt([[NSData alloc] init], 12);
    XCTAssert(value == 0, "range outside of buffer should return 0 value");
    const unsigned char bytes[] = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
    NSData *validBuffer = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    value = readUnsignedInt(validBuffer, 12);
    XCTAssert(value == 269422093, "should be valid value in range");
}

- (void)testWriteInt {
    const unsigned char bytes[] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
    NSMutableData *buffer = [NSMutableData dataWithBytes:bytes length:sizeof(bytes)];
    NSUInteger value;
    value = readUnsignedInt([[NSMutableData alloc] init], 1);
    XCTAssert(value == 0, @"invalid value written and read.");
    value = readUnsignedInt(buffer, 1);
    XCTAssert(value == 0, @"invalid value written and read.");
    writeInt(buffer, 1, 84148994);
    value = readUnsignedInt(buffer, 1);
    XCTAssert(value == 84148994, @"invalid value written and read.");
}

@end
