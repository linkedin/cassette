//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and limitations under the License.

#import "CASObjectQueue.h"

@implementation CASObjectQueue

- (BOOL)closeAndReturnError:(NSError * __autoreleasing * _Nullable)error {
    [NSException raise:NSInternalInconsistencyException
                format:@"Must override method '%@' in subclass '%@'", NSStringFromSelector(_cmd), [self class]];
    return NO;
}

- (void)add:(id<NSCoding>)data {
    [self add:data error:NULL];
}

- (BOOL)add:(id<NSCoding>)data error:(NSError * __autoreleasing * _Nullable)error {
    return [self addElements:@[data] error:error];
}

- (BOOL)addElements:(__unused NSArray<id> *)elements error:(__unused NSError * __autoreleasing * _Nullable)error {
    [NSException raise:NSInternalInconsistencyException
                format:@"Must override LITapeObjectQueue method '%@' in subclass '%@'", NSStringFromSelector(_cmd), [self class]];
    return NO;
}

- (NSUInteger)size {
    [NSException raise:NSInternalInconsistencyException
                format:@"Must override LITapeObjectQueue method '%@' in subclass '%@'", NSStringFromSelector(_cmd), [self class]];
    return 0;
}

- (BOOL)isEmpty {
    return self.size == 0;
}

- (id)peek {
    return [self peek:1 error:NULL].firstObject;
}

- (id)peekWithError:(NSError * __autoreleasing * _Nullable)error {
    return [self peek:1 error:error].firstObject;
}

- (NSArray<id> *)peek:(NSUInteger)amount {
    return [self peek:amount error:NULL] ?: @[];
}

- (NSArray<id> * _Nullable)peek:(__unused NSUInteger)amount error:(__unused NSError * __autoreleasing * _Nullable)error {
    [NSException raise:NSInternalInconsistencyException
                format:@"Must override LITapeObjectQueue method '%@' in subclass '%@'", NSStringFromSelector(_cmd), [self class]];
    return nil;
}

- (void)pop {
    [self pop:1 error:NULL];
}

- (void)pop:(NSUInteger)amount {
    [self pop:amount error:NULL];
}

- (BOOL)pop:(__unused NSUInteger)amount error:(__unused NSError * __autoreleasing * _Nullable)error {
    [NSException raise:NSInternalInconsistencyException
                format:@"Must override LITapeObjectQueue method '%@' in subclass '%@'", NSStringFromSelector(_cmd), [self class]];
    return NO;
}

- (void)clear {
    [self clearAndReturnError:NULL];
}

- (BOOL)clearAndReturnError:(NSError * __autoreleasing * _Nullable)error {
    return [self pop:self.size error:error];
}

@end
