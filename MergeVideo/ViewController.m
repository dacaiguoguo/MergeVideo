//
//  ViewController.m
//  ChaImage
//
//  Created by yanguo sun on 2023/2/17.
//

#import "ViewController.h"
@import AVFoundation;
@import PhotosUI;
@import MobileCoreServices;
@import UniformTypeIdentifiers;

@interface ViewController ()<PHPickerViewControllerDelegate, UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) NSMutableArray *mp4Array;
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation ViewController
#pragma mark tableView lazy
-(UITableView *)tableView {
    if (!_tableView) {
        _tableView = [[UITableView alloc]initWithFrame:self.view.bounds style:UITableViewStylePlain];
        _tableView.delegate = self;
        _tableView.dataSource = self;
    }
    return _tableView;
}

#pragma tableView UITableViewDataSource
-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.mp4Array.count;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"identifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identifier];
        UIProgressView *pview = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        [cell.contentView addSubview:pview];
        pview.tag = 102;
        pview.frame = CGRectMake(0, 0, self.view.bounds.size.width, 10);
    }
    NSURL *obj = self.mp4Array[indexPath.row];
    cell.textLabel.text = obj.description;
    UIProgressView *pview = [cell.contentView viewWithTag:102];
    if ([obj isKindOfClass:NSProgress.class]){
        pview.observedProgress = (NSProgress *)obj;
    }
    if ([obj isKindOfClass:NSURL.class]){
        pview.observedProgress = nil;
        [pview setProgress:0.0 animated:NO];
        cell.textLabel.text = obj.path.lastPathComponent;
    }
    return cell;
}

#pragma tableView--UITableViewDelegate
-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.mp4Array = [NSMutableArray array];
    [self.view addSubview:self.tableView];
    _tableView.frame = self.view.bounds;
    NSLog(@"%@", NSHomeDirectory());
    if (@available(iOS 14, *)) {
        PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
        config.selectionLimit = 100;
        config.filter = PHPickerFilter.videosFilter;
        config.preferredAssetRepresentationMode = PHPickerConfigurationAssetRepresentationModeAutomatic;
        PHPickerViewController *pvc = [[PHPickerViewController alloc] initWithConfiguration:config];
        pvc.delegate = self;
        [self presentViewController:pvc animated:YES completion:^{

        }];
    }
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:^{
        [self.mp4Array removeAllObjects];
        // 由于后面获取视频是异步操作，为了判断是否全部获取，先全部用null 对象填充，再判断是否包含null。
        [results enumerateObjectsUsingBlock:^(PHPickerResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [self.mp4Array addObject:[NSNull null]];
        }];
        [self.tableView reloadData];
        [results enumerateObjectsUsingBlock:^(PHPickerResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            // Your program should copy or move the file within the completion handler.
            // 需要在block内copy或者move文件 因为block执行后文件会被删除
            NSProgress *logp = [obj.itemProvider loadFileRepresentationForTypeIdentifier:UTTypeMovie.identifier
                                                                       completionHandler:^(NSURL * _Nullable item, NSError * _Nullable error) {
                NSFileManager *fileManager = [NSFileManager defaultManager];
                NSError *err = nil;
                NSURL *docUrl = [fileManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&err];
                NSURL *wurl = [docUrl URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4", @(idx)]];
                [fileManager removeItemAtURL:wurl error:&err];
                [fileManager copyItemAtURL:item toURL:wurl error:&err];
                NSLog(@"等待合并%@", NSThread.currentThread);
                // completionHandler 在不同的 线程，是否考虑线程安全问题？
                dispatch_sync(dispatch_get_main_queue(), ^{
                    // 总是在主线程操作可变数组，保证结果正确
                    [self.mp4Array replaceObjectAtIndex:idx withObject:wurl];
                    [self.tableView reloadData];
                    BOOL hasNull = NO;
                    // 检查是否存在 null
                    for (id item in self.mp4Array) {
                        if(![item isKindOfClass:NSURL.class]) {
                            hasNull = YES;
                        }
                    }

                    if (!hasNull) {
                        [self mergeAndShare];
                    }
                });

            }];
            NSLog(@"等待logp%@", logp);
            [self.mp4Array replaceObjectAtIndex:idx withObject:logp];
            [self.tableView reloadData];
        }];
    }];
}

- (void)mergeAndShare {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *err = nil;
    NSURL *docUrl = [fileManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&err];
    // 都取到了，就合并
    NSLog(@"开始合并");
    NSURL *destDirectory = [docUrl URLByAppendingPathComponent:@"join"];
    if ([fileManager fileExistsAtPath:destDirectory.path isDirectory:nil]) {
        [fileManager removeItemAtURL:destDirectory error:&err];
    }
    [fileManager createDirectoryAtURL:destDirectory withIntermediateDirectories:YES attributes:nil error:&err];
    NSURL *outputFileUrl = [[docUrl URLByAppendingPathComponent:@"join"] URLByAppendingPathComponent:@"合并后的视频.mp4"];


    AVMutableComposition *mixComposition = [self mergeVideostoOneVideo:self.mp4Array];
    AVAssetExportSession* _assetExport = [AVAssetExportSession exportSessionWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];
    NSLog(@"%@", [_assetExport supportedFileTypes]);
    /*
     (
     "com.apple.quicktime-movie",
     "public.mpeg-4",
     "com.apple.m4v-video"
     )
     */
    // _assetExport.outputFileType = @"com.apple.quicktime-movie";
    _assetExport.outputFileType = @"public.mpeg-4";
    _assetExport.outputURL = outputFileUrl;
    [_assetExport exportAsynchronouslyWithCompletionHandler:^{
        AVAssetExportSessionStatus  status = _assetExport.status;
        NSLog(@"exportAsynchronouslyWithCompletionHandler: %li\n", (long)status);
        if (status == AVAssetExportSessionStatusCompleted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                //如果想分享图片 就把图片添加进去 文字什么的同上
                NSArray *activityItems = @[outputFileUrl];
                // 创建分享vc
                UIActivityViewController *activityVC = [[UIActivityViewController alloc]initWithActivityItems:activityItems applicationActivities:nil];
                // 设置不出现在活动的项目
                activityVC.excludedActivityTypes =
                @[UIActivityTypePrint,UIActivityTypeMessage,UIActivityTypeMail,
                  UIActivityTypePrint,UIActivityTypeAddToReadingList,UIActivityTypeOpenInIBooks,
                  UIActivityTypeCopyToPasteboard,UIActivityTypeAssignToContact];

                [self presentViewController:activityVC animated:YES completion:nil];
                // 分享之后的回调
                activityVC.completionWithItemsHandler = ^(UIActivityType  _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError) {
                    if (completed) {
                        //分享 成功
                    } else  {
                        //分享 取消
                    }
                };
            });
        }
    }];
}
/**
 *  多个视频合成为一个
 *
 *  @param array 多个视频的NSURL地址
 *
 *  @return 返回AVMutableComposition
 */
-(AVMutableComposition *)mergeVideostoOneVideo:(NSArray<NSURL *>*)array {
    AVMutableComposition* mixComposition = [AVMutableComposition composition];
    AVMutableCompositionTrack *compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *compositionAudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];


    [array enumerateObjectsUsingBlock:^(NSURL * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        Float64 tmpDuration = CMTimeGetSeconds(mixComposition.duration);
        /**
         *  依次加入每个asset
         *
         *  TimeRange 加入的asset持续时间
         *  Track     加入的asset类型,这里都是video
         *  Time      从哪个时间点加入asset,这里用了CMTime下面的CMTimeMakeWithSeconds(tmpDuration, 0),timesacle为0
         *
         */
        AVURLAsset *videoAsset = [[AVURLAsset alloc] initWithURL:obj options:nil];
        CMTimeRange video_timeRange = CMTimeRangeMake(kCMTimeZero, videoAsset.duration);
        //素材的音频轨
        NSArray<AVAssetTrack *> *tt = [videoAsset tracksWithMediaType:AVMediaTypeAudio];
        AVAssetTrack *audioAssertTrack = tt.firstObject;
        if (audioAssertTrack) {
            [compositionAudioTrack insertTimeRange:video_timeRange ofTrack:audioAssertTrack atTime:CMTimeMakeWithSeconds(tmpDuration, 0) error:nil];
        }
        NSError *error;
        NSArray<AVAssetTrack *> *ttvideos = [videoAsset tracksWithMediaType:AVMediaTypeVideo];
        AVAssetTrack *videoTrack = ttvideos.firstObject;
        if (videoTrack) {
            __unused BOOL succcess = [compositionVideoTrack insertTimeRange:video_timeRange ofTrack:videoTrack atTime:CMTimeMakeWithSeconds(tmpDuration, 0) error:&error];
        }
    }];

    return mixComposition;
}


@end
