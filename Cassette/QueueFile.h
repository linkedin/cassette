//
//  QueueFile.h
//  Cassette
//
//  Created by Prateek Srivastava on 2015-06-03.
//  Copyright (c) 2015 Segment. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface QueueFile : NSObject

+ (QueueFile *)queueFileWithPath:(NSString *)path;

/** Adds an element to the end of the queue. */
- (void)add:(NSData *)data;

/** Returns true if this queue contains no entries. */
- (BOOL)isEmpty;

/** Reads the eldest element. Returns null if the queue is empty. */
- (NSData *)peek;

/**
 * Invokes the given reader once for each element in the queue, from eldest to most recently
 * added and returns the number of elements visited. Continues until all elements are read or
 * the reader returns false.
 */
- (int)forEach:(BOOL (^)(NSData *data))reader;

/** Returns the number of elements in this queue. */
- (int)size;

/** Removes the eldest element. */
- (void)remove;

/** Removes the eldest {@code n} elements. */
- (void)remove:(int)n;

/** Clears this queue. Truncates the file to the initial size. */
- (void)clear;

@end
