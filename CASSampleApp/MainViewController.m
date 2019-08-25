//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and limitations under the License.

#import "MainViewController.h"

#import <Cassette/CASFileObjectQueue.h>

@interface MainViewController ()<UITextFieldDelegate>

@property (nonatomic, strong, nullable) CASFileObjectQueue<NSNumber *> *queue;

@property (weak, nonatomic) IBOutlet UITextField *inputField;
@property (weak, nonatomic) IBOutlet UILabel *headElementLabel;

@end

@implementation MainViewController

- (instancetype)init {
    self = [super initWithNibName:@"MainViewController" bundle:nil];
    if (self) {

    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    NSError *error;
    self.queue = [[CASFileObjectQueue alloc] initWithRelativePath:@"sample-app-tape-storage" error:&error];
    if (error != nil) {
        NSLog(@"Queue should have been properly created but it wasn't.");
    }

    self.inputField.delegate = self;
}

- (IBAction)tapAddButton:(__unused id)sender {
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    NSString *result = self.inputField.text;
    NSNumber *number = [numberFormatter numberFromString:result];
    if (number != nil) {
        [self.queue add:number];
    }
    [self refreshHeadElementLabel];
}

- (IBAction)tapPopButton:(__unused id)sender {
    [self.queue pop];
    [self refreshHeadElementLabel];
}

- (IBAction)tapPeekButton:(__unused id)sender {
    [self refreshHeadElementLabel];
}

- (void)refreshHeadElementLabel {
    NSNumber *number = [self.queue peek];
    if (number == nil) {
        self.headElementLabel.text = @"empty";
    } else {
        self.headElementLabel.text = number.stringValue;
    }
}

- (BOOL)textField:(__unused UITextField *)textField shouldChangeCharactersInRange:(__unused NSRange)range replacementString:(__unused NSString *)string {
    // Only allow numbers
    NSCharacterSet *numbersOnly = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
    NSCharacterSet *characterSetFromTextField = [NSCharacterSet characterSetWithCharactersInString:string];
    BOOL stringIsValid = [numbersOnly isSupersetOfSet:characterSetFromTextField];
    return stringIsValid;
}

@end
