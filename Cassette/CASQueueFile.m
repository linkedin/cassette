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

    NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingURL:[NSURL fileURLWithPath:path]
                                                                error:error];
    if (!fileHandle) {
        return nil;
    }
    NSData *buffer;

    if (![fileHandle seekToOffset:0 error:error]) {
      return nil;
    }
    buffer = [fileHandle readDataUpToLength:QueueFileHeaderLength error:error];
    if (!buffer) {
      return nil;
    }

    NSUInteger fileLength = readUnsignedInt(buffer, 0);
    NSUInteger elementCount = readUnsignedInt(buffer, 4);
    NSUInteger firstObjectOffset = readUnsignedInt(buffer, 8);
    NSUInteger lastObjectOffset = readUnsignedInt(buffer, 12);

    CASQueueFile *result = [[self alloc] initWithCommitFilePath:commitFilePath
                                                     forManager:fileManager
                                                     fileHandle:fileHandle
                                                     fileLength:fileLength
                                                   elementCount:elementCount];
    CASQueueFileElement *firstElement = [result readElement:firstObjectOffset error:error];
    if (!firstElement) {
        return nil;
    }
    CASQueueFileElement *lastElement = [result readElement:lastObjectOffset error:error];
    if (!lastElement) {
        return nil;
    }
    result.first = firstElement;
    result.last = lastElement;
    return result;
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

- (instancetype)initWithCommitFilePath:(NSString *)commitFilePath
                            forManager:(NSFileManager *)fileManager
                            fileHandle:(NSFileHandle *)fileHandle
                            fileLength:(NSUInteger)fileLength
                          elementCount:(NSUInteger)elementCount {
    if (self = [super init]) {
        _commitFilePath = [commitFilePath copy];
        _fileManager = fileManager;
        _fileHandle = fileHandle;
        _buffer = [NSMutableData dataWithLength:QueueFileHeaderLength];
        _fileLength = fileLength;
        _elementCount = elementCount;
    }
    return self;
}

#pragma mark - Public API

- (BOOL)closeAndReturnError:(NSError * __autoreleasing * _Nullable)error {
  return [self.fileHandle closeAndReturnError:error];
}

- (void)add:(NSData *)data {
    [self add:data error:NULL];
}

- (BOOL)add:(NSData *)data
      error:(NSError * __autoreleasing * _Nullable)error {
    return [self addElements:@[data] error:error];
}

- (BOOL)addElements:(NSArray<NSData *> *)elements error:(NSError * __autoreleasing * _Nullable)error {
    if (!elements.count) {
        return YES;
    }

    if (![self expandIfNecessary:elements error:error]) {
        return NO;
    }

    // Insert the new element(s) after the current last element.
    BOOL wasEmpty = self.isEmpty;
    NSUInteger position = wasEmpty ? QueueFileHeaderLength : [self wrapPosition:self.last.position + self.last.length + ElementHeaderLength];

    CASQueueFileElement *newFirstElement = nil;
    CASQueueFileElement *newLastElement = nil;

    for (NSData *data in elements) {
        newLastElement = [[CASQueueFileElement alloc] initAtPosition:position withLength:data.length];
        if (!newFirstElement) {
            newFirstElement = newLastElement;
        }
        // Write element length.
        writeInt(self.buffer, 0, (uint32_t) data.length);
        if (![self ringWriteAtPosition:newLastElement.position buffer:self.buffer synchronizeFile:NO error:error]) {
            return NO;
        }

        // Write element's data.
        if (![self ringWriteAtPosition:newLastElement.position + ElementHeaderLength buffer:data synchronizeFile:NO error:error]) {
            return NO;
        }
        position = [self wrapPosition:newLastElement.position + newLastElement.length + ElementHeaderLength];
    }

    // Commit the addition(s).
    NSUInteger firstPosition = wasEmpty ? newFirstElement.position : self.first.position;
    if (![self writeHeader:self.fileLength
              elementCount:self.elementCount + elements.count
             firstPosition:firstPosition
              lastPosition:newLastElement.position
           synchronizeFile:YES
                     error:error]) {
        return NO;
    }

    self.last = newLastElement;
    self.elementCount += elements.count;

    // Handle edge case where this is the first element added
    if (wasEmpty) {
        self.first = newFirstElement;
    }

    return YES;
}

- (NSUInteger)size {
    return self.elementCount;
}

- (BOOL)isEmpty {
    return self.size == 0;
}

- (NSArray<NSData *> *)peek:(NSUInteger)amount {
    return [self peek:amount error:NULL] ?: @[];
}

- (nullable NSArray<NSData *> *)peek:(NSUInteger)amount error:(NSError * __autoreleasing * _Nullable)error {
    // Clamp number of elements we read down to the size in case @c amount is larger
    amount = MIN(amount, self.elementCount);
    NSUInteger position = self.first.position;
    NSMutableArray<NSData *> *elements = [[NSMutableArray alloc] init];

    for (NSUInteger i = 0; i < amount; i++) {
        // Read element from storage
        CASQueueFileElement *current = [self readElement:position error:error];
        if (!current) {
            return nil;
        }
        NSData *data = [self ringReadAtPosition:current.position + ElementHeaderLength count:current.length error:error];
        if (!data) {
            return nil;
        }

        // cache the result
        [elements addObject:data];

        // Move pointer to the next element
        position = [self wrapPosition:current.position + ElementHeaderLength + current.length];
    }

    return elements;
}

- (void)pop:(NSUInteger)amount {
    [self pop:amount error:NULL];
}

- (BOOL)pop:(NSUInteger)amount error:(NSError * __autoreleasing * _Nullable)error {
    // Base case: Nothing to do if we have no elements
    if (self.isEmpty || amount == 0) {
        return YES;
    }

    // Optimize for clear call when possible since it is less expensive
    if (amount >= self.elementCount) {
        return [self clearAndReturnError:error];
    }

    NSUInteger eraseStartPosition = self.first.position;
    NSUInteger totalLengthToErase = 0;

    // Seek to the new "head", while recording how much data we need to erase.
    NSUInteger newFirstPosition = self.first.position;
    NSUInteger newFirstLength = self.first.length;
    for (NSUInteger i = 0; i < amount; i++) {
        totalLengthToErase += ElementHeaderLength + newFirstLength;
        newFirstPosition = [self wrapPosition:newFirstPosition + ElementHeaderLength + newFirstLength];
        NSData *buffer = [self ringReadAtPosition:newFirstPosition count:ElementHeaderLength error:error];
        if (!buffer) {
            return NO;
        }
        newFirstLength = readUnsignedInt(buffer, 0);
    }

    // Commit the header and reassign pertinent in-memory variables
    if (![self writeHeader:self.fileLength
              elementCount:self.elementCount - amount
             firstPosition:newFirstPosition
              lastPosition:self.last.position
           synchronizeFile:NO
                     error:error]) {
        return NO;
    }
    self.elementCount -= amount;
    self.first = [[CASQueueFileElement alloc] initAtPosition:newFirstPosition withLength:newFirstLength];

    // Zero out the data where the elements were removed
    return [self ringEraseAtPosition:eraseStartPosition length:totalLengthToErase synchronizeFile:YES error:error];
}

- (void)clear {
    [self clearAndReturnError:NULL];
}

- (BOOL)clearAndReturnError:(NSError * __autoreleasing * _Nullable)error {
    // Reset the header
    if (![self writeHeader:QueueFileInitialLength
              elementCount:0
             firstPosition:0
              lastPosition:0
           synchronizeFile:NO
                     error:error]) {
        return NO;
    }

    // Reset in-memory variables
    self.elementCount = 0;
    self.first = CASQueueFileElement.null;
    self.last = CASQueueFileElement.null;

   // Zero out the data in our file storage
    NSData *buffer = [NSMutableData dataWithLength:QueueFileInitialLength - QueueFileHeaderLength];
    if (![self ringWriteAtPosition:QueueFileHeaderLength buffer:buffer synchronizeFile:NO error:error]) {
        return NO;
    }

    if (self.fileLength > QueueFileInitialLength) {
        if (![self setFile:self.fileHandle toLength:QueueFileInitialLength synchronizeFile:YES error:error]) {
            return NO;
        }
    } else {
        if (![self synchronizeFile:self.fileHandle error:error]) {
            return NO;
        }
    }
    self.fileLength = QueueFileInitialLength;
    return YES;
}

#pragma mark - Private Helper Functions

/**
 * Reads the element stored at the given position in the file, wrapping around
 * if necessary.
 */
- (nullable CASQueueFileElement *)readElement:(NSUInteger)position
                                        error:(NSError * __autoreleasing * _Nullable)error {
    if (position == 0) {
        return [CASQueueFileElement null];
    }
    NSData *buffer = [self ringReadAtPosition:position count:ElementHeaderLength error:error];
    if (!buffer) {
        return nil;
    }
    NSUInteger length = readUnsignedInt(buffer, 0);
    return [[CASQueueFileElement alloc] initAtPosition:(NSUInteger)position withLength:length];
}

/**
 * Reads @c count bytes from the given position in the file, wrapping
 * around if necessary.
 */
- (nullable NSData *)ringReadAtPosition:(NSUInteger)position count:(NSUInteger)count error:(NSError * __autoreleasing * _Nullable)error {
    position = [self wrapPosition:position];

    // Handle the simple case where we don't wrap around
    if (position + count < self.fileLength) {
      if (![self.fileHandle seekToOffset:position error:error]) {
        return nil;
      }
      return [self.fileHandle readDataUpToLength:count error:error];
    }

    // The requested read overlaps the EOF, so we need to read through to the EOF, wrap around, and read the remaining bytes
    NSMutableData *buffer = [NSMutableData dataWithCapacity:count];
    NSUInteger numBytesBeforeEOF = self.fileLength - position;
    if (![self.fileHandle seekToOffset:position error:error]) {
      return nil;
    }
    NSData *dataUntilEOF = [self.fileHandle readDataUpToLength:numBytesBeforeEOF error:error];
    if (!dataUntilEOF) {
      return nil;
    }
    [buffer appendData:dataUntilEOF];
    if (![self.fileHandle seekToOffset:QueueFileHeaderLength error:error]) {
      return nil;
    }
    NSData *remainingData = [self.fileHandle readDataUpToLength:count - numBytesBeforeEOF
                                                          error:error];
    if (!remainingData) {
      return nil;
    }
    [buffer appendData:remainingData];
    return buffer;
}

/**
 * Writes buffer to position in file. Automatically wraps write if position is past the end of the file
 * or if buffer overlaps it.
 */
- (BOOL)ringWriteAtPosition:(NSUInteger)position
                     buffer:(NSData *)buffer
            synchronizeFile:(BOOL)synchronizeFile
                      error:(NSError * __autoreleasing * _Nullable)error {
    position = [self wrapPosition:position];

    // Handle the simple case where we don't wrap around
    if (position + buffer.length <= self.fileLength) {
      if (![self.fileHandle seekToOffset:position error:error]) {
        return NO;
      }
      if (![self.fileHandle writeData:buffer error:error]) {
        return NO;
      }
    } else {
        // The write overlaps the EOF.
        // # of bytes to write before the EOF.
        NSUInteger numBytesBeforeEOF = _fileLength - position;
        if (![self.fileHandle seekToOffset:position error:error]) {
          return NO;
        }
        if (![self.fileHandle writeData:[buffer subdataWithRange:NSMakeRange(0, numBytesBeforeEOF)]
                                  error:error]) {
          return NO;
        }
        if (![self.fileHandle seekToOffset:QueueFileHeaderLength error:error]) {
          return NO;
        }
        if (![self.fileHandle
                writeData:[buffer subdataWithRange:NSMakeRange(0 + numBytesBeforeEOF,
                                                               buffer.length - numBytesBeforeEOF)]
                    error:error]) {
          return NO;
        }
    }

    if (synchronizeFile) {
        [self synchronizeFile:self.fileHandle error:error];
    }

    return YES;
}

/**
 * Zeroes out the file starting at @c position until @c length.
 */
- (BOOL)ringEraseAtPosition:(NSUInteger)position
                     length:(NSUInteger)length
            synchronizeFile:(BOOL)synchronizeFile
                      error:(NSError * __autoreleasing * _Nullable)error {
    NSData *buffer = [NSMutableData dataWithLength:length];
    return [self ringWriteAtPosition:position buffer:buffer synchronizeFile:synchronizeFile error:error];
}

/**
 * Writes header atomically. This only updates the state in the
 * file. Assumes segment writes are atomic in the underlying file
 * system.
 */
- (BOOL)writeHeader:(NSUInteger)fileLength
       elementCount:(NSUInteger)elementCount
      firstPosition:(NSUInteger)firstPosition
       lastPosition:(NSUInteger)lastPosition
    synchronizeFile:(BOOL)synchronizeFile
              error:(NSError * __autoreleasing * _Nullable)error
{
    // Write header attributes to in-memory buffer
    writeInt(self.buffer, 0, (uint32_t) fileLength);
    writeInt(self.buffer, 4, (uint32_t) elementCount);
    writeInt(self.buffer, 8, (uint32_t) firstPosition);
    writeInt(self.buffer, 12, (uint32_t) lastPosition);

    // Create temporary file to not lose the data
    if (![self.buffer writeToFile:self.commitFilePath
                          options:NSDataWritingAtomic
                            error:error]) {
        if (error) {
            CASLOG(@"Could not initialize commit file at path: %@, error: %@", self.commitFilePath, *error);
        }
        return NO;
    }

    // Write header to file
    if (![self.fileHandle seekToOffset:0 error:error]) {
      if (error) {
        CASLOG(@"Could not seek to beginning of file, error: %@", *error);
      }
      return NO;
    }
    if (![self.fileHandle writeData:self.buffer error:error]) {
      if (error) {
        CASLOG(@"Could not write %zu bytes, error: %@", self.buffer.length, *error);
      }
      return NO;
    }

    if (synchronizeFile) {
        if (![self synchronizeFile:self.fileHandle error:error]) {
            return NO;
        }
    }

    // Remove the temporary file since it's no longer necessary
    NSError *removeError;
    if (![self.fileManager removeItemAtPath:self.commitFilePath error:&removeError]) {
        CASLOG(@"Could not remove commit file at path: %@, error: %@", self.commitFilePath, removeError);
    }
    return YES;
}

/**
 * Wraps the position if it exceeds the end of the file.
 */
- (NSUInteger)wrapPosition:(NSUInteger)position {
    return position < self.fileLength ? position : (QueueFileHeaderLength + position - self.fileLength);
}

/**
 * If necessary, expands the file to accommodate the given elements.
 *
 * Returns YES on success. On failure, returns NO and sets *error.
 */
- (BOOL)expandIfNecessary:(NSArray<NSData *> *)elements
                    error:(NSError * __autoreleasing * _Nullable)error {
    // For each element, reserve 4 bytes to serialize the element's length.
    NSUInteger numBytesRequested = ElementHeaderLength * elements.count;
    for (NSData *data in elements) {
        numBytesRequested += data.length;
    }
    NSUInteger remainingBytes = [self remainingBytes];

    // The file has enough space to accomodate the new element. Return early
    if (remainingBytes >= numBytesRequested) {
        return YES;
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
    if (![self setFile:self.fileHandle toLength:newFileLength synchronizeFile:NO error:error]) {
        return NO;
    }

    // Calculate the position of the tail end of the data in the ring buffer
    NSUInteger endOfLastElement = [self wrapPosition:self.last.position + ElementHeaderLength + self.last.length];

    if (endOfLastElement <= self.first.position) {
        // Hard luck. The data wrapped around to the head and is now fragmented due to file expansion.
        // Copy the tail data after the head data to fix and make contiguous.
        NSUInteger count = endOfLastElement - QueueFileHeaderLength;
        NSData *buffer = [self ringReadAtPosition:QueueFileHeaderLength count:count error:error];
        if (!buffer) {
            return NO;
        }
        if (![self.fileHandle seekToOffset:self.fileLength error:error]) {
          if (error) {
            CASLOG(@"Could not seek to offset %zu, error: %@", self.fileLength, *error);
          }
          return NO;
        }
        if (![self.fileHandle writeData:buffer error:error]) {
          if (error) {
            CASLOG(@"Could not write %zu bytes, error: %@", buffer.length, *error);
          }
          return NO;
        }
        if (![self ringEraseAtPosition:QueueFileHeaderLength length:count synchronizeFile:NO error:error]) {
            return NO;
        }
    }

    // Update the headers and in-memory variables
    if (self.last.position < self.first.position) {
        NSUInteger newLastPosition = self.fileLength + self.last.position - QueueFileHeaderLength;
        if (![self writeHeader:newFileLength
                  elementCount:self.elementCount
                 firstPosition:self.first.position
                  lastPosition:newLastPosition
               synchronizeFile:YES
                         error:error]) {
            return NO;
        }
        self.last = [[CASQueueFileElement alloc] initAtPosition:newLastPosition withLength:self.last.length];
    } else {
        if (![self writeHeader:newFileLength
                  elementCount:self.elementCount
                 firstPosition:self.first.position
                  lastPosition:self.last.position
               synchronizeFile:YES
                         error:error]) {
            return NO;
        }
    }
    self.fileLength = newFileLength;
    return YES;
}

/**
 * Truncates the specified file to the new length, and commits it to persisted storage.
 */
- (BOOL)setFile:(NSFileHandle *)fileHandle
       toLength:(NSUInteger)newLength
synchronizeFile:(BOOL)synchronizeFile
          error:(NSError * __autoreleasing * _Nullable)error {
  if (![fileHandle truncateAtOffset:newLength error:error]) {
    if (error) {
      CASLOG(@"Could not truncate to %zu bytes, error: %@", newLength, *error);
    }
    return NO;
  }
    if (synchronizeFile) {
        return [self synchronizeFile:fileHandle error:error];
    }
    return YES;
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

- (BOOL)synchronizeFile:(NSFileHandle *)file error:(NSError * __autoreleasing * _Nullable)error {
  if (![self.fileHandle synchronizeAndReturnError:error]) {
    if (error) {
      CASLOG(@"Could not synchronize file, error: %@", *error);
    }
    return NO;
  }
    return YES;
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
