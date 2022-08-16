// Copyright 2022 The E-Dutainment Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "BetterPlayerSwankmpDrmAssetsLoaderDelegate.h"

@implementation BetterPlayerSwankmpDrmAssetsLoaderDelegate

NSString *_assetId;

//Swankmp LICENSE DRM
NSString * DEFAULT_SWANKMP_LICENSE_SERVER_URL = @"https://fairplay.swankmp.net/api/v1/license";

- (instancetype)init:(NSURL *)certificateURL withLicenseURL:(NSURL *)licenseURL
    withHeaders:(NSDictionary *)headers{

    self = [super init];
    _certificateURL = certificateURL;
    _licenseURL = licenseURL;
    _headers = [[NSMutableDictionary alloc] init];

    for(id key in headers) {
        [_headers setObject:headers[key] forKey:key];
        NSLog(@"%@:%@", headers[key], key);
        NSLog(@"Swankmp Inits")
    }
    
    return self;
}

/*------------------------------------------
 **
 ** getContentLicense
 **
 ** ---------------------------------------*/
- (NSData *)getContentLicense:(NSData*)requestBytes and:(NSString *)assetId and:(NSDictionary *)headers and:(NSError *)errorOut {
    NSData * decodedData;
    NSURLResponse * response;
    
    NSLog(@"🔑 receive AssetID: %@", assetId);

    NSURL * finalLicenseURL;
    if ([_licenseURL checkResourceIsReachableAndReturnError:nil] == NO) {
        finalLicenseURL = _licenseURL;
    } else {
        finalLicenseURL = [[NSURL alloc] initWithString: DEFAULT_SWANKMP_LICENSE_SERVER_URL];
    }
    
    NSURL * requestURL = [[NSURL alloc] initWithString:finalLicenseURL];
    
    NSMutableURLRequest * request = [[NSMutableURLRequest alloc] initWithURL:requestURL];
    
    NSString * swankmpSpc = [NSString stringWithFormat:@"spc=%@", [requestBytes base64EncodedStringWithOptions:0]];
    NSData * data = [swankmpSpc dataUsingEncoding:NSUTF8StringEncoding];

    
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-type"];
    [request setHTTPBody:data];

    for (NSString* key in headers) {
        [request setValue:headers[key] forHTTPHeaderField:key];
    }

    @try {
        NSData * data = [self sendSynchronousRequest:request returningResponse:&response error:nil];
        decodedData = [[NSData alloc] initWithBase64EncodedData:data options:NSDataBase64DecodingIgnoreUnknownCharacters];
    }
    @catch (NSException* excp) {
        NSLog(@"SDK Error, SDK responded with Error: (getContentLicense)");
    }

    NSLog(@"🔑 CKC: %@", decodedData.count);
    return decodedData;
}

/*------------------------------------------
 **
 ** getAppCertificate
 **
 ** ---------------------------------------*/
- (NSData *)getAppCertificate:(NSString *) String {
    NSData * certificate = nil;
    certificate = [NSData dataWithContentsOfURL:_certificateURL];
    return certificate;
}

- (NSData *)sendSynchronousRequest:(NSURLRequest *)request returningResponse:(NSURLResponse **)response error:(NSError **)error
{
    NSError __block *err = NULL;
    NSData __block *data;
    BOOL __block reqProcessed = false;
    NSURLResponse __block *resp;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable _data, NSURLResponse * _Nullable _response, NSError * _Nullable _error) {
        resp = _response;
        err = _error;
        _ckcStrData = [[NSString alloc] initWithData:_data encoding:NSUTF8StringEncoding];
        _ckcStr = _ckcStrData.dropFirst(5).dropLast(6);
        data = [[NSData alloc] initWithBase64EncodedData:_ckcStr options:NSDataBase64DecodingIgnoreUnknownCharacters]; //DATA TO CKC
        reqProcessed = true;
        dispatch_semaphore_signal(semaphore);
        }] resume];

    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    if (response != nil)
        *response = resp;
    if (error != nil)
        *error = err;
    
    return data;
}

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
    NSURL *assetURI = loadingRequest.request.URL;
    
    NSString * fullAssetID = assetURI.absoluteString;
    NSString * assetIDString = [fullAssetID dropFirst:6];
    NSData * assetIDData = [assetIDString dataUsingEncoding:NSUTF8StringEncoding];
    _assetId = assetIDString;
    
    NSLog(@"Resource Loader, 🔑 receive AssetID: %@", assetId);
    
    NSString * scheme = assetURI.scheme;
    NSData * requestBytes;
    NSData * certificate;
    
    if (!([scheme isEqualToString: @"skd"])){
        return NO;
    }
    @try {
        certificate = [self getAppCertificate:_assetId];
    }
    @catch (NSException* excp) {
        NSLog(@"Resource Loader, SDK responded with Error: (getAppCertificate)");
        [loadingRequest finishLoadingWithError:[[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorClientCertificateRejected userInfo:nil]];
    }

    @try {
        requestBytes = [loadingRequest streamingContentKeyRequestDataForApp:certificate contentIdentifier:assetIDData options:[AVContentKeyRequestProtocolVersionsKey: [1]] error:nil];
    }
    @catch (NSException* excp) {
        NSLog(@"Resource Loader, SDK responded with Error: (finishLoadingWithError)");
        [loadingRequest finishLoadingWithError:nil];
        return YES;
    }

    NSData * responseData;
    NSError * error;

    responseData = [self getContentLicense:requestBytes and:_assetId and:_headers and:error];

    if (responseData != nil && responseData != NULL && ![responseData.class isKindOfClass:NSNull.class]){
        AVAssetResourceLoadingDataRequest * dataRequest = loadingRequest.dataRequest;
        [dataRequest respondWithData:responseData];
        [loadingRequest finishLoading];
    } else {
        [loadingRequest finishLoadingWithError:error];
    }

    return YES;
}

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForRenewalOfRequestedResource:(AVAssetResourceRenewalRequest *)renewalRequest {
    return [self resourceLoader:resourceLoader shouldWaitForLoadingOfRequestedResource:renewalRequest];
}

@end
