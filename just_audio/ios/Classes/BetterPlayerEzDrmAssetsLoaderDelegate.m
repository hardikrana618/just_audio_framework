#import "BetterPlayerEzDrmAssetsLoaderDelegate.h"

@implementation BetterPlayerEzDrmAssetsLoaderDelegate

NSString *_assetId;

NSString * DEFAULT_LICENSE_SERVER_URL = @"https://fps.ezdrm.com/api/licenses/";

- (instancetype)init:(NSURL *)certificateURL withLicenseURL:(NSURL *)licenseURL{
    self = [super init];
    _certificateURL = certificateURL;
    _licenseURL = licenseURL;
    return self;
}

/*------------------------------------------
 **
 ** getContentKeyAndLeaseExpiryFromKeyServerModuleWithRequest
 **
 ** Takes the bundled SPC and sends it to the license server defined at licenseUrl or KEY_SERVER_URL (if licenseUrl is null).
 ** It returns CKC.
 ** ---------------------------------------*/
- (NSData *)getContentKeyAndLeaseExpiryFromKeyServerModuleWithRequest:(NSData*)requestBytes and:(NSString *)assetId and:(NSString *)customParams and:(NSError *)errorOut {
    NSData * decodedData;
    NSURLResponse * response;
    
    NSURL * finalLicenseURL;
    if (_licenseURL != [NSNull null]){
        finalLicenseURL = _licenseURL;
    } else {
        finalLicenseURL = [[NSURL alloc] initWithString: DEFAULT_LICENSE_SERVER_URL];
    }
    NSURL * ksmURL = [[NSURL alloc] initWithString: [NSString stringWithFormat:@"%@%@%@",finalLicenseURL,assetId,customParams]];
    
    NSMutableURLRequest * request = [[NSMutableURLRequest alloc] initWithURL:ksmURL];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-type"];
    [request setHTTPBody:requestBytes];
    
    @try {
        decodedData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:nil];
    }
    @catch (NSException* excp) {
        NSLog(@"SDK Error, SDK responded with Error: (error)");
    }
    return decodedData;
}

/*------------------------------------------
 **
 ** getAppCertificate
 **
 ** returns the apps certificate for authenticating against your server
 ** the example here uses a local certificate
 ** but you may need to edit this function to point to your certificate
 ** ---------------------------------------*/
- (NSData *)getAppCertificate:(NSString *) String {
    NSData * certificate = nil;
    certificate = [NSData dataWithContentsOfURL:_certificateURL];
    return certificate;
}

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
    NSLog(@"*********** resourceLoader");
    return [self avResourceLoader:resourceLoader loadingRequest:loadingRequest];
}

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForRenewalOfRequestedResource:(AVAssetResourceRenewalRequest *)renewalRequest {
    return [self resourceLoader:resourceLoader shouldWaitForLoadingOfRequestedResource:renewalRequest];
}

- (BOOL)avResourceLoader:(AVAssetResourceLoader *)resourceLoader
         loadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
           {
    NSLog(@"*************** avResourceLoader 00 %@", _certificateURL.path);
    NSURL *url = loadingRequest.request.URL;
    if (!url) {
        NSLog(@"Unable to read URL from loadingRequest");
        [loadingRequest finishLoadingWithError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
        return NO;
    }
    NSLog(@"*************** avResourceLoader 01");
    
    NSData *certificateData = [NSData dataWithContentsOfURL:_certificateURL];
    if (!certificateData) {
        NSLog(@"Unable to read the certificate data.");
        [loadingRequest finishLoadingWithError:[NSError errorWithDomain:@"" code:-2 userInfo:nil]];
        return NO;
    }
    NSLog(@"*************** avResourceLoader 02");
    
    NSString *contentId = url.host;
    NSData *contentIdData = [contentId dataUsingEncoding:NSUTF8StringEncoding];
    NSData *spcData = [loadingRequest streamingContentKeyRequestDataForApp:certificateData contentIdentifier:contentIdData options:nil error:nil];
    if (!spcData) {
        NSLog(@"Unable to read the SPC data.");
        [loadingRequest finishLoadingWithError:[NSError errorWithDomain:@"" code:-3 userInfo:nil]];
        return NO;
    }
    NSLog(@"*************** avResourceLoader 03 %@",_licenseURL.path);
    NSString *stringBody = [NSString stringWithFormat:@"spc=%@&assetId=%@", [spcData base64EncodedStringWithOptions:0], contentId ?: @""];
    NSData *postData = [stringBody dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:_licenseURL];
    request.HTTPMethod = @"POST";
    request.HTTPBody = postData;
    [request setValue:@"YOUR AUTHENTICATION XML IN BASE64 FORMAT HERE" forHTTPHeaderField:@"customdata"];
    
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (data) {
            NSLog(@"*************** avResourceLoader 08");
            NSError *jsonError;
            NSDictionary *parsedData = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if (jsonError) {
                NSLog(@"The response may be a license. Moving on.");
            } else {
                NSString *errorId = parsedData[@"errorid"];
                NSString *errorMsg = parsedData[@"errormsg"];
                NSLog(@"License request failed with an error: %@ [%@]", errorMsg, errorId);
            }
            
            NSData *ld = [[NSData alloc] initWithBase64EncodedData:data options:0];
            [loadingRequest.dataRequest respondWithData:ld];
            [loadingRequest finishLoading];
        } else {
            NSLog(@"%@", error.localizedDescription ?: @"Error during CKC request.");
        }
    }];
    
    NSLog(@"*************** avResourceLoader 13");
    [task resume];
    
    return YES;
}

@end
