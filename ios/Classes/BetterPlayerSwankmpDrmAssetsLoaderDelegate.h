// Copyright 2022 The E-Dutainment Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <Foundation/Foundation.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>

@interface BetterPlayerSwankmpDrmAssetsLoaderDelegate : NSObject

@property(readonly, nonatomic) NSURL* certificateURL;
@property(readonly, nonatomic) NSURL* licenseURL;
@property(readonly, nonatomic) NSMutableDictionary* headers;

- (instancetype)init:(NSURL *)certificateURL withLicenseURL:(NSURL *)licenseURL
    withHeaders:(NSDictionary *)headers;

@end
