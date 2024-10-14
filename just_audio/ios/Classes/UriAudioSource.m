#import "UriAudioSource.h"
#import "IndexedAudioSource.h"
#import "IndexedPlayerItem.h"
#import "LoadControl.h"
#import <AVFoundation/AVFoundation.h>


@implementation UriAudioSource {
    NSString *_uri;
    IndexedPlayerItem *_playerItem;
    IndexedPlayerItem *_playerItem2;
    /* CMTime _duration; */
    LoadControl *_loadControl;
    NSMutableDictionary *_headers;
    NSDictionary *_options;
}

- (instancetype)initWithId:(NSString *)sid uri:(NSString *)uri loadControl:(LoadControl *)loadControl headers:(NSDictionary *)headers options:(NSDictionary *)options {
    self = [super initWithId:sid];
    NSAssert(self, @"super init cannot be nil");
    _uri = uri;
    _loadControl = loadControl;
    _headers = headers != (id)[NSNull null] ? [headers mutableCopy] : nil;
    _options = options;
    _playerItem = [self createPlayerItem:uri];
    _playerItem2 = nil;
    return self;
}

- (NSString *)uri {
    return _uri;
}

- (IndexedPlayerItem *)createPlayerItem:(NSString *)uri {
    IndexedPlayerItem *item;
    if ([uri hasPrefix:@"file://"]) {
        item = [[IndexedPlayerItem alloc] initWithURL:[NSURL fileURLWithPath:[[uri stringByRemovingPercentEncoding] substringFromIndex:7]]];
    } else {
        NSDictionary* headers = @{};
        NSURL* url = [NSURL URLWithString:uri];
        NSString* certificateURL = @"https://fp-keyos.licensekeyserver.com/cert/e7b25199f39945f79c689f6d7ebd1451.der";
        NSString* licenseURL = @"https://drm-auth.abantuaudio.com/?drm-type=fairplay";
        NSURL * certificateNSURL = [[NSURL alloc] initWithString: certificateURL];
        NSURL * licenseNSURL = [[NSURL alloc] initWithString: licenseURL];
        
        NSLog(@"createPlayerItem To Print 02");
        AVURLAsset* asset = [AVURLAsset URLAssetWithURL:url options:@{@"AVURLAssetHTTPHeaderFieldsKey" : headers}];
        _loaderDelegate = [[BetterPlayerEzDrmAssetsLoaderDelegate alloc] init:certificateNSURL withLicenseURL:licenseNSURL];
        dispatch_queue_attr_t qos = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_DEFAULT, -1);
        dispatch_queue_t streamQueue = dispatch_queue_create("streamQueue", qos);
        [asset.resourceLoader setDelegate:_loaderDelegate queue:streamQueue];
        NSLog(@"createPlayerItem To Print 03");
        item = [[IndexedPlayerItem alloc] initWithAsset:asset];
    }
    if (@available(macOS 10.13, iOS 11.0, *)) {
        // This does the best at reducing distortion on voice with speeds below 1.0
        item.audioTimePitchAlgorithm = AVAudioTimePitchAlgorithmTimeDomain;
    }
    if (@available(macOS 10.12, iOS 10.0, *)) {
        if (_loadControl.preferredForwardBufferDuration != (id)[NSNull null]) {
            item.preferredForwardBufferDuration = (double)([_loadControl.preferredForwardBufferDuration longLongValue]/1000) / 1000.0;
        }
    }
    if (@available(iOS 9.0, macOS 10.11, *)) {
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = _loadControl.canUseNetworkResourcesForLiveStreamingWhilePaused;
    }
    if (@available(iOS 8.0, macOS 10.10, *)) {
        if (_loadControl.preferredPeakBitRate != (id)[NSNull null]) {
            item.preferredPeakBitRate = [_loadControl.preferredPeakBitRate doubleValue];
        }
    }
    
    return item;
}

// Not used. XXX: Remove?
- (void)applyPreferredForwardBufferDuration {
    if (@available(macOS 10.12, iOS 10.0, *)) {
        if (_loadControl.preferredForwardBufferDuration != (id)[NSNull null]) {
            double value = (double)([_loadControl.preferredForwardBufferDuration longLongValue]/1000) / 1000.0;
            _playerItem.preferredForwardBufferDuration = value;
            if (_playerItem2) {
                _playerItem2.preferredForwardBufferDuration = value;
            }
        }
    }
}

- (void)applyCanUseNetworkResourcesForLiveStreamingWhilePaused {
    if (@available(iOS 9.0, macOS 10.11, *)) {
        _playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = _loadControl.canUseNetworkResourcesForLiveStreamingWhilePaused;
        if (_playerItem2) {
            _playerItem2.canUseNetworkResourcesForLiveStreamingWhilePaused = _loadControl.canUseNetworkResourcesForLiveStreamingWhilePaused;
        }
    }
}

- (void)applyPreferredPeakBitRate {
    if (@available(iOS 8.0, macOS 10.10, *)) {
        if (_loadControl.preferredPeakBitRate != (id)[NSNull null]) {
            double value = [_loadControl.preferredPeakBitRate doubleValue];
            _playerItem.preferredPeakBitRate = value;
            if (_playerItem2) {
                _playerItem2.preferredPeakBitRate = value;
            }
        }
    }
}

- (IndexedPlayerItem *)playerItem {
    return _playerItem;
}

- (IndexedPlayerItem *)playerItem2 {
    return _playerItem2;
}

- (NSArray<NSNumber *> *)getShuffleIndices {
    return @[@(0)];
}

- (void)play:(AVQueuePlayer *)player {
}

- (void)pause:(AVQueuePlayer *)player {
}

- (void)stop:(AVQueuePlayer *)player {
}

- (void)seek:(CMTime)position completionHandler:(void (^)(BOOL))completionHandler {
    if (!completionHandler || (_playerItem.status == AVPlayerItemStatusReadyToPlay)) {
        NSValue *seekableRange = _playerItem.seekableTimeRanges.lastObject;
        if (seekableRange) {
            CMTimeRange range = [seekableRange CMTimeRangeValue];
            position = CMTimeAdd(position, range.start);
        }
        [_playerItem seekToTime:position toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:completionHandler];
    } else {
        [super seek:position completionHandler:completionHandler];
    }
}

- (void)flip {
    IndexedPlayerItem *temp = _playerItem;
    _playerItem = _playerItem2;
    _playerItem2 = temp;
}

- (void)preparePlayerItem2 {
    if (!_playerItem2) {
        _playerItem2 = [self createPlayerItem:_uri];
        _playerItem2.audioSource = _playerItem.audioSource;
    }
}

- (CMTime)duration {
    NSValue *seekableRange = _playerItem.seekableTimeRanges.lastObject;
    if (seekableRange) {
        CMTimeRange seekableDuration = [seekableRange CMTimeRangeValue];
        return seekableDuration.duration;
    }
    else {
        return _playerItem.duration;
    }
    return kCMTimeInvalid;
}

- (void)setDuration:(CMTime)duration {
}

- (CMTime)position {
    NSValue *seekableRange = _playerItem.seekableTimeRanges.lastObject;
    if (seekableRange) {
        CMTimeRange range = [seekableRange CMTimeRangeValue];
        return CMTimeSubtract(_playerItem.currentTime, range.start);
    } else {
        return _playerItem.currentTime;
    }
    
}

- (CMTime)bufferedPosition {
    NSValue *last = _playerItem.loadedTimeRanges.lastObject;
    if (last) {
        CMTimeRange timeRange = [last CMTimeRangeValue];
        return CMTimeAdd(timeRange.start, timeRange.duration);
    } else {
        return _playerItem.currentTime;
    }
    return kCMTimeInvalid;
}

@end
