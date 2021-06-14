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
#import "CASPrivateConstants.h"
#import "CASQueueFile.h"
#import "CASDefaultDataSerializer.h"

@interface CASFileObjectQueue ()

/**
 * Backing storage implementation
 */
@property (nonatomic, nonnull, strong, readonly) CASQueueFile *queueFile;

@property (nonatomic, nonnull, strong, readonly) id<CASDataSerializer> serializer;

@property (nonatomic, assign) NSUInteger objectCount;

@end

@implementation CASFileObjectQueue

- (instancetype)initWithRelativePath:(NSString *)filePath error:(NSError * __autoreleasing * _Nullable)error {
    return [self initWithRelativePath:filePath serializer:[CASDefaultDataSerializer shared] error:error];
}

- (instancetype)initWithRelativePath:(NSString *)filePath serializer:(id<CASDataSerializer>)serializer error:(NSError *__autoreleasing  _Nullable *)error {
    NSArray<NSString *> *directoryPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *absolutePath = [directoryPaths[0] stringByAppendingPathComponent:filePath];
    return [self initWithAbsolutePath:absolutePath serializer:serializer error:error];
}

- (instancetype)initWithAbsolutePath:(NSString *)filePath error:(NSError * __autoreleasing * _Nullable)error {
    return [self initWithAbsolutePath:filePath serializer:[CASDefaultDataSerializer shared] error:error];
}

- (instancetype)initWithAbsolutePath:(NSString *)filePath serializer:(id<CASDataSerializer>)serializer error:(NSError *__autoreleasing  _Nullable *)error {
    if (self = [super init]) {
        CASQueueFile *queueFile = [CASQueueFile queueFileWithPath:filePath error:error];
        if (error != nil && *error != nil) {
            return nil;
        }
        _queueFile = queueFile;
        _serializer = serializer;
    }
    return self;
}

- (NSUInteger)size {
    return self.queueFile.size;
}

- (void)add:(id)data {
    NSError *error;
    NSData *serializedData = [self.serializer serialize:data error:&error];

    if (error != nil) {
        CASLOG(@"Error serializing data: %@", error.localizedDescription);
    } else {
        [self.queueFile add:serializedData];
    }
}

- (NSArray<id> *)peek:(NSUInteger)amount {
    NSArray<NSData *> *elements = [self.queueFile peek:amount];
    NSMutableArray<id> *coercedElements = [[NSMutableArray alloc] init];
    for (NSUInteger i = 0; i < elements.count; i++) {
        NSData *element = elements[i];
        id coercedElement = [self deserialize:element];
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

#pragma mark - Helper Method

- (nullable id)deserialize:(NSData *)data {
    NSError *error;
    id result = [self.serializer deserialize:data error:&error];
    if (error != nil) {
        CASLOG(@"Error deserializing data: %@", error.localizedDescription);
    }

    return result;
}

@end
