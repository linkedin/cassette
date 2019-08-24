#import <XCTest/XCTest.h>

#import "CASQueueFile.h"

@interface CASQueueFileTests : XCTestCase

@property (nonatomic, nullable, strong) CASQueueFile *queueFile;

@end

@implementation CASQueueFileTests

- (void)setUp {
    NSError *error;
    CASQueueFile *queueFile = [CASQueueFile queueFileWithPath:[NSString stringWithFormat:@"%@/CASQueueFileTests-storage", NSTemporaryDirectory()]
                                                              error:&error];
    if (error != nil) {
        XCTFail(@"CASQueueFile could not be initialized.");
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
    [self triggerStressedFragmentation];
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

- (void)triggerStressedFragmentation {
    // Add just enough elements that it almost fills the storage
    // 4096 - 16 = 4080
    // Assumption: initial file size is 4096 - headerlength(16) = 4080
    // Assumption: element header length = 4
    NSUInteger initialFileLength = 4080;
    NSUInteger numElementsToStartWith = 10;
    NSUInteger elementHeaderLength = 4;
    NSUInteger sizeOfEachElement = initialFileLength / numElementsToStartWith;
    NSData *data = [NSMutableData dataWithLength:(sizeOfEachElement - elementHeaderLength)];
    for (NSUInteger i = 0; i < numElementsToStartWith; i++) {
        [self.queueFile add:data];
    }

    // At this point, buffer should be completely full.
    // To trigger fragmentation, let's pop a few elements and add them back in.
    // This will mean the head is now somewhere in the middle of the file, as well as the tail.
    NSUInteger numElementsToRemove = numElementsToStartWith / 2;
    [self.queueFile pop:numElementsToRemove];
    for (NSUInteger i = 0; i < numElementsToRemove; i++) {
        [self.queueFile add:data];
    }
}

@end
