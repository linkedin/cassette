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

- (void)add:(__unused id)data {
    [NSException raise:NSInternalInconsistencyException
                format:@"Must override LITapeObjectQueue method '%@' in subclass '%@'", NSStringFromSelector(_cmd), [self class]];
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
    NSArray<id> *elements = [self peek:1];
    if (elements.count > 0) {
        return elements[0];
    }
    return nil;
}

- (NSArray<id> *)peek:(__unused NSUInteger)amount {
    [NSException raise:NSInternalInconsistencyException
                format:@"Must override LITapeObjectQueue method '%@' in subclass '%@'", NSStringFromSelector(_cmd), [self class]];
    return @[];
}

- (void)pop {
    [self pop:1];
}

- (void)pop:(__unused NSUInteger)amount {
    [NSException raise:NSInternalInconsistencyException
                format:@"Must override LITapeObjectQueue method '%@' in subclass '%@'", NSStringFromSelector(_cmd), [self class]];
}

- (void)clear {
    [self pop:self.size];
}

@end
