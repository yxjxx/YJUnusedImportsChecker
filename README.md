# 一种无用 import 的检查思路

暴力模拟人工检查无用 import 的做法：注释掉一行 import 看 build 能否通过，若能则可以注释掉，否则解开注释。

实现：关键点是程序如何知道一个工程 build 成功还是失败。想到 xcodebuild 命令，读了一下 manual 可以用下面的命令，和 Xcode 中 Commond+B 效果一样。

因为不想继续改进这个工具了，所以没有做的通用，仅提供一个思路。以下提到工程路径的地方需要修改为自己的。见谅 :(

```
xcodebuild -workspace /Users/yxj/Desktop/NewCarpool/OneTravel.xcworkspace 
-configuration Debug -scheme OneTravel SYMROOT="/Users/yxj/Desktop/UnusedImport" build
```

（根据自己的工程路径修改一下以上路径）

第一次编译耗时较长 OneTravel 可能需要十分钟，配置 SYMROOT 可以使用增量编译，之后一次成功的编译大概在 40-60s，失败编译的时间大概在 10-20s. 

思路有了之后，实现用 `NSTask` 加 `NSPipe` 来执行命令并获取输出即可

```objc
- (BOOL)canXcodeProjBuildSuccess {
    NSInteger start = [self p_currentTime];
    NSInteger end;
    NSString *workspace = @"/Users/yxj/Desktop/NewCarpool/OneTravel.xcworkspace";
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
        NSLog(@"BUILD SUCCEEDED : %ld", end-start);
        return YES;
    } else {
        end = [self p_currentTime];
        NSLog(@"BUILD FAILED: %ld", end - start);
        return NO;
    }
}
```

遍历工程目录取到所有的 .h 和 .m 文件，对每一个文件中每行 import 执行注释掉编译这一步

```objc
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
```

本方案优点：完全准确，理论上具备检查出所有无用 import 的能力。

本方案缺点：耗时太长(我们的工程大概 1100 个自定义类，耗时需约6小时），所以对大工程不具备完整可执行性（但是可以单独检查某一个较小的目录，比如购物车 10 个类耗时约半小时）。

去掉无用 import 的主要目的还是为了使用 projcheck 快速找出更多的无用类以有效的减少包大小。

所以本方案的改进可以做两件事情：

1. 提高编译速度：除要检查的模块外其他 pod 全部使用二进制集成；不输出 dsym 文件；使用增量编译；使用性能更强大的机器；Clang modules; 关闭一切可能的优化（仅支持 armv7，关闭编译优化即 Optimize level 改为 O0，使用虚拟内存）详细可参考：<https://bestswifter.com/improve_compile_speed/>
2. 减少需要判断的文件数：最简单的思路就是只检查我们自定义类并且如果一个类被注释导致了编译失败下次遇到就可以直接跳过。或者有其他较快的方案（比如基于文本静态检查）的输出一个可疑名单来检查。

## 其他检查无用 import 的方法

基于 [smck](https://github.com/ming1016/smck) 拆分的 token 来做无用 import 检查。

我们 import 一个头文件的目的使用它的 `#define`，字符串常量，属性，成员变量，实例方法，类方法，C方法或者它里面包含的其他文件里面的这些 token ，smck 拆分的 token 就包含这些信息，还需要加上 import 链（设计一个高效的数据结构存 importObj 的 所有 token 和它包含的其他 import 的所有 token）。

分两轮，第一轮取到所有的信息：对所有的自定义类，对它的每一个 import，递归取到它所有的 token（自己的 token 加 import 的别人的 token）。
第二轮对每个 importObj 看是否被当前类和它的子类们使用了，如果所有的 token 都没有被用到，说明是可疑的无用 import，输出列表，给上面的暴力法跑一遍。

## 暴力 build 法其他用途

检测无用类也很难做到 100% 准确也可以输出可疑列表给暴力 build 过一遍。


