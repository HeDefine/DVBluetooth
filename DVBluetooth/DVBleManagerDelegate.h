//
//  DVBleManagerDelegate.h
//  DVBluetooth
//
//  Created by Devine.He on 2019/4/19.
//  Copyright © 2019 Devine. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DVBleEnum.h"

@class DVBlePeripheral;
NS_ASSUME_NONNULL_BEGIN
@protocol DVBleManagerDelegate <NSObject>

@required
/**
 蓝牙状态发送改变
 @param state 蓝牙当前的状态
 */
- (void)didBluetoothStateChanged: (DVBleManagerState)state;

@optional
#pragma mark - 扫描相关回调

/**
 扫描到新设备

 @param state 扫描状态
 @param newPeri 新设备
 */
- (void)didScanPeripheralState:(DVBleManagerScanState)state newPeripheral:(nullable DVBlePeripheral *)newPeri;


#pragma mark - 连接相关回调
/**
已连接到外设

 @param peripheral 外设
 */
- (void)didConnectToPeripheral:(DVBlePeripheral *)peripheral state:(DVBleManagerConnectState)state;

/**
 连接失败并且重连也失败的时候回调 (一般是连接失败或者被动断开连接)

 @param peripheral 外设
 @param error 错误原因
 */
- (void)didConnectFailedToPeripheral:(DVBlePeripheral *)peripheral error:(DVBleManagerConnectError)error;

/**
 外设 已经主动断开连接

 @param peripheral 外设
 @param isActive 是否是主动断开连接的
 */
- (void)didDisConnectedToPeripheral:(DVBlePeripheral *)peripheral isActive:(BOOL)isActive;

/**
 开始重连操作.

 @param needReconnectPeripheral 需要重连的设备列表
 @param state 当前重连的状态
 */
- (void)didReconnectedToPeripherals:(nullable NSArray <DVBlePeripheral *> *)needReconnectPeripheral status:(DVBleManagerReconnectState)state;

@end

NS_ASSUME_NONNULL_END
