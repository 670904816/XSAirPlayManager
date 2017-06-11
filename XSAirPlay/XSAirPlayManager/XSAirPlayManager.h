//
//  XSAirPlayManager.h
//  YouKu
//
//  Created by OSX on 17/1/19.
//  Copyright © 2017年 OSX. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GCDAsyncSocket.h>
#import "XSAirPlayModel.h"
#import <UIKit/UIKit.h>
@interface XSAirPlayManager : NSObject<GCDAsyncSocketDelegate,NSNetServiceDelegate,NSNetServiceBrowserDelegate>
{
    NSMutableArray *foundServices;
    NSNetService *netService;
    NSNetServiceBrowser *airPlayBrowser;
    GCDAsyncSocket *socket;
    BOOL status;
    NSString *connectedHost;
}
+ (XSAirPlayManager *)sharedInstance;

@property(nonatomic,strong)NSMutableArray *devicesArr;
-(void)startSearch;
-(void)stopSearch;
-(void)connectDevice:(NSString*)ip width:(UInt16)port;
-(void)sendRawData:(NSData *)data;
-(void)sendRawMessage:(NSString *)message; // Sends a raw HTTP string over Airplay.
-(void)sendContentURL:(NSString *)url;
-(void)sendImage:(UIImage *)image;
-(void)sendImage:(UIImage *)image forceReady:(BOOL)ready;
-(void)sendStop;
-(void)sendReverse;
-(void)setScrub:(float)seconds;
-(void)getScrub;
-(void)setRate:(BOOL)playState;
-(void)getVolume;
-(void)setVolume:(float)volume;
-(void)getPlaybackInfo;
-(void)getServerInfo;
-(BOOL)getDeviceStatus;
-(NSString*)getDeviceIp;
@end
