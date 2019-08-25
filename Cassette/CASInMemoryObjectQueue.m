//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and limitations under the License.

#import "CASInMemoryObjectQueue.h"

@interface CASInMemoryObjectQueue ()

@property (nonatomic, strong, nonnull) NSMutableArray *inMemoryStorage;

@end

@implementation CASInMemoryObjectQueue

- (instancetype)init {
    if (self = [super init]) {
        _inMemoryStorage = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)add:(id)data {
    [self.inMemoryStorage addObject:data];
}

- (NSUInteger)size {
    return self.inMemoryStorage.count;
}

-(NSArray *)peek:(NSUInteger)amount {
    // Clamp number of elements we read down to the size in case @c amount is larger
    NSUInteger actualAmountToRetrieve = MIN(amount, self.size);
    return [self.inMemoryStorage subarrayWithRange:NSMakeRange(0, actualAmountToRetrieve)];
}

- (void)pop:(NSUInteger)amount {
    if (amount >= self.size) {
        [self clear];
        return;
    }

    [self.inMemoryStorage removeObjectsInRange:NSMakeRange(0, amount)];
}

- (void)clear {
    [self.inMemoryStorage removeAllObjects];
}

@end
