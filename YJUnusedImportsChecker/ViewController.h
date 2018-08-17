//
//  ViewController.h
//  YJUnusedImportsChecker
//
//  Created by Jing Yang on 2017/09/03 Sunday.
//  Copyright © 2017 Jing Yang. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ViewController : NSViewController

@property (weak) IBOutlet NSTextField *dotXcworkspacePathTextField;

@property (weak) IBOutlet NSTextField *toCheckFolderPathTextField;

@property (weak) IBOutlet NSTextField *symrootTextField;

@property (weak) IBOutlet NSTextField *handlingFilenameLabel;

- (IBAction)dotXcworkspacePathBrowserBtn:(id)sender;

- (IBAction)toCheckFolderBrowserBtn:(id)sender;

- (IBAction)symrootPathBrowserBtn:(id)sender;

@end

