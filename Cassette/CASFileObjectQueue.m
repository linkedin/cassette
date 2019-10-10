//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and limitations under the License.

#import "CASFileObjectQueue.h"

#import "CASQueueFile.h"

@interface CASFileObjectQueue ()

/**
 * Backing storage implementation
 */
@property (nonatomic, nonnull, strong, readonly) CASQueueFile *queueFile;

@property (nonatomic, assign) NSUInteger objectCount;

@end

@implementation CASFileObjectQueue

- (instancetype)initWithRelativePath:(NSString *)filePath error:(NSError * __autoreleasing * _Nullable)error {
    if ([filePath hasSuffix:@"/"]) {
        NSAssert(NO, @"invalid path, should end with filename, not directory component.");
        return nil;
    }
    NSArray<NSString *> *directoryPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *absolutePath = [directoryPaths[0] stringByAppendingPathComponent:filePath];
    return [self initWithAbsolutePath:absolutePath error:error];
}

- (instancetype)initWithAbsolutePath:(NSString *)filePath error:(NSError * __autoreleasing * _Nullable)error {
    if (self = [super init]) {
        CASQueueFile *queueFile = [CASQueueFile queueFileWithPath:filePath error:error];
        if (error != nil && *error != nil) {
            return nil;
        }
        _queueFile = queueFile;
    }
    return self;
}

- (NSUInteger)size {
    return self.queueFile.size;
}

- (void)add:(id)data {
    [self.queueFile add:[NSKeyedArchiver archivedDataWithRootObject:data]];
}

- (void)addArchived:(NSData *)data {
    [self.queueFile add:data];
}

- (NSData *)peekArchivedData {
    NSArray<id> *elements = [self peek:1 archived:YES];
    if (elements.count > 0) {
        return elements[0];
    }
    return nil;
}

- (NSArray<id> *)peek:(NSUInteger)amount {
    return [self peek:amount archived:NO];
}

- (NSArray<id> *)peek:(NSUInteger)amount archived:(BOOL)archived {
    NSArray<NSData *> *elements = [self.queueFile peek:amount];
    NSMutableArray<id> *coercedElements = [[NSMutableArray alloc] init];
    for (NSUInteger i = 0; i < elements.count; i++) {
        NSData *element = elements[i];
        id coercedElement = archived ? element : [NSKeyedUnarchiver unarchiveObjectWithData:element];
        if (coercedElement != nil) {
            [coercedElements addObject:coercedElement];
        }
    }
    return coercedElements;
}

- (void)pop {
    [self pop:1];
}

- (void)pop:(NSUInteger)amount {
    [self.queueFile pop:amount];
}

- (void)clear {
    [self.queueFile clear];
}

@end
