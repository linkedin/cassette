//
//  QueueFile.m
//  Cassette
//
//  Created by Prateek Srivastava on 2015-06-03.
//  Copyright (c) 2015 Segment. All rights reserved.
//

#import "QueueFile.h"

/** Initial file size in bytes. */
#define QUEUE_FILE_INITIAL_LENGTH 4096 // one file system block
/** Length of header in bytes. */
#define QUEUE_FILE_HEADER_LENGTH 16
/** Length of element header in bytes. */
#define ELEMENT_HEADER_LENGTH 4

@interface Element : NSObject

@property(nonatomic, readwrite) int position;
@property(nonatomic, readwrite) int length;

@end

@implementation Element

+ (instancetype)atPosition:(int)position withLength:(int)length {
  return [[Element alloc] initAtPosition:position withLength:length];
}

+ (instancetype)null {
  return [Element atPosition:0 withLength:0];
}

- (instancetype)initAtPosition:(int)position withLength:(int)length {
  if (self = [super init]) {
    _position = position;
    _length = length;
  }
  return self;
}

@end

@interface QueueFile ()

@property(nonatomic, strong, readwrite) NSFileManager *fileManager;
@property(nonatomic, strong, readwrite) NSString *filePath;
@property(nonatomic, strong, readwrite) NSFileHandle *fileHandle;

/** In-memory buffer. Big enough to hold the header. */
@property(nonatomic, readwrite) NSMutableData *buffer;

/** Cached file length. Always a power of 2. */
@property(nonatomic, readwrite) int fileLength;

/** Number of elements. */
@property(nonatomic, readwrite) int elementCount;

/** Pointer to first (or eldest) element. */
@property(nonatomic, readwrite) Element *first;

/** Pointer to last (or newest) element. */
@property(nonatomic, readwrite) Element *last;

@end

@implementation QueueFile

/** Stores an {@code int} in the {@code buffer} at the given {@code offset}. */
void writeInt(NSMutableData *buffer, int offset, int value) {
  [buffer replaceBytesInRange:NSMakeRange(offset, 4) withBytes:&value];
}

/** Reads an {@code int} from the {@code buffer}. */
int readInt(NSData *buffer, int offset) {
  int value;
  [buffer getBytes:&value range:NSMakeRange(offset, 4)];
  return value;
}

/** Returns the size of the while without clobbering the current offset. */
unsigned long long int sizeOfFile(NSFileHandle *fileHandle) {
  unsigned long long int offsetInFile = fileHandle.offsetInFile;
  unsigned long long int size = [fileHandle seekToEndOfFile];
  [fileHandle seekToFileOffset:offsetInFile];
  return size;
}

/** Atomically initializes a new QueueFile at the given path. */
void initialize(NSString *path) {
  NSFileManager *fileManager = [NSFileManager defaultManager];

  // Use a temporary file so we don't leave a partially-initialized file.
  NSString *tempPath = [NSString stringWithFormat:@"%@.tmp", path];

  NSMutableData *headerBuffer =
      [NSMutableData dataWithLength:QUEUE_FILE_INITIAL_LENGTH];
  writeInt(headerBuffer, 0, QUEUE_FILE_INITIAL_LENGTH);

  BOOL success = [fileManager createFileAtPath:tempPath
                                      contents:headerBuffer
                                    attributes:nil];

  if (!success) {
    [NSException raise:@"IOException"
                format:@"Could not initialize file at path: %@.", tempPath];
  }

  // TODO: is moving atomic?
  NSError *error;
  [fileManager moveItemAtPath:tempPath toPath:path error:&error];
  if (error) {
    [NSException raise:@"IOException"
                format:@"Could not move file from %@ to %@.", path, tempPath];
  }
}

+ (QueueFile *)queueFileWithPath:(NSString *)path {
  NSFileManager *fileManager = [NSFileManager defaultManager];
  if (![fileManager fileExistsAtPath:path]) {
    initialize(path);
  }

  return [[self alloc] initWithPath:path forManager:fileManager];
}

- (instancetype)initWithPath:(NSString *)filePath
                  forManager:(NSFileManager *)fileManager {
  if (self = [super init]) {
    _filePath = filePath;
    _fileManager = fileManager;
    _fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:filePath];
    _buffer = [NSMutableData dataWithLength:QUEUE_FILE_HEADER_LENGTH];
    [self readHeader];
  }
  return self;
}

/** Read the data stored in the header into instance variables. */
- (void)readHeader {
  [_fileHandle seekToFileOffset:0];
  NSData *buffer = [_fileHandle readDataOfLength:QUEUE_FILE_HEADER_LENGTH];

  _fileLength = readInt(buffer, 0);
  if (_fileLength > sizeOfFile(_fileHandle)) {
    [NSException
         raise:@"IOException"
        format:@"File is truncated. Expected length: %d, Actual length: %d",
               _fileLength, sizeOfFile(_fileHandle)];
  } else if (_fileLength <= 0) {
    [NSException
         raise:@"IOException"
        format:@"File is corrupt; length stored in header (%d) is invalid.",
               _fileLength];
  }

  _elementCount = readInt(buffer, 4);
  int firstOffset = readInt(buffer, 8);
  int lastOffset = readInt(buffer, 12);

  _first = [self readElement:firstOffset];
  _last = [self readElement:lastOffset];
}

/**
 * Reads the element stored at the given position in the file, wrapping around
 * if necessary.
 */
- (Element *)readElement:(int)position {
  if (position == 0) {
    return [Element null];
  }
  NSData *buffer = [self ringRead:position count:ELEMENT_HEADER_LENGTH];
  int length = readInt(buffer, 0);
  return [Element atPosition:position withLength:length];
}

/**
 * Reads {@code count} bytes from the given position in the file, wrapping
 * around if necessary.
 */
- (NSData *)ringRead:(int)position count:(int)count {
  position = [self wrapPosition:position];

  if (position + count < _fileLength) {
    [_fileHandle seekToFileOffset:position];
    return [_fileHandle readDataOfLength:count];
  }

  // The read overlaps the EOF.
  NSMutableData *buffer = [NSMutableData dataWithLength:count];
  // # of bytes to read before the EOF.
  int beforeEof = _fileLength - position;
  [_fileHandle seekToFileOffset:beforeEof];
  [buffer appendData:[_fileHandle readDataOfLength:beforeEof]];
  [_fileHandle seekToFileOffset:QUEUE_FILE_HEADER_LENGTH];
  [buffer appendData:[_fileHandle readDataOfLength:count - beforeEof]];
  return buffer;
}

/** Wraps the position if it exceeds the end of the file. */
- (int)wrapPosition:(int)position {
  return position < _fileLength ? position : QUEUE_FILE_HEADER_LENGTH +
                                                 position - _fileLength;
}

/** Adds an element to the end of the queue. */
- (void)add:(NSData *)data {
  int count = data.length;
  [self expandIfNecessary:count];

  // Insert a new element after the current last element.
  BOOL wasEmpty = [self isEmpty];
  int position = wasEmpty
                     ? QUEUE_FILE_HEADER_LENGTH
                     : [self wrapPosition:_last.position +
                                          ELEMENT_HEADER_LENGTH + _last.length];
  Element *newLast = [Element atPosition:position withLength:count];

  // Write length.
  writeInt(_buffer, 0, count);
  [self ringWrite:newLast.position
           buffer:_buffer
           offset:0
            count:ELEMENT_HEADER_LENGTH];

  // Write data.
  [self ringWrite:newLast.position + ELEMENT_HEADER_LENGTH
           buffer:data
           offset:0
            count:count];

  // Commit the addition. If wasEmpty, first == last.
  int firstPosition = wasEmpty ? newLast.position : _first.position;
  [self writeHeader:_fileLength
       elementCount:_elementCount + 1
      firstPosition:firstPosition
       lastPosition:newLast.position];
  _last = newLast;
  _elementCount++;
  if (wasEmpty) {
    _first = _last; // first element
  }
}

/**
 * If necessary, expands the file to accommodate an additional element of the
 * given length.
 */
- (void)expandIfNecessary:(int)dataLength {
  int elementLength = ELEMENT_HEADER_LENGTH + dataLength;
  int remainingBytes = [self remainingBytes];
  if (remainingBytes >= elementLength) {
    return;
  }

  // Expand.
  int previousLength = _fileLength;
  int newLength;
  // Double the length until we can fit the new data.
  do {
    remainingBytes += previousLength;
    newLength = previousLength << 1;
    previousLength = newLength;
  } while (remainingBytes < elementLength);

  [self setLength:newLength];

  // Calculate the position of the tail end of the data in the ring buffer
  int endOfLastElement =
      [self wrapPosition:_last.position + ELEMENT_HEADER_LENGTH + _last.length];

  // If the buffer is split, we need to make it contiguous
  if (endOfLastElement <= _first.position) {
    int count = endOfLastElement - QUEUE_FILE_HEADER_LENGTH;
    NSData *buffer = [self ringRead:QUEUE_FILE_HEADER_LENGTH count:count];
    [_fileHandle seekToFileOffset:_fileLength];
    [_fileHandle writeData:buffer];
    [self ringErase:QUEUE_FILE_HEADER_LENGTH length:count];
  }

  // Commit the expansion.
  if (_last.position < _first.position) {
    int newLastPosition =
        _fileLength + _last.position - QUEUE_FILE_HEADER_LENGTH;
    [self writeHeader:newLength
         elementCount:_elementCount
        firstPosition:_first.position
         lastPosition:_last.position];
    _last = [Element atPosition:newLastPosition withLength:_last.length];
  } else {
    [self writeHeader:newLength
         elementCount:_elementCount
        firstPosition:_first.position
         lastPosition:_last.position];
  }

  _fileLength = newLength;
}

- (int)remainingBytes {
  return _fileLength - [self usedBytes];
}

- (int)usedBytes {
  if (_elementCount == 0)
    return QUEUE_FILE_HEADER_LENGTH;

  if (_last.position >= _first.position) {
    // Contiguous queue.
    return (_last.position - _first.position)     // all but last entry
           + ELEMENT_HEADER_LENGTH + _last.length // last entry
           + QUEUE_FILE_HEADER_LENGTH;
  } else {
    // tail < head. The queue wraps.
    return _last.position                         // buffer front + header
           + ELEMENT_HEADER_LENGTH + _last.length // last entry
           + _fileLength - _first.position;       // buffer end
  }
}

/**
 * Writes {@code count} bytes from buffer to position in file. Automatically
 * wraps write if position is past the end of the file or if buffer overlaps it.
 */
- (void)ringWrite:(int)position
           buffer:(NSData *)buffer
           offset:(int)offset
            count:(int)count {
  position = [self wrapPosition:position];

  if (position + count <= _fileLength) {
    NSData *actual = [buffer subdataWithRange:NSMakeRange(offset, count)];
    [_fileHandle seekToFileOffset:position];
    [_fileHandle writeData:actual];
  } else {
    // The write overlaps the EOF.
    // # of bytes to write before the EOF.
    int beforeEof = _fileLength - position;
    [_fileHandle seekToFileOffset:position];
    [_fileHandle
        writeData:[buffer subdataWithRange:NSMakeRange(offset, beforeEof)]];
    [_fileHandle seekToFileOffset:QUEUE_FILE_HEADER_LENGTH];
    [_fileHandle
        writeData:[buffer subdataWithRange:NSMakeRange(offset + beforeEof,
                                                       count - beforeEof)]];
  }

  [_fileHandle synchronizeFile];
}

/**
 * Writes header atomically. The arguments contain the updated values. The class
 * member fields should not have changed yet. This only updates the state in the
 * file. It's up to the caller to update the class member variables *after* this
 * call succeeds. Assumes segment writes are atomic in the underlying file
 * system.
 */
- (void)writeHeader:(int)fileLength
       elementCount:(int)elementCount
      firstPosition:(int)firstPosition
       lastPosition:(int)lastPosition {
  writeInt(_buffer, 0, fileLength);
  writeInt(_buffer, 4, elementCount);
  writeInt(_buffer, 8, firstPosition);
  writeInt(_buffer, 12, lastPosition);

  [_fileHandle seekToFileOffset:0];
  [_fileHandle writeData:_buffer];
  [_fileHandle synchronizeFile];
}

/** Returns true if this queue contains no entries. */
- (BOOL)isEmpty {
  return _elementCount == 0;
}

/** Reads the eldest element. Returns null if the queue is empty. */
- (NSData *)peek {
  if ([self isEmpty]) {
    return NULL;
  }

  return [self ringRead:_first.position + ELEMENT_HEADER_LENGTH
                  count:_first.length];
}

/** Returns the number of elements in this queue. */
- (int)size {
  return _elementCount;
}

/** Removes the eldest element. */
- (void)remove {
  [self remove:1];
}

/** Removes the eldest {@code n} elements. */
- (void)remove:(int)n {
  if ([self isEmpty]) {
    [NSException raise:@"Assertion"
                format:@"Cannot remove elements from an empty file."];
  }
  if (n < 0) {
    [NSException raise:@"Assertion"
                format:@"Cannot remove negative number of elements."];
  }
  if (n == 0) {
    return;
  }
  if (n == _elementCount) {
    [self clear];
    return;
  }
  if (n > _elementCount) {
    [NSException raise:@"Assertion"
                format:@"Cannot remove more elements (%d) than in file (%d).",
                       n, _elementCount];
  }

  int eraseStartPosition = _first.position;
  int eraseTotalLength = 0;

  // Read the position and length of the new first element.
  int newFirstPosition = _first.position;
  int newFirstLength = _first.length;
  for (int i = 0; i < n; i++) {
    eraseTotalLength += ELEMENT_HEADER_LENGTH + newFirstLength;
    newFirstPosition = [self
        wrapPosition:newFirstPosition + ELEMENT_HEADER_LENGTH + newFirstLength];
    NSData *buffer =
        [self ringRead:newFirstPosition count:ELEMENT_HEADER_LENGTH];
    newFirstLength = readInt(buffer, 0);
  }

  // Commit the header.
  [self writeHeader:_fileLength
       elementCount:_elementCount - n
      firstPosition:newFirstPosition
       lastPosition:_last.position];
  _elementCount -= n;
  _first = [Element atPosition:newFirstPosition withLength:newFirstLength];

  // Commit the erase.
  [self ringErase:eraseStartPosition length:eraseTotalLength];
}

/** Erases the file starting at {@code position} until {@code length}. */
- (void)ringErase:(int)position length:(int)length {
  NSData *buffer = [NSMutableData dataWithCapacity:length];
  [self ringWrite:position buffer:buffer offset:0 count:length];
}

/** Clears this queue. Truncates the file to the initial size. */
- (void)clear {
  // Commit the header
  [self writeHeader:QUEUE_FILE_INITIAL_LENGTH
       elementCount:0
      firstPosition:0
       lastPosition:0];

  // Zero out the data.
  NSData *buffer = [NSMutableData
      dataWithLength:QUEUE_FILE_INITIAL_LENGTH - QUEUE_FILE_HEADER_LENGTH];
  [self ringWrite:QUEUE_FILE_HEADER_LENGTH
           buffer:buffer
           offset:0
            count:QUEUE_FILE_INITIAL_LENGTH - QUEUE_FILE_HEADER_LENGTH];

  _elementCount = 0;
  _first = [Element null];
  _last = [Element null];
  if (_fileLength > QUEUE_FILE_INITIAL_LENGTH) {
    [self setLength:QUEUE_FILE_INITIAL_LENGTH];
  }
  _fileLength = QUEUE_FILE_INITIAL_LENGTH;
}

/** Sets the length of the file. */
- (void)setLength:(int)newLength {
  [_fileHandle truncateFileAtOffset:newLength];
  [_fileHandle synchronizeFile];
}

@end