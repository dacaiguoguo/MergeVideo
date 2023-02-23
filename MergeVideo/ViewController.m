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

@interface ViewController ()<PHPickerViewControllerDelegate>
@property (nonatomic, strong) NSMutableArray *mp4Array;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.mp4Array = [NSMutableArray array];
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

        [results enumerateObjectsUsingBlock:^(PHPickerResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            // Your program should copy or move the file within the completion handler.
            // 需要在block内copy或者move文件 因为block执行后文件会被删除
            [obj.itemProvider loadFileRepresentationForTypeIdentifier:UTTypeMovie.identifier completionHandler:^(NSURL * _Nullable item, NSError * _Nullable error) {

                NSFileManager *fileManager = [NSFileManager defaultManager];
                NSError *err = nil;
                NSURL *docUrl = [fileManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&err];
                NSURL *wurl = [docUrl URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4", @(idx)]];
                [fileManager removeItemAtURL:wurl error:&err];
                [fileManager copyItemAtURL:item toURL:wurl error:&err];

                [self.mp4Array replaceObjectAtIndex:idx withObject:wurl];
                BOOL hasNull = NO;
                // 检查是否存在 null
                for (id item in self.mp4Array) {
                    if([item isKindOfClass:NSNull.class]) {
                        hasNull = YES;
                    }
                }

                NSLog(@"等待合并");
                if (!hasNull) {
                    // 都取到了，就合并
                    NSLog(@"开始合并");
                    [self mergeVideoToOneVideo:self.mp4Array toStorePath:@"join" WithStoreName:@"合并后的视频" success:^(NSURL *fileurl){
                        //如果想分享图片 就把图片添加进去 文字什么的同上
                        NSArray *activityItems = @[fileurl];
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


                    } failure:^{

                    }];


                }
            }];
            //            [obj.itemProvider loadItemForTypeIdentifier:UTTypeMovie.identifier options:nil completionHandler:^(NSURL *item, NSError * _Null_unspecified error) {
            //
            //            }];
        }];
    }];
}

/**
 *  多个视频合成为一个视频输出到指定路径,注意区分是否3D视频
 *
 *  @param tArray       视频文件NSURL地址
 *  @param storePath    沙盒目录下的文件夹
 *  @param storeName    合成的文件名字
 *  @param successBlock 成功block
 *  @param failureBlcok 失败block
 */
-(void)mergeVideoToOneVideo:(NSArray *)tArray toStorePath:(NSString *)storePath WithStoreName:(NSString *)storeName success:(void (^)(NSURL *fileurl))successBlock failure:(void (^)(void))failureBlcok
{
    AVMutableComposition *mixComposition = [self mergeVideostoOneVideo:tArray];
    NSURL *outputFileUrl = [self joinStorePath:storePath togetherStoreName:storeName];
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
                //在系统相册存储一份
                successBlock(outputFileUrl);
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
/**
 *  拼接url地址
 *
 *  @param sPath 沙盒文件夹名
 *  @param sName 文件名称
 *
 *  @return 返回拼接好的url地址
 */
-(NSURL *)joinStorePath:(NSString *)sPath togetherStoreName:(NSString *)sName {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentPath = [paths objectAtIndex:0];
    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSString *storePath = [documentPath stringByAppendingPathComponent:sPath];
    BOOL isExist = [fileManager fileExistsAtPath:storePath];
    if (isExist) {
        [fileManager removeItemAtPath:storePath error:nil];
    }
    [fileManager createDirectoryAtPath:storePath withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *realName = [NSString stringWithFormat:@"%@.mp4", sName];
    storePath = [storePath stringByAppendingPathComponent:realName];
    NSURL *outputFileUrl = [NSURL fileURLWithPath:storePath];
    return outputFileUrl;
}


@end
