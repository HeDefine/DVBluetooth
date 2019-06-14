//
//  DVBleManager.h
//  DVBluetooth
//
//  Created by Devine.He on 2019/4/19.
//  Copyright © 2019 Devine. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DVBleManagerDelegate.h"
#import "DVBlePeripheral.h"

NS_ASSUME_NONNULL_BEGIN
typedef BOOL(^ScannedPeripheralsFilterBlock)(DVBlePeripheral *peripheral);
typedef BOOL(^ConnectedPeripheralsFilterBlock)(DVBlePeripheral *peripheral);
typedef void(^NotifyCharacteristicValueBlock)(DVBlePeripheral *peripheral);
typedef void(^WriteDataCallbackBlock)(DVBlePeripheral *peripheral, DVBlePeripheralWriteState state, NSString *uuidStr);
typedef void(^ReadDataCallbackBlock)(DVBlePeripheral *peripheral, DVBlePeripheralReadState state, NSString *uuidStr, NSData *data);
@interface DVBleManager : NSObject

#pragma mark - 属性
///当前蓝牙状态
@property (nonatomic, assign, readonly) DVBleManagerState state;
///协议
@property (nonatomic, weak) id<DVBleManagerDelegate> delegate;

/**  连接相关   **/
///最大可连接的设备数量, 默认是1 (最大连接数是8 ,如果再次连接时，会断开多余的设备，根据先连先断的原则)
@property (nonatomic, assign) NSInteger maxConnectedPeripheralsCount;
///连接超时时限   默认10s
@property (nonatomic, assign) NSTimeInterval connectTimeoutInterval;
///是否允许自动重连, 默认打开重连
@property (nonatomic, assign, getter = isEnableReconnect) BOOL enableReconnect;
///当前是否在重连
@property (nonatomic, assign, readonly) BOOL isReconnecting;
///自动重连次数, 默认重连次数时3. ( -1 表示无限重连 ***谨慎开启, 会有性能损耗)
@property (nonatomic, assign) NSInteger maxReconnectTimes;
///重连间隔, 默认是 10s
@property (nonatomic, assign) NSTimeInterval reconnectDuration;
///是否允许打开App时自动重连
@property (nonatomic, assign, getter = isEnableAutoReconnectLastPeripherals) BOOL enableAutoReconnectLastPeripherals;

///从第一次扫描开始，每次扫描就保存下所有的设备
@property (nonatomic, strong, readonly) NSArray<DVBlePeripheral *> *allPeripherals;
///扫描到的设备
@property (nonatomic, strong, readonly) NSArray<DVBlePeripheral *> *scannedPeripherals;
///连接中的设备
@property (nonatomic, strong, readonly) NSArray<DVBlePeripheral *> *connectedPeripherals;
///需要重连的设备
@property (nonatomic, strong, readonly) NSArray<DVBlePeripheral *> *reconnectPeripherals;

///需要搜索所有的服务值和特征值,默认是YES
@property (nonatomic, assign) BOOL needDiscoverAllServicesAndCharacteristics;

///读取超时时间, 默认是10s
@property (nonatomic, assign) NSTimeInterval readDataTimeoutInterval;
///写入超时时间, 默认是10s
@property (nonatomic, assign) NSTimeInterval writeDataTimeoutInterval;

///扫描到的设备过滤
@property (nonatomic, copy) ScannedPeripheralsFilterBlock scannedPeriFilterBlock;
///连接到的设备过滤
@property (nonatomic, copy) ConnectedPeripheralsFilterBlock connectPeriFilterBlock;
///监听特征值
@property (nonatomic, copy) NotifyCharacteristicValueBlock notifyPeriCharacteristicBlock;
//写入回调
@property (nonatomic, copy) WriteDataCallbackBlock writeDataCallbackBlock;
//读取回调
@property (nonatomic, copy) ReadDataCallbackBlock readDataCallbackBlock;
#pragma mark - 单例
/**
 单例
 */
+ (instancetype)shared;

#pragma mark - 扫描设备
/**
 扫描设备, 默认是扫描10s。

 (Why? 因为苹果官方不建议一直扫描,过于消耗电量等,所以应当及时停止扫描.如果需要一直扫描用[scanPeripheralsForSeconds:]方法)
 */
- (void)scanPeripherals;

/**
 扫描设备
 
 @param seconds 扫描时间.如果扫描时间为<=0时,会一直扫描设备
 */
- (void)scanPeripheralsForSeconds:(NSInteger)seconds;

/**
 设置扫描到的设备筛选

 @param scannedPeriFilterBlock 筛选规则
 */
- (void)setScannedPeriFilterBlock:(ScannedPeripheralsFilterBlock)scannedPeriFilterBlock ;

/**
 扫描设备基础方法

 @param seconds 扫描时间.如果扫描时间为<=0时,会一直扫描设备
 @param filter 筛选规则
 */
- (void)scanPeripheralsForSeconds:(NSInteger)seconds filter:(nullable ScannedPeripheralsFilterBlock)filter;

/**
 停止扫描设备
 */
- (void)stopScanPeripherals;


#pragma mark - 连接设备
/**
 连接最后一次连接的设备, 一般是App打开时会用到
 */
- (void)connectToLastConnectedPeripheral;

/**
 通过UUID来连接到外设

 @param UUIDStr 设备的UUID
 */
- (void)connectToPeripheralUUID:(NSString *)UUIDStr;

/**
 连接到外设

 @param peripheral 外设
 */
- (void)connectToPeripheral:(DVBlePeripheral *)peripheral;

/**
 连接到外设。并过滤特征值

 @param peripheral 外设
 @param filter 过滤块
 */
- (void)connectToPeripheral:(DVBlePeripheral *)peripheral filter:(nullable ConnectedPeripheralsFilterBlock)filter;

/**
 通过UUID来断开外设连接

 @param UUIDStr 外设UUID
 */
- (void)disConnectToPeripheralUUID:(NSString *)UUIDStr;

/**
 断开外设连接

 @param peripheral 外设
 */
- (void)disConnectToPeripheral:(DVBlePeripheral *)peripheral;

/**
 开启重连. 会在以前连接失败的设备重连.
 */
- (void)reconnect;

/**
 取消当前重连
 */
- (void)cancelReconnect;


#pragma mark - 数据读写
/**
 写入数据

 @param peripheral 设备
 @param uuid 写入特征值ID
 @param data 写入数据
 */
- (void)writeDataToPeripheral:(DVBlePeripheral *)peripheral onCharacteristicUUID:(NSString *)uuid withData:(NSData *)data;

/**
 读取数据

 @param peripheral 外设
 @param uuid 外设特征值
 */
- (void)readDataFromPeripheral:(DVBlePeripheral *)peripheral onCharacteristicUUID:(NSString *)uuid;

/**
 监听数据

 @param peripheral 外设
 @param uuid 特征值ID
 @param enable 是否开启监听
 */
- (void)notifyValueToPeripheral:(DVBlePeripheral *)peripheral onCharacteristicUUID:(NSString *)uuid enable:(BOOL)enable;
@end

NS_ASSUME_NONNULL_END
