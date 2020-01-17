//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and limitations under the License.

#import "CASQueueFile.h"

#import "CASPrivateConstants.h"
#import "CASQueueFileElement.h"
#import "CASError.h"

/**
 * Initial file size in bytes.
 */
static NSUInteger const QueueFileInitialLength = 4096;

/**
 * Length of header in bytes.
 */
static NSUInteger const QueueFileHeaderLength = 16;

/**
 * Length of element header in bytes.
 */
static NSUInteger const ElementHeaderLength = 4;


@interface CASQueueFile ()

@property (nonatomic, strong, readwrite) NSFileHandle *fileHandle;
@property (nonatomic, strong, readwrite) NSString *commitFilePath;
@property (nonatomic, strong, readwrite) NSFileManager *fileManager;

/**
 * In-memory buffer. This must be big enough to hold the header.
 */
@property (nonatomic, readwrite) NSMutableData *buffer;

/**
 * Cached file length. Always a power of 2.
 */
@property (nonatomic, readwrite) NSUInteger fileLength;

/**
 * The number of elements added.
 */
@property (nonatomic, readwrite) NSUInteger elementCount;

/**
 * Pointer to first element, at the front of the queue.
 */
@property (nonatomic, readwrite) CASQueueFileElement *first;

/**
 * Pointer to last element, at the end of the queue.
 */
@property (nonatomic, readwrite) CASQueueFileElement *last;

@end

// TODO several NSFileHandle API methods are deprecated in iOS 13. Will change once those APIs are stable.
@implementation CASQueueFile

#pragma mark - Initialization

+ (nullable CASQueueFile *)queueFileWithPath:(NSString *)path error:(NSError * __autoreleasing * _Nullable)error {
    NSString *commitFilePath = commitFilePathForFile(path);
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *tapeError;

    // There was an unfinished commit, clear and reinitialize.
    if ([fileManager fileExistsAtPath:commitFilePath]) {
        if (![fileManager removeItemAtPath:path error:&tapeError]) {
            CASLOG(@"Could not remove file at path: %@.", commitFilePath);
            if ([CASError handleError:tapeError error:error]) {
                return nil;
            }
        }
        if (![fileManager removeItemAtPath:commitFilePath error:&tapeError]) {
            CASLOG(@"Could not remove commit file at path: %@.", commitFilePath);
            if ([CASError handleError:tapeError error:error]) {
                return nil;
            }
        }
        [self safelySetUpFile:path forManager:fileManager error:&tapeError];
    } else if (![fileManager fileExistsAtPath:path]) {
        // There was no existing file, initialize one.
        [self safelySetUpFile:path forManager:fileManager error:&tapeError];
    }

    if ([CASError handleError:tapeError error:error]) {
        return nil;
    }

    return [[self alloc] initWithPath:path forManager:fileManager];
}

/**
 * Atomically initializes a new LITapeQueueFile at the given path.
 */
+ (void)safelySetUpFile:(NSString *)path forManager:(NSFileManager *)fileManager error:(NSError * __autoreleasing * _Nullable)error {
    NSError *tapeError;

    // Use a temporary file so we don't leave a partially-initialized file.
    NSString *tempPath = [path stringByAppendingPathExtension:@"tmp"];

    // Write the initial set of data for the file
    NSMutableData *fileBuffer = [NSMutableData dataWithLength:QueueFileInitialLength];
    writeInt(fileBuffer, 0, QueueFileInitialLength);

    BOOL isDirectory = YES;

    NSString *folderPath = [path stringByDeletingLastPathComponent];

    BOOL doesFolderExistAlready = [fileManager fileExistsAtPath:folderPath
                                                    isDirectory:&isDirectory];

    if (!doesFolderExistAlready) {
        tapeError = [CASError createError:CASErrorFileInitialization];
        CASLOG(@"Creation of intermediary directories is not supported, please create folder path: %@", folderPath);
        [CASError handleError:tapeError error:error];
        return;
    }

    if (!isDirectory) {
        tapeError = [CASError createError:CASErrorFileInitialization];
        CASLOG(@"Could not create file because base directory is a file!: %@", folderPath);
        [CASError handleError:tapeError error:error];
        return;
    }

    if (![fileManager createFileAtPath:tempPath
                              contents:fileBuffer
                            attributes:nil]) {
        tapeError = [CASError createError:CASErrorFileInitialization];
        CASLOG(@"%@", [NSString stringWithFormat:@"Could not initialize file at path: %@.", tempPath]);
        [CASError handleError:tapeError error:error];
        return;
    }

    if (![fileManager moveItemAtPath:tempPath
                              toPath:path
                               error:error]) {
        CASLOG(@"Could not move file from %@ to %@.", path, tempPath);
        [CASError handleError:tapeError error:error];
        return;
    }
}

- (instancetype)initWithPath:(NSString *)filePath
                  forManager:(NSFileManager *)fileManager {
    if (self = [super init]) {
        _commitFilePath = commitFilePathForFile(filePath);
        _fileManager = fileManager;
        _fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:filePath];
        _buffer = [NSMutableData dataWithLength:QueueFileHeaderLength];

        // Now that our main properties are set up, let's set up some fast access variables.
        [self parseHeaderForFastAccessVariables];
    }
    return self;
}

/**
 * Read the data stored in the header into instance variables.
 */
- (void)parseHeaderForFastAccessVariables {
    [self.fileHandle seekToFileOffset:0];
    NSData *buffer = [self.fileHandle readDataOfLength:QueueFileHeaderLength];

    self.fileLength = readUnsignedInt(buffer, 0);
    self.elementCount = readUnsignedInt(buffer, 4);
    NSUInteger firstObjectOffset = readUnsignedInt(buffer, 8);
    NSUInteger lastObjectOffset = readUnsignedInt(buffer, 12);

    self.first = [self readElement:firstObjectOffset];
    self.last = [self readElement:lastObjectOffset];
}

#pragma mark - Public API

- (void)add:(NSData *)data {
    [self expandIfNecessary:data.length];

    // Insert a new element after the current last element.
    BOOL wasEmpty = self.isEmpty;
    NSUInteger position = wasEmpty ? QueueFileHeaderLength : [self wrapPosition:self.last.position + self.last.length + ElementHeaderLength];
    CASQueueFileElement *newLastElement = [[CASQueueFileElement alloc] initAtPosition:position withLength:data.length];

    // Write element length.
    writeInt(self.buffer, 0, (uint32_t) data.length);
    [self ringWriteAtPosition:newLastElement.position buffer:self.buffer];

    // Write element's data.
    [self ringWriteAtPosition:newLastElement.position + ElementHeaderLength buffer:data];

    // Commit the addition. If wasEmpty, first == last.
    NSUInteger firstPosition = wasEmpty ? newLastElement.position : self.first.position;
    [self writeHeader:_fileLength
         elementCount:_elementCount + 1
        firstPosition:firstPosition
         lastPosition:newLastElement.position];
    self.last = newLastElement;
    self.elementCount++;

    // Handle edge case where this is the first element added
    if (wasEmpty) {
        self.first = self.last;
    }
}

- (NSUInteger)size {
    return self.elementCount;
}

- (BOOL)isEmpty {
    return self.size == 0;
}

- (NSArray<NSData *> *)peek:(NSUInteger)amount {
    // Clamp number of elements we read down to the size in case @c amount is larger
    amount = MIN(amount, self.elementCount);
    NSUInteger position = self.first.position;
    NSMutableArray<NSData *> *elements = [[NSMutableArray alloc] init];

    for (NSUInteger i = 0; i < amount; i++) {
        // Read element from storage
        CASQueueFileElement *current = [self readElement:position];
        NSData *data = [self ringReadAtPosition:current.position + ElementHeaderLength count:current.length];

        // cache the result
        [elements addObject:data];

        // Move pointer to the next element
        position = [self wrapPosition:current.position + ElementHeaderLength + current.length];
    }

    return elements;
}

- (void)pop:(NSUInteger)amount {
    // Base case: Nothing to do if we have no elements
    if (self.isEmpty || amount == 0) {
        return;
    }

    // Optimize for clear call when possible since it is less expensive
    if (amount >= self.elementCount) {
        [self clear];
        return;
    }

    NSUInteger eraseStartPosition = self.first.position;
    NSUInteger totalLengthToErase = 0;

    // Seek to the new "head", while recording how much data we need to erase.
    NSUInteger newFirstPosition = self.first.position;
    NSUInteger newFirstLength = self.first.length;
    for (NSUInteger i = 0; i < amount; i++) {
        totalLengthToErase += ElementHeaderLength + newFirstLength;
        newFirstPosition = [self wrapPosition:newFirstPosition + ElementHeaderLength + newFirstLength];
        NSData *buffer = [self ringReadAtPosition:newFirstPosition count:ElementHeaderLength];
        newFirstLength = readUnsignedInt(buffer, 0);
    }

    // Commit the header and reassign pertinent in-memory variables
    [self writeHeader:self.fileLength
         elementCount:self.elementCount - amount
        firstPosition:newFirstPosition
         lastPosition:self.last.position];
    self.elementCount -= amount;
    self.first = [[CASQueueFileElement alloc] initAtPosition:newFirstPosition withLength:newFirstLength];

    // Zero out the data where the elements were removed
    [self ringEraseAtPosition:eraseStartPosition length:totalLengthToErase];
}

- (void)clear {
    // Reset the header
    [self writeHeader:QueueFileInitialLength
         elementCount:0
        firstPosition:0
         lastPosition:0];

    // Zero out the data in our file storage
    NSData *buffer = [NSMutableData dataWithLength:QueueFileInitialLength - QueueFileHeaderLength];
    [self ringWriteAtPosition:QueueFileHeaderLength buffer:buffer];

    // Reset in-memory variables
    self.elementCount = 0;
    self.first = CASQueueFileElement.null;
    self.last = CASQueueFileElement.null;
    if (self.fileLength > QueueFileInitialLength) {
        [self setFile:self.fileHandle toLength:QueueFileInitialLength];
    }
    self.fileLength = QueueFileInitialLength;
}

#pragma mark - Private Helper Functions

/**
 * Reads the element stored at the given position in the file, wrapping around
 * if necessary.
 */
- (CASQueueFileElement *)readElement:(NSUInteger)position {
    if (position == 0) {
        return [CASQueueFileElement null];
    }
    NSData *buffer = [self ringReadAtPosition:position count:ElementHeaderLength];
    NSUInteger length = readUnsignedInt(buffer, 0);
    return [[CASQueueFileElement alloc] initAtPosition:(NSUInteger)position withLength:length];
}

/**
 * Reads @c count bytes from the given position in the file, wrapping
 * around if necessary.
 */
- (NSData *)ringReadAtPosition:(NSUInteger)position count:(NSUInteger)count {
    position = [self wrapPosition:position];

    // Handle the simple case where we don't wrap around
    if (position + count < self.fileLength) {
        [self.fileHandle seekToFileOffset:position];
        return [self.fileHandle readDataOfLength:count];
    }

    // The requested read overlaps the EOF, so we need to read through to the EOF, wrap around, and read the remaining bytes
    NSMutableData *buffer = [NSMutableData dataWithCapacity:count];
    NSUInteger numBytesBeforeEOF = self.fileLength - position;
    [self.fileHandle seekToFileOffset:position];
    [buffer appendData:[self.fileHandle readDataOfLength:numBytesBeforeEOF]];
    [self.fileHandle seekToFileOffset:QueueFileHeaderLength];
    [buffer appendData:[self.fileHandle readDataOfLength:count - numBytesBeforeEOF]];
    return buffer;
}

/**
 * Writes buffer to position in file. Automatically wraps write if position is past the end of the file
 * or if buffer overlaps it.
 */
- (void)ringWriteAtPosition:(NSUInteger)position buffer:(NSData *)buffer {
    position = [self wrapPosition:position];

    // Handle the simple case where we don't wrap around
    if (position + buffer.length <= self.fileLength) {
        [self.fileHandle seekToFileOffset:position];
        [self.fileHandle writeData:buffer];
    } else {
        // The write overlaps the EOF.
        // # of bytes to write before the EOF.
        NSUInteger numBytesBeforeEOF = _fileLength - position;
        [self.fileHandle seekToFileOffset:position];
        [self.fileHandle writeData:[buffer subdataWithRange:NSMakeRange(0, numBytesBeforeEOF)]];
        [self.fileHandle seekToFileOffset:QueueFileHeaderLength];
        [self.fileHandle writeData:[buffer subdataWithRange:NSMakeRange(0 + numBytesBeforeEOF, buffer.length - numBytesBeforeEOF)]];
    }

    // Flush in-memory changes to permanent storage
    [self.fileHandle synchronizeFile];
}

/**
 * Zeroes out the file starting at @c position until @c length.
 */
- (void)ringEraseAtPosition:(NSUInteger)position length:(NSUInteger)length {
    NSData *buffer = [NSMutableData dataWithLength:length];
    [self ringWriteAtPosition:position buffer:buffer];
}

/**
 * Writes header atomically. This only updates the state in the
 * file. Assumes segment writes are atomic in the underlying file
 * system.
 */
- (void)writeHeader:(NSUInteger)fileLength
       elementCount:(NSUInteger)elementCount
      firstPosition:(NSUInteger)firstPosition
       lastPosition:(NSUInteger)lastPosition
{
    // Write header attributes to in-memory buffer
    writeInt(self.buffer, 0, (uint32_t) fileLength);
    writeInt(self.buffer, 4, (uint32_t) elementCount);
    writeInt(self.buffer, 8, (uint32_t) firstPosition);
    writeInt(self.buffer, 12, (uint32_t) lastPosition);

    // Create temporary file to not lose the data
    if (![self.fileManager createFileAtPath:self.commitFilePath
                                   contents:self.buffer
                                 attributes:nil]) {
        CASLOG(@"Could not initialize commit file at path: %@.", self.commitFilePath);
    }

    // Write header to file
    [self.fileHandle seekToFileOffset:0];
    [self.fileHandle writeData:self.buffer];
    [self.fileHandle synchronizeFile];

    // Remove the temporary file since it's no longer necessary
    if (![self.fileManager removeItemAtPath:self.commitFilePath error:nil]) {
        CASLOG(@"Could not remove commit file at path: %@.", self.commitFilePath);
    }
}

/**
 * Wraps the position if it exceeds the end of the file.
 */
- (NSUInteger)wrapPosition:(NSUInteger)position {
    return position < self.fileLength ? position : (QueueFileHeaderLength + position - self.fileLength);
}

/**
 * If necessary, expands the file to accommodate an additional element of the
 * given length.
 */
- (void)expandIfNecessary:(NSUInteger)elementLength {
    NSUInteger numBytesRequested = ElementHeaderLength + elementLength;
    NSUInteger remainingBytes = [self remainingBytes];

    // The file has enough space to accomodate the new element. Return early
    if (remainingBytes >= numBytesRequested) {
        return;
    }

    // Resize the file to accomodate the new element.
    NSUInteger previousFileLength = self.fileLength;
    NSUInteger newFileLength;

    // Double the length until we can fit the new data.
    do {
        newFileLength = previousFileLength << 1;
        remainingBytes += previousFileLength;
        previousFileLength = newFileLength;
    } while (remainingBytes < numBytesRequested);

    // Actually expand the file
    [self setFile:self.fileHandle toLength:newFileLength];

    // Calculate the position of the tail end of the data in the ring buffer
    NSUInteger endOfLastElement = [self wrapPosition:self.last.position + ElementHeaderLength + self.last.length];

    if (endOfLastElement <= self.first.position) {
        // Hard luck. The data wrapped around to the head and is now fragmented due to file expansion.
        // Copy the tail data after the head data to fix and make contiguous.
        NSUInteger count = endOfLastElement - QueueFileHeaderLength;
        NSData *buffer = [self ringReadAtPosition:QueueFileHeaderLength count:count];
        [self.fileHandle seekToFileOffset:self.fileLength];
        [self.fileHandle writeData:buffer];
        [self ringEraseAtPosition:QueueFileHeaderLength length:count];
    }

    // Update the headers and in-memory variables
    if (self.last.position < self.first.position) {
        NSUInteger newLastPosition = self.fileLength + self.last.position - QueueFileHeaderLength;
        [self writeHeader:newFileLength
             elementCount:self.elementCount
            firstPosition:self.first.position
             lastPosition:newLastPosition];
        self.last = [[CASQueueFileElement alloc] initAtPosition:newLastPosition withLength:self.last.length];
    } else {
        [self writeHeader:newFileLength
             elementCount:self.elementCount
            firstPosition:self.first.position
             lastPosition:self.last.position];
    }
    self.fileLength = newFileLength;
}

/**
 * Truncates the specified file to the new length, and commits it to persisted storage.
 */
- (void)setFile:(NSFileHandle *)fileHandle toLength:(NSUInteger)newLength {
    [fileHandle truncateFileAtOffset:newLength];
    [fileHandle synchronizeFile];
}

- (NSUInteger)remainingBytes {
    return self.fileLength - [self usedBytes];
}

- (NSUInteger)usedBytes {
    if (self.elementCount == 0) {
        return QueueFileHeaderLength;
    }

    if (self.last.position >= self.first.position) {
        // Contiguous queue.
        NSUInteger allButLastOccupiedSpace = self.last.position - self.first.position;
        NSUInteger occupiedSpaceOfLastElement = ElementHeaderLength + self.last.length;
        return allButLastOccupiedSpace + occupiedSpaceOfLastElement + QueueFileHeaderLength;
    } else {
        // The queue wraps.
        NSUInteger headSpace = self.last.position + ElementHeaderLength + _last.length;
        NSUInteger tailSpace = self.fileLength - self.first.position;
        return headSpace + tailSpace;
    }
}

/**
 * Stores a 32-bit integer @c value in the @c buffer at the given @c offset.
 */
void writeInt(NSMutableData *buffer, NSUInteger offset, uint32_t value) {
    [buffer replaceBytesInRange:NSMakeRange(offset, 4) withBytes:&value];
}

/**
 * Reads a 32-bit integer value from the @c buffer at @c offset.
 */
NSUInteger readUnsignedInt(NSData *buffer, NSUInteger offset) {
    uint32_t value;
    [buffer getBytes:&value range:NSMakeRange(offset, 4)];
    return value;
}

NSString *commitFilePathForFile(NSString *file) {
    return [NSString stringWithFormat:@"%@.commit", file];
}

@end
