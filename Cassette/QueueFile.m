//
//  QueueFile.m
//  Cassette
//
//  Created by Prateek Srivastava on 2015-06-03.
//  Copyright (c) 2015 Segment. All rights reserved.
//

#import "QueueFile.h"

/** Initial file size in bytes. */
#define INITIAL_LENGTH 4096 // one file system block
/** Length of header in bytes. */
#define HEADER_LENGTH 16

@interface QueueFile ()

@property (nonatomic, strong, readwrite) NSFileHandle *fileHandle;
/** In-memory buffer. Big enough to hold the header. */
@property (nonatomic, strong, readwrite) NSData *buffer;

/** Cached file length. Always a power of 2. */
@property (nonatomic, readwrite) int fileLength;
/** Number of elements. */
@property (nonatomic, readwrite) int elementCount;

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
    [tempFileHandle truncateFileAtOffset:INITIAL_LENGTH];
    [tempFileHandle seekToFileOffset:0];
    NSMutableData *headerBuffer = [NSMutableData dataWithLength:16];
    writeInt(headerBuffer, 0, INITIAL_LENGTH);
    [tempFileHandle writeData:headerBuffer];
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

    NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:path];
    return [[self alloc] initWithFileHandle:fileHandle];
}

- (instancetype)initWithFileHandle:(NSFileHandle *)fileHandle {
    if (self = [super init]) {
        self.fileHandle = fileHandle;
    }
    return self;
}

- (void)readHeader {
    [self.fileHandle seekToFileOffset:0];
    NSData *data = [self.fileHandle readDataOfLength:HEADER_LENGTH];
}

- (void)add:(NSData *)data {
}

- (BOOL)isEmpty {
    return NO;
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
