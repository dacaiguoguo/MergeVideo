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
@property (nonatomic, strong) UIActivityIndicatorView *loadingView;
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
        pview.frame = CGRectMake(0, 40, self.view.bounds.size.width, 10);
    }
    NSURL *obj = self.mp4Array[indexPath.row];
    cell.textLabel.text = obj.description;
    UIProgressView *pview = [cell.contentView viewWithTag:102];
    if ([obj isKindOfClass:NSProgress.class]){
        pview.observedProgress = (NSProgress *)obj;
    }
    if ([obj isKindOfClass:NSURL.class]){
        pview.observedProgress = nil;
        [pview setProgress:1.0 animated:NO];
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
    self.loadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:(UIActivityIndicatorViewStyleLarge)];
    [self.view addSubview:self.loadingView];
    _loadingView.center = self.view.center;
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
        // ???????????????????????????????????????????????????????????????????????????????????????null ????????????????????????????????????null???
        self.mp4Array = results.mutableCopy;
        [self.tableView reloadData];
        [results enumerateObjectsUsingBlock:^(PHPickerResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            // Your program should copy or move the file within the completion handler.
            // ?????????block???copy??????move?????? ??????block???????????????????????????
            NSProgress *logp = [obj.itemProvider loadFileRepresentationForTypeIdentifier:UTTypeMovie.identifier
                                                                       completionHandler:^(NSURL * _Nullable item, NSError * _Nullable error) {
                NSFileManager *fileManager = [NSFileManager defaultManager];
                NSError *err = nil;
                NSURL *docUrl = [fileManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&err];
                NSURL *wurl = [docUrl URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4", @(idx)]];
                [fileManager removeItemAtURL:wurl error:&err];
                [fileManager copyItemAtURL:item toURL:wurl error:&err];
                NSLog(@"????????????%@", NSThread.currentThread);
                // completionHandler ???????????? ??????????????????????????????????????????
                dispatch_sync(dispatch_get_main_queue(), ^{
                    // ?????????????????????????????????????????????????????????
                    [self.mp4Array replaceObjectAtIndex:idx withObject:wurl];
                    [self.tableView reloadData];
                    BOOL hasNull = NO;
                    // ?????????????????? null
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
            NSLog(@"??????logp%@", logp);
            [self.mp4Array replaceObjectAtIndex:idx withObject:logp];
            [self.tableView reloadData];
        }];
    }];
}

- (void)mergeAndShare {
    [self.loadingView startAnimating];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *err = nil;
    NSURL *docUrl = [fileManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&err];
    // ????????????????????????
    NSLog(@"dacaiguoguo????????????");

    NSURL *destDirectory = [docUrl URLByAppendingPathComponent:@"join"];
    if ([fileManager fileExistsAtPath:destDirectory.path isDirectory:nil]) {
        [fileManager removeItemAtURL:destDirectory error:&err];
    }
    [fileManager createDirectoryAtURL:destDirectory withIntermediateDirectories:YES attributes:nil error:&err];
    NSURL *outputFileUrl = [[docUrl URLByAppendingPathComponent:@"join"] URLByAppendingPathComponent:@"??????????????????.mp4"];


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
        NSLog(@"dacaiguoguo: %li\n", (long)status);
        if (status == AVAssetExportSessionStatusCompleted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                //????????????????????? ???????????????????????? ?????????????????????
                NSArray *activityItems = @[outputFileUrl];
                // ????????????vc
                UIActivityViewController *activityVC = [[UIActivityViewController alloc]initWithActivityItems:activityItems applicationActivities:nil];
                // ?????????????????????????????????
                activityVC.excludedActivityTypes =
                @[UIActivityTypePrint,UIActivityTypeMessage,UIActivityTypeMail,
                  UIActivityTypePrint,UIActivityTypeAddToReadingList,UIActivityTypeOpenInIBooks,
                  UIActivityTypeCopyToPasteboard,UIActivityTypeAssignToContact];

                [self presentViewController:activityVC animated:YES completion:^{
                    [self.loadingView stopAnimating];
                }];
                // ?????????????????????
                activityVC.completionWithItemsHandler = ^(UIActivityType  _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError) {
                    if (completed) {
                        //?????? ??????
                    } else  {
                        //?????? ??????
                    }
                };
            });
        }
    }];
}
/**
 *  ???????????????????????????
 *
 *  @param array ???????????????NSURL??????
 *
 *  @return ??????AVMutableComposition
 */
-(AVMutableComposition *)mergeVideostoOneVideo:(NSArray<NSURL *>*)array {
    AVMutableComposition* mixComposition = [AVMutableComposition composition];
    AVMutableCompositionTrack *compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *compositionAudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];


    [array enumerateObjectsUsingBlock:^(NSURL * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        Float64 tmpDuration = CMTimeGetSeconds(mixComposition.duration);
        /**
         *  ??????????????????asset
         *
         *  TimeRange ?????????asset????????????
         *  Track     ?????????asset??????,????????????video
         *  Time      ????????????????????????asset,????????????CMTime?????????CMTimeMakeWithSeconds(tmpDuration, 0),timesacle???0
         *
         */
        AVURLAsset *videoAsset = [[AVURLAsset alloc] initWithURL:obj options:nil];
        CMTimeRange video_timeRange = CMTimeRangeMake(kCMTimeZero, videoAsset.duration);
        //??????????????????
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
