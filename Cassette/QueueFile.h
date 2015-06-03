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

- (void)add:(NSData *)data;

- (BOOL)isEmpty;

- (NSData *)peek;

- (int)size;

- (void)remove;

- (void)remove:(int)n;

- (void)clear;

@end
