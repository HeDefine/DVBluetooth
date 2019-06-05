//
//  DVBleEnum.h
//  DVBluetooth
//
//  Created by Devine.He on 2019/4/19.
//  Copyright © 2019 Devine. All rights reserved.
//

#ifndef DVBleEnum_h
#define DVBleEnum_h

#pragma mark - BleManager 相关
///蓝牙状态 枚举
typedef enum : NSUInteger {
    ///当前蓝牙未授权,需要到系统设置中允许蓝牙通信
    DVBleManagerStateUnAvaiable = 0,
    ///当前蓝牙已经开启
    DVBleManagerStatePowerOn = 1,
    ///当前蓝牙已经关闭
    DVBleManagerStatePowerOff = 2,
    
} DVBleManagerState;

///蓝牙搜索状态 枚举
typedef enum : NSUInteger {
    DVBleManagerScanBegin,
    DVBleManagerScanning,
    DVBleManagerScanEnd,
} DVBleManagerScanState;

///外设的连接状态
typedef enum : NSUInteger {
    ///开始连接
    DVBleManagerConnectBegin,
    ///连接成功,开始搜索特征值
    DVBleManagerConnectDiscovering,
    ///筛选特征值
    DVBleManagerConnectFiltering,
    ///连接成功
    DVBleManagerConnectSuccess,
    
} DVBleManagerConnectState;

///重连状态 枚举
typedef enum : NSUInteger {
    ///开始重连
    DVBleManagerReconnectBegin,
    ///重连中
    DVBleManagerReconnecting,
    ///重连结束
    DVBleManagerReconnectEnd,
    
} DVBleManagerReconnectState;

///连接失败原因 枚举
typedef enum : NSUInteger {
    ///没有错误
    DVBleManagerConnectErrorNone,
    ///连接超时
    DVBleManagerConnectErrorTimeout,
    ///连接失败并重连也失败的
    DVBleManagerConnectErrorConnectFailed,
    ///连接失败,因为不是对应的设备(未找到对应的服务值&特征值)
    DVBleManagerConnectErrorNotParied,
    
} DVBleManagerConnectError;



#pragma mark - Peripheral 外设相关
///外设当前状态 枚举
typedef enum : NSUInteger {
    ///外设未连接
    DVBlePeripheralStateUnConnected,
    ///外设已连接
    DVBlePeripheralStateConnected,
    
} DVBlePeripheralState;

//外设写入数据
typedef enum : NSUInteger {
    ///外设未连接, 写入失败
    DVBlePeripheralWriteStateUnConnected,
    ///没有找到指定的特征值, 写入失败
    DVBlePeripheralWriteStateNoCharacteristic,
    ///没有写入的数据，写入失败
    DVBlePeripheralWriteStateNoData,
    ///写入超时
    DVBlePeripheralWriteStateTimeout,
    ///写入成功
    DVBlePeripheralWriteStateSuccess,
    ///写入失败 系统原因
    DVBlePeripheralWriteStateError,

} DVBlePeripheralWriteState;


//外设读取数据
typedef enum : NSUInteger {
    ///外设未连接
    DVBlePeripheralReadStateUnConnected,
    ///没有找到指定的特征值, 写入失败
    DVBlePeripheralReadStateNoCharacteristic,
    ///外设读取超时
    DVBlePeripheralReadStateTimeout,
    ///外设读取成功
    DVBlePeripheralReadStateSuccess,
    ///外设读取失败
    DVBlePeripheralReadStateError,
    ///外设订阅失败
    DVBlePeripheralReadStateNotifyFailed,

} DVBlePeripheralReadState;
#endif /* DVBleEnum_h */
