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
        //        pvc.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:pvc animated:YES completion:^{

        }];
        //        [self.navigationController pushViewController:pvc animated:YES];
    }
    //    NSURL *url1 = [NSBundle.mainBundle URLForResource:@"22849_1676808731" withExtension:@"mp4"];
    //    NSURL *url2 = [NSBundle.mainBundle URLForResource:@"22850_1676808776" withExtension:@"mp4"];
    //    [self mergeVideoToOneVideo:@[url1, url2] toStorePath:@"join" WithStoreName:@"merge5" andIf3D:NO success:^{
    //
    //    } failure:^{
    //
    //    }];
    //    [[UIImage imageNamed:@"启动图-苹果-背景"] saveToURL:[NSURL fileURLWithPath:@"/Users/sunyanguo/Developer/tinified-4/logoaaa@3x.jpg"] type:NYXImageTypeJPEG backgroundFillColor:UIColor.systemPinkColor];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    //    [self.navigationController popViewControllerAnimated:YES];
    [picker dismissViewControllerAnimated:YES completion:^{
        [self.mp4Array removeAllObjects];
        for (__unused PHPickerResult *item in results) {
            [self.mp4Array addObject:[NSNull null]];
        }

        [results enumerateObjectsUsingBlock:^(PHPickerResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [obj.itemProvider loadFileRepresentationForTypeIdentifier:UTTypeMovie.identifier completionHandler:^(NSURL * _Nullable item, NSError * _Nullable error) {
                NSData *save1 =  [NSData dataWithContentsOfURL:item];
                NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
                NSString *documentPath = [paths objectAtIndex:0];
                NSURL *wurl = [NSURL fileURLWithPath:[documentPath stringByAppendingPathComponent:[NSString stringWithFormat:@"aaa%@.mp4", @(idx)]]];
                [save1 writeToURL:wurl atomically:YES];
                [self.mp4Array replaceObjectAtIndex:idx withObject:wurl];
                BOOL hasNull = NO;
                // 检查是否存在 null
                for (id item in self.mp4Array) {
                    if([item isKindOfClass:NSNull.class]) {
                        hasNull = YES;
                    }
                }

                NSLog(@"fff");
                if (!hasNull) {
                    // 都取到了，就合并
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self mergeVideoToOneVideo:self.mp4Array toStorePath:@"join" WithStoreName:@"merge6" andIf3D:NO success:^{

                        } failure:^{

                        }];
                    });

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
 *  @param tbool        是否3D视频,YES表示是3D视频
 *  @param successBlock 成功block
 *  @param failureBlcok 失败block
 */
-(void)mergeVideoToOneVideo:(NSArray *)tArray toStorePath:(NSString *)storePath WithStoreName:(NSString *)storeName andIf3D:(BOOL)tbool success:(void (^)(void))successBlock failure:(void (^)(void))failureBlcok
{
    AVMutableComposition *mixComposition = [self mergeVideostoOnevideo:tArray];
    NSURL *outputFileUrl = [self joinStorePaht:storePath togetherStoreName:storeName];
    [self storeAVMutableComposition:mixComposition withStoreUrl:outputFileUrl andVideoUrl:[tArray objectAtIndex:0] WihtName:storeName andIf3D:tbool success:successBlock failure:failureBlcok];
}
/**
 *  多个视频合成为一个
 *
 *  @param array 多个视频的NSURL地址
 *
 *  @return 返回AVMutableComposition
 */
-(AVMutableComposition *)mergeVideostoOnevideo:(NSArray*)array
{
    AVMutableComposition* mixComposition = [AVMutableComposition composition];
    AVMutableCompositionTrack *a_compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *audioCompositionTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    Float64 tmpDuration = 0.0;


    for (NSInteger i=0; i<array.count; i++)
    {

        AVURLAsset *videoAsset = [[AVURLAsset alloc]initWithURL:array[i] options:nil];
        CMTimeRange video_timeRange = CMTimeRangeMake(kCMTimeZero,videoAsset.duration);

        //素材的音频轨
        NSArray<AVAssetTrack *> *tt = [videoAsset tracksWithMediaType:AVMediaTypeAudio];
        AVAssetTrack *audioAssertTrack = tt.firstObject;
        if (audioAssertTrack) {
            [audioCompositionTrack insertTimeRange:video_timeRange ofTrack:audioAssertTrack atTime:CMTimeMakeWithSeconds(tmpDuration, 0) error:nil];
        }
        /**
         *  依次加入每个asset
         *
         *  TimeRange 加入的asset持续时间
         *  Track     加入的asset类型,这里都是video
         *  Time      从哪个时间点加入asset,这里用了CMTime下面的CMTimeMakeWithSeconds(tmpDuration, 0),timesacle为0
         *
         */

        NSError *error;
        NSArray<AVAssetTrack *> *ttvideos = [videoAsset tracksWithMediaType:AVMediaTypeVideo];
        AVAssetTrack *videoTrack = ttvideos.firstObject;
        if (videoTrack) {
            __unused BOOL succcess = [a_compositionVideoTrack insertTimeRange:video_timeRange ofTrack:videoTrack atTime:CMTimeMakeWithSeconds(tmpDuration, 0) error:&error];
        }

        tmpDuration += CMTimeGetSeconds(videoAsset.duration);

    }
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
-(NSURL *)joinStorePaht:(NSString *)sPath togetherStoreName:(NSString *)sName
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentPath = [paths objectAtIndex:0];
    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSString *storePath = [documentPath stringByAppendingPathComponent:sPath];
    BOOL isExist = [fileManager fileExistsAtPath:storePath];
    if(!isExist){
        [fileManager createDirectoryAtPath:storePath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *realName = [NSString stringWithFormat:@"%@.mp4", sName];
    storePath = [storePath stringByAppendingPathComponent:realName];
    NSURL *outputFileUrl = [NSURL fileURLWithPath:storePath];
    return outputFileUrl;
}
/**
 *  存储合成的视频
 *
 *  @param mixComposition mixComposition参数
 *  @param storeUrl       存储的路径
 *  @param successBlock   successBlock
 *  @param failureBlcok   failureBlcok
 */
-(void)storeAVMutableComposition:(AVMutableComposition*)mixComposition withStoreUrl:(NSURL *)storeUrl andVideoUrl:(NSURL *)videoUrl WihtName:(NSString *)aName andIf3D:(BOOL)tbool success:(void (^)(void))successBlock failure:(void (^)(void))failureBlcok
{
    AVAssetExportSession* _assetExport = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];
    //    _assetExport.outputFileType = @"com.apple.quicktime-movie";
    //    _assetExport.outputFileType = @"public.mpeg-4";
    _assetExport.outputFileType = UTTypeMovie.identifier;
    _assetExport.outputURL = storeUrl;
    [_assetExport exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            //在系统相册存储一份
            UISaveVideoAtPathToSavedPhotosAlbum([storeUrl path], nil, nil, nil);
            successBlock();
        });
    }];
}


@end
