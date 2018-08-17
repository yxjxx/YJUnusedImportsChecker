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
            NSString *str = [NSString stringWithFormat:@"//RICO COMMET %@", line];
            [mutableLines replaceObjectAtIndex:idx withObject:str];//注释掉
            [self writeBackToFile:mutableLines atPath:filePath];//写回
            BOOL buildSuccess = [self canXcodeProjBuildSuccess];//编译
            if (buildSuccess) {//如果编译通过，什么都不用做
                //do nothing
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
    NSString *folderPath = @"/Users/yxj/Desktop/20180511Blord/CarpoolBusiness/Pod/Classes/Business/Mine/Header/actions/";
    NSArray *suffixs = @[@"h", @"m"];
    NSArray *pathList = [self resourceFilesInDirectory:folderPath excludeFolders:nil resourceSuffixs:suffixs];
    for (NSString *filePath in pathList) {
        [self handleOneFile:filePath];
    }
    [self.progressIndicator stopAnimation:self];
    
    //读取所有的文件列表
    //读取所有自定义类存到一个集合里（把文件列表中后缀为 .h 的取出来)
}

- (BOOL)canXcodeProjBuildSuccess {
    //xcodebuild -workspace /Users/yxj/Desktop/NewCarpool/OneTravel.xcworkspace -configuration Debug -scheme OneTravel SYMROOT="/Users/yxj/Desktop/UnusedImport" build
    NSInteger start = [self p_currentTime];
    NSInteger end;
    NSString *workspace = @"/Users/yxj/Desktop/20180511Blord/OneTravel.xcworkspace";
    NSString *configuration = @"Debug";
    NSString *scheme = @"OneTravel";
    NSString *symroot = @"SYMROOT=/Users/yxj/Desktop/UnusedImport";
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

@end
