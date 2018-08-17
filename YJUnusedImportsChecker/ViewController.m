//
//  ViewController.m
//  YJUnusedImportsChecker
//
//  Created by Jing Yang on 2017/09/03 Sunday.
//  Copyright © 2017 Jing Yang. All rights reserved.
//

#import "ViewController.h"

@interface ViewController()

@property (weak) IBOutlet NSProgressIndicator *progressIndicator;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    self.dotXcworkspacePathTextField.editable = NO;
    self.toCheckFolderPathTextField.editable = NO;
    self.symrootTextField.editable = NO;
    self.handlingFilenameLabel.editable = NO;
}

- (void)handleOneFile:(NSString *)filePath {
    if (filePath.length <= 0) return;
    //按行读入
    NSString *content = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
    if (!content) return;
    NSArray *lines = [content componentsSeparatedByString:@"\n"];
    //遍历所有行，如果是 import 行，注释掉写回，并编译
    NSMutableArray *mutableLines = [lines mutableCopy];
    [lines enumerateObjectsUsingBlock:^(NSString* line, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([self isImportLine:line]) {
            NSString *str = [NSString stringWithFormat:@"//RICO TRY TO COMMET %@", line];//写入正常尝试注释的标记，如果程序异常中断，可能会遗留这个标记
            [mutableLines replaceObjectAtIndex:idx withObject:str];//注释掉
            [self writeBackToFile:mutableLines atPath:filePath];//写回
            BOOL buildSuccess = [self canXcodeProjBuildSuccess];//编译
            if (buildSuccess) {//如果编译通过, 写入注释成功的标记
                NSString *commetedSuccessStr = [NSString stringWithFormat:@"//RICO COMMET SUCCESS %@", line];
                [mutableLines replaceObjectAtIndex:idx withObject:commetedSuccessStr];
                [self writeBackToFile:mutableLines atPath:filePath];//写回

            } else {//如果编译失败
                [mutableLines replaceObjectAtIndex:idx withObject:line];//去掉注释写回，进行下一行
                [self writeBackToFile:mutableLines atPath:filePath];
                //建白名单，有用的 import 下次遇到直接跳过加快速度
            }
        }
    }];
}

- (BOOL)writeBackToFile:(NSMutableArray *)mutableLines atPath:(NSString *)filePath {
    //写回 pb 文件
    NSMutableString *outputPbfile = [[NSMutableString alloc] init];
    NSString *outputPath = filePath;
    //最后一行不要 append \n
    [mutableLines enumerateObjectsUsingBlock:^(NSString *line, NSUInteger idx, BOOL * _Nonnull stop) {
        if (idx == [mutableLines count]-1) {
            [outputPbfile appendFormat:@"%@", line];
        } else {
            [outputPbfile appendFormat:@"%@\n", line];
        }
    }];
    NSError *writeError = nil;
    [outputPbfile writeToFile:outputPath atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
    // Check write result
    if (writeError == nil) {
//        [self showAlertWithStyle:NSInformationalAlertStyle title:@"Delete Complete" subtitle:[NSString stringWithFormat:@"Delete Complete: %@", outputPath]];
        return YES;
    } else {
        return NO;
//        [self showAlertWithStyle:NSCriticalAlertStyle title:@"Delete Error" subtitle:[NSString stringWithFormat:@"Delete Error: %@", writeError]];
    }
}

- (BOOL)isImportLine:(NSString *)lineStr {
    if (![lineStr hasPrefix:@"//"] &&
        ![lineStr containsString:@"<"] &&
        [lineStr containsString:@"#import"]) {
        return YES;
    }
    return NO;
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}
- (IBAction)findBtnClicked:(id)sender {
    [self.progressIndicator startAnimation:self];
//    NSString *folderPath = @"/Users/yxj/Desktop/NewCarpool/CarpoolBusiness/Pod/Classes/Kit/DCFundationKit/Component/OrderList/ShoppingCart/view/";
    NSString *folderPath =self.toCheckFolderPathTextField.stringValue;
    //@"/Users/yxj/Desktop/20180511Blord/CarpoolBusiness/Pod/Classes/Business/Mine/Header/actions/";
    if (![folderPath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].length) {
        [self showAlertWithStyle:NSAlertStyleWarning title:@"请选择要检查的文件夹" subtitle:@"比如：/Users/yxj/Desktop/20180511Blord/CarpoolBusiness/Pod/Classes/Business/Mine"];
        return;
    }
    NSString *workspace = self.dotXcworkspacePathTextField.stringValue;
    if (![workspace hasSuffix:@".xcworkspace"]) {
//        [self showAlertWithStyle:NSAlertStyleInformational title:@"选择正确的 .xcworkspac 文件" subtitle:@"比如：/Users/yxj/Desktop/20180511Blord/OneTravel.xcworkspace"];
//        return;
    }
    NSArray *suffixs = @[@"h", @"m", @"mm"];
    NSArray *pathList = [self resourceFilesInDirectory:folderPath excludeFolders:nil resourceSuffixs:suffixs];
    for (NSString *filePath in pathList) {
        self.handlingFilenameLabel.stringValue = [NSString stringWithFormat:@"Handling %@...", filePath];
        [self handleOneFile:filePath];
    }
    [self.progressIndicator stopAnimation:self];
    self.handlingFilenameLabel.stringValue = @"Finished.";
    
    //读取所有的文件列表
    //读取所有自定义类存到一个集合里（把文件列表中后缀为 .h 的取出来)
}

- (BOOL)canXcodeProjBuildSuccess {
    //xcodebuild -workspace /Users/yxj/Desktop/20180511Blord/OneTravel.xcworkspace -configuration Debug -scheme OneTravel SYMROOT="/Users/yxj/Desktop/UnusedImport" GCC_PREPROCESSOR_DEFINITIONS='$GCC_PREPROCESSOR_DEFINITIONS API_TYPE=1' build
    NSInteger start = [self p_currentTime];
    NSInteger end;
    NSString *workspace = self.dotXcworkspacePathTextField.stringValue;
    if (!workspace.length) {
        workspace = @"/Users/yxj/Desktop/20180511Blord/OneTravel.xcworkspace";
    }
    
    NSString *configuration = @"Debug";
    NSString *scheme = @"OneTravel";
    NSString *symroot = @"SYMROOT=/Users/yxj/Desktop/UnusedImportCheckOutput";
    if (self.symrootTextField.stringValue.length) {
        symroot = [NSString stringWithFormat:@"SYMROOT=%@/UnusedImportCheckOutput", self.symrootTextField.stringValue];
    }
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath: @"/usr/bin/xcodebuild"];
    NSMutableArray *argvals = [NSMutableArray array];
    [argvals addObject:@"-workspace"];
    [argvals addObject:workspace];
    [argvals addObject:@"-configuration"];
    [argvals addObject:configuration];
    [argvals addObject:@"-scheme"];
    [argvals addObject:scheme];
    [argvals addObject:symroot];
    [argvals addObject:@"build"];
    NSString *pchMacor = @"GCC_PREPROCESSOR_DEFINITIONS='$GCC_PREPROCESSOR_DEFINITIONS DCARPOOL_IS_PSG=1 DCARPOOL_IS_BLORD=1'";
    [argvals addObject:pchMacor];
    
    [task setArguments: argvals];
    
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    NSFileHandle *file = [pipe fileHandleForReading];
    
    // Run task
    [task launch];
    
    // Read the response
    NSData *data = [file readDataToEndOfFile];
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if ([string containsString:@"BUILD SUCCEEDED"]) {
        end = [self p_currentTime];
        NSLog(@"BUILD SUCCEEDED : %lds", end-start);
        return YES;
    } else {
        end = [self p_currentTime];
        NSLog(@"BUILD FAILED: %lds", end - start);
        return NO;
    }
}

- (NSInteger)p_currentTime {
    return (NSInteger)[[NSDate date] timeIntervalSince1970];
}

- (NSArray *)resourceFilesInDirectory:(NSString *)directoryPath excludeFolders:(NSArray *)excludeFolders resourceSuffixs:(NSArray *)suffixs {
    NSMutableArray *resources = [NSMutableArray array];
    for (NSString *fileType in suffixs) {
        NSArray *pathList = [self searchDirectory:directoryPath excludeFolders:excludeFolders forFiletype:fileType];
        if (pathList.count) {
            [resources addObjectsFromArray:pathList];
        }
    }
    return resources;
}


- (NSArray *)searchDirectory:(NSString *)directoryPath excludeFolders:(NSArray *)excludeFolders forFiletype:(NSString *)filetype {
    // Create a find task
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath: @"/usr/bin/find"];
    
    // Search for all files
    NSMutableArray *argvals = [NSMutableArray array];
    [argvals addObject:directoryPath];
    [argvals addObject:@"-name"];
    [argvals addObject:[NSString stringWithFormat:@"*.%@", filetype]];
    
    for (NSString *folder in excludeFolders) {
        [argvals addObject:@"!"];
        [argvals addObject:@"-path"];
        [argvals addObject:[NSString stringWithFormat:@"*/%@/*", folder]];
    }
    
    [task setArguments: argvals];
    
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    NSFileHandle *file = [pipe fileHandleForReading];
    
    // Run task
    [task launch];
    
    // Read the response
    NSData *data = [file readDataToEndOfFile];
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    // See if we can create a lines array
    if (string.length) {
        NSArray *lines = [string componentsSeparatedByString:@"\n"];
        NSMutableArray *linesM = [lines mutableCopy];//去掉最后一行空行
        [linesM removeLastObject];
        return [linesM copy];
    }
    return nil;
}

- (void)showAlertWithStyle:(NSAlertStyle)style title:(NSString *)title subtitle:(NSString *)subtitle {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = style;
    [alert setMessageText:title];
    [alert setInformativeText:subtitle];
    [alert runModal];
}

#pragma mark - storyboard
- (IBAction)dotXcworkspacePathBrowserBtn:(id)sender {
    // Show an open panel
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setCanChooseFiles:YES];
    openPanel.allowsMultipleSelection = NO;
    openPanel.allowedFileTypes = @[@"xcworkspace"];
    
    BOOL okButtonPressed = ([openPanel runModal] == NSModalResponseOK);
    if (okButtonPressed) {
        // Update the path text field
        NSString *path = [[openPanel URL] path];
        [self.dotXcworkspacePathTextField setStringValue:path];
    }
}

- (IBAction)toCheckFolderBrowserBtn:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setCanChooseFiles:NO];
    openPanel.allowsMultipleSelection = NO;
    
    BOOL okButtonPressed = ([openPanel runModal] == NSModalResponseOK);
    if (okButtonPressed) {
        // Update the path text field
        NSString *path = [[openPanel URL] path];
        [self.toCheckFolderPathTextField setStringValue:path];
    }
}

- (IBAction)symrootPathBrowserBtn:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setCanChooseFiles:NO];
    openPanel.allowsMultipleSelection = NO;
    
    BOOL okButtonPressed = ([openPanel runModal] == NSModalResponseOK);
    if (okButtonPressed) {
        // Update the path text field
        NSString *path = [[openPanel URL] path];
        [self.symrootTextField setStringValue:path];
    }
}


@end
