//
//  XSAirPlayManager.m
//  YouKu
//
//  Created by OSX on 17/1/19.
//  Copyright © 2017年 OSX. All rights reserved.
//

#import "XSAirPlayManager.h"
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netinet/in.h>
@implementation XSAirPlayManager
+ (XSAirPlayManager *)sharedInstance
{
    static XSAirPlayManager *sharedInstace = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,^{
        sharedInstace = [[self alloc] init];
    });
    return sharedInstace;
}
-(void)startSearch
{
    NSLog(@"%s",__func__);
    connectedHost = @"";
    foundServices = [NSMutableArray array];
    self.devicesArr = [NSMutableArray array];
    airPlayBrowser = [[NSNetServiceBrowser alloc] init];
    airPlayBrowser.delegate = self;
    [airPlayBrowser searchForServicesOfType:@"_airplay._tcp." inDomain:@"local."];
}

-(void)stopSearch
{
    [airPlayBrowser stop];
}
#pragma mark NSServiceBrowser Delegate
- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
    [aNetService setDelegate:self];
    [aNetService resolveWithTimeout:20.0];
    [foundServices addObject:aNetService];
    if(!moreComing)
    {
        [self stopSearch];
    }
}
- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
    
}
#pragma mark NSService Delegate
-(void)netServiceDidResolveAddress:(NSNetService *)sender
{
    if (sender == nil) {
        return;
    }
    
    NSString *host = [self getIpFromData:[sender.addresses firstObject]];
    if ([self discoverDevices:host widthName:sender.name width:sender.port]) {
        NSLog(@"发现新设备\n设备名称:%@\nip:%@",host,sender.name);
//        if ([host isEqualToString:@"10.17.174.43"]) {
//            [self connectDevice:host width:sender.port];
//        }
    }
}
-(BOOL)discoverDevices:(NSString*)ip widthName:(NSString*)deviceName width:(UInt16)port
{
    if ([ip isEqualToString:@"0.0.0.0"]) {
        return NO;
    }
    NSInteger deviceCount = self.devicesArr.count;
    for (NSInteger index = 0; index < deviceCount; index ++) {
        XSAirPlayModel *model = self.devicesArr[index];
        if ([model.ip isEqualToString:ip]) {
            return NO;
        }
    }
    XSAirPlayModel *xsModel = [[XSAirPlayModel alloc]init];
    xsModel.ip = ip;
    xsModel.deviceName = deviceName;
    xsModel.port = port;
    [self.devicesArr addObject:xsModel];
    return YES;
}
-(NSString*)getIpFromData:(NSData*)data
{
    if (data == nil) {
        return @"0.0.0.0";
    }
    struct sockaddr_in *addr = (struct sockaddr_in*)[data bytes];
    if (addr->sin_family == AF_INET) {
        NSString *ip = [NSString stringWithFormat:@"%s",inet_ntoa(addr->sin_addr)];
        return ip;
    }
    return @"0.0.0.0";
}

-(void)connectDevice:(NSString*)ip width:(UInt16)port
{
    socket = [[GCDAsyncSocket alloc]initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    NSError *error = nil;
    
    
    [socket connectToHost:ip onPort:port withTimeout:-1 error:&error];
}
//断开Socket
- (void)disconnectDevice
{
    status = NO;
    if (socket == nil) {
        return;
    }
    //立即断开Socket
    [socket disconnect];
}
#pragma mark socketDelegate
-(void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
    NSLog(@"host:%@--port:%d",host,port);
    status = YES;
    connectedHost = host;
    [socket readDataWithTimeout:-1 tag:0];
    [self sendReverse];
}
//发送数据
-(void)sendRawData:(NSData *)data
{
    [socket writeData:data withTimeout:-1 tag:0];
}

-(void)sendRawMessage:(NSString *)message
{
    [self sendRawData:[message dataUsingEncoding:NSUTF8StringEncoding]];
}
//播放请求：携带播放链接
//本地文件播放为http，网络文件播放为m3u8地址
-(void)sendContentURL:(NSString *)url
{
    NSString *body = [[NSString alloc] initWithFormat:@"Content-Location: %@\r\n"
                      "Start-Position: 0\r\n\r\n", url];
    int length = (int)[body length];
    
    NSString *message = [[NSString alloc] initWithFormat:@"POST /play HTTP/1.1\r\n"
                         "Content-Length: %d\r\n"
                         "User-Agent: MediaControl/1.0\r\n\r\n%@", length, body];
    
    
    [self sendRawMessage:message];
}

-(void)sendImage:(UIImage *)image forceReady:(BOOL)ready
{
    [self sendImage:image];
}
//推送图片：在HTTP的Body发送实际图片
- (void)sendImage:(UIImage *)image
{
        
    NSData *imageData = UIImageJPEGRepresentation(image, 0.8);
    int length = (int)[imageData length];
    NSString *message = [[NSString alloc] initWithFormat:@"PUT /photo HTTP/1.1\r\n"
                             "Content-Length: %d\r\n"
                             "User-Agent: MediaControl/1.0\r\n\r\n", length];
    NSMutableData *messageData = [[NSMutableData alloc] initWithData:[message dataUsingEncoding:NSUTF8StringEncoding]];
    [messageData appendData:imageData];
    [self sendRawData:messageData];
}
//设置播放时间，seconds(秒数)
-(void)setScrub:(float)seconds
{
    NSString *cmdStr = [NSString stringWithFormat:@"POST /scrub?position=%f HTTP/1.1\r\nUser-Agent: MediaControl/1.0\r\n\r\n",seconds];
    [self sendRawMessage:cmdStr];
}
//获取播放位置
-(void)getScrub
{
    NSString *cmdStr = @"GET /scrub HTTP/1.1\r\n"
    "User-Agent: MediaControl/1.0\r\n\r\n";
    [self sendRawMessage:cmdStr];
}
//暂停／播放
-(void)setRate:(BOOL)playState
{
    NSString *cmdStr = @"";
    if (playState) {//播放
        cmdStr = @"POST /rate?value=1.000000 HTTP/1.1\r\n"
        "User-Agent: MediaControl/1.0\r\n\r\n";
    }
    else//暂停
    {
        cmdStr = @"POST /rate?value=0.000000 HTTP/1.1\r\n"
        "User-Agent: MediaControl/1.0\r\n\r\n";
    }
    [self sendRawMessage:cmdStr];
}
//获取音量
-(void)getVolume
{
    NSString *cmdStr = @"GET /volume HTTP/1.1\r\n"
    "User-Agent: MediaControl/1.0\r\n\r\n";
    [self sendRawMessage:cmdStr];
}
//设置音量
-(void)setVolume:(float)volume
{
    NSLog(@"%s",__func__);
    NSString *cmdStr = [NSString stringWithFormat:@"POST /volume?value=%f HTTP/1.1\r\nUser-Agent: MediaControl/1.0\r\n\r\n",volume];
    [self sendRawMessage:cmdStr];
}
//关闭播放
- (void)sendStop
{
    NSString *message = @"POST /stop HTTP/1.1\r\n"
    "User-Agent: MediaControl/1.0\r\n\r\n";
    [self sendRawMessage:message];
}
//获取播放端的状态：总时长、缓冲时长、播放位置、播放器状态（LOADING、PLAYING、PAUSED、STOP）等信息
-(void)getPlaybackInfo
{
    NSString *cmdStr = @"GET /playback-info HTTP/1.1\r\n"
    "Content-Length: 0\r\n"
    "User-Agent: MediaControl/1.0\r\n\r\n";
    [self sendRawMessage:cmdStr];
}
//获取服务器信息
-(void)getServerInfo
{
    NSString *cmdStr = @"GET /server-info HTTP/1.1\r\n"
    "X-Apple-Device-ID: 0xdc2b61a0ce79\r\n"
    "Content-Length: 0\r\n"
    "User-Agent: MediaControl/1.0\r\n\r\n";
    [self sendRawMessage:cmdStr];
}
//协商请求
-(void)sendReverse
{
    NSString *message = @"POST /reverse HTTP/1.1\r\n"
    "Upgrade: PTTH/1.0\r\n"
    "Connection: Upgrade\r\n"
    "X-Apple-Purpose: event\r\n"
    "Content-Length: 0\r\n"
    "User-Agent: MediaControl/1.0\r\n\r\n";
    
    [self sendRawData:[message dataUsingEncoding:NSUTF8StringEncoding]];
}

-(void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    NSLog(@"readData:%@",[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]);
    [socket readDataWithTimeout:-1 tag:0];
}

-(void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    NSLog(@"%@",err.description);
    status = NO;
    [self disconnectDevice];
}
-(BOOL)getDeviceStatus
{
    return status;
}
-(NSString*)getDeviceIp
{
    return connectedHost;
}
@end
