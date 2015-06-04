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
#define ELEMENT_HEADER_LENGTH 16

@interface Element : NSObject

@property (nonatomic, readwrite) int position;
@property (nonatomic, readwrite) int length;

@end

@implementation Element

const Element *ELEMENT_NULL = [Element elementAtPosition:0 withLength:0];

+ (instancetype)elementAtPosition:(int)position withLength:(int)length {
    return [[Element alloc] initAtPosition:position withLength:length];
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

@property (nonatomic, strong, readwrite) NSFileManager *fileManager;
@property (nonatomic, strong, readwrite) NSString *filePath;
@property (nonatomic, strong, readwrite) NSFileHandle *fileHandle;

/** Cached file length. Always a power of 2. */
@property (nonatomic, readwrite) int fileLength;

/** Number of elements. */
@property (nonatomic, readwrite) int elementCount;

/** Pointer to first (or eldest) element. */
@property (nonatomic, readwrite) Element *first;

/** Pointer to last (or newest) element. */
@property (nonatomic, readwrite) Element *last;

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
+ (void)initialize:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];

    // Use a temp file so we don't leave a partially-initialized file.
    NSString *tempPath = [NSString stringWithFormat:@"%@.tmp", path];

    NSError *error = nil;
    BOOL success = [fileManager createDirectoryAtPath:tempPath
                          withIntermediateDirectories:YES
                                           attributes:nil
                                                error:&error];
    if (!success) {
        // TODO: raise exception
    }

    NSFileHandle *tempFileHandle =
            [NSFileHandle fileHandleForUpdatingAtPath:tempPath];
    [tempFileHandle truncateFileAtOffset:QUEUE_FILE_INITIAL_LENGTH];
    [tempFileHandle seekToFileOffset:0];
    NSMutableData *headerBuffer = [NSMutableData dataWithLength:QUEUE_FILE_HEADER_LENGTH];
    writeInt(headerBuffer, 0, QUEUE_FILE_INITIAL_LENGTH);
    [tempFileHandle writeData:headerBuffer];
    [tempFileHandle synchronizeFile]; // It's unclear if closing the file fsync's it as well
    [tempFileHandle closeFile];

    [fileManager moveItemAtPath:tempPath toPath:path error:&error];
    if (error) {
        // TODO: raise exception
    }
}

+ (QueueFile *)queueFileWithPath:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path]) {
        [QueueFile initialize:path];
    }

    return [[self alloc] initWithPath:path forManager:fileManager];
}

- (instancetype)initWithPath:(NSString *)filePath forManager:(NSFileManager *)fileManager {
    if (self = [super init]) {
        _filePath = filePath;
        _fileManager = fileManager;
        _fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:filePath];
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
        // TODO: raise exception
    } else if (_fileLength <= 0) {
        // TODO: raise exception
    }

    _elementCount = readInt(buffer, 4);
    int firstOffset = readInt(buffer, 8);
    int lastOffset = readInt(buffer, 12);

    _first = [self readElement:firstOffset];
    _last = [self readElement:lastOffset];
}

- (Element *)readElement:(int)position {
    if (position == 0) {
        return ELEMENT_NULL;
    }
    NSData *buffer = [self ringRead:position count:ELEMENT_HEADER_LENGTH];
    int length = readInt(buffer, 0);
    return [Element elementAtPosition:position withLength:length];
}

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
    return position < _fileLength ? position : QUEUE_FILE_HEADER_LENGTH + position - _fileLength;
}

/** Adds an element to the end of the queue. */
- (void)add:(NSData *)data {
    int count = data.length;
    [self expandIfNecessary:count];

    // Insert a new element after the current last element.
    BOOL wasEmpty = [self isEmpty];
    int position = wasEmpty ? QUEUE_FILE_HEADER_LENGTH
            : [self wrapPosition:_last.position + ELEMENT_HEADER_LENGTH + _last.length];
    Element *newLast = [Element elementAtPosition:position withLength:count];
}

/** If necessary, expands the file to accommodate an additional element of the given length. */
- (void)expandIfNecessary:(int)dataLength {
    int elementLength = ELEMENT_HEADER_LENGTH + dataLength;
    int remainingBytes = [self remainingBytes];
    if (remainingBytes >= elementLength) return;
}

- (int)remainingBytes {
    return _fileLength - [self usedBytes];
}

- (int)usedBytes {
    if (_elementCount == 0) return QUEUE_FILE_HEADER_LENGTH;

    if (_last.position >= _first.position) {
        // Contiguous queue.
        return (_last.position - _first.position)   // all but last entry
                + ELEMENT_HEADER_LENGTH + _last.length // last entry
                + QUEUE_FILE_HEADER_LENGTH;
    } else {
        // tail < head. The queue wraps.
        return _last.position                      // buffer front + header
                + ELEMENT_HEADER_LENGTH + _last.length // last entry
                + _fileLength - _first.position;        // buffer end
    }
}

/** Returns true if this queue contains no entries. */
- (BOOL)isEmpty {
    return _elementCount == 0;
}

- (NSData *)peek {
    return nil;
}

- (int)size {
    return 0;
}

- (void)remove {
}

- (void)remove:(int)n {
}

- (void)clear {
}

@end