#import "IndexedAudioSource.h"
#import "LoadControl.h"
#import <Flutter/Flutter.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import "BetterPlayerEzDrmAssetsLoaderDelegate.h"

@interface UriAudioSource : IndexedAudioSource
@property(readonly, nonatomic) BetterPlayerEzDrmAssetsLoaderDelegate* loaderDelegate;
@property (readonly, nonatomic) NSString *uri;

- (instancetype)initWithId:(NSString *)sid uri:(NSString *)uri loadControl:(LoadControl *)loadControl headers:(NSDictionary *)headers options:(NSDictionary *)options;
@end
