//
//  DVBlePeripheral.h
//  DVBluetooth
//
//  Created by Devine.He on 2019/4/19.
//  Copyright © 2019 Devine. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DVBleEnum.h"
#import "DVBlePeripheralDelegate.h"

@class CBPeripheral;
@class CBUUID;
@class CBService;
@class CBCharacteristic;

NS_ASSUME_NONNULL_BEGIN
@interface DVBlePeripheral : NSObject
#pragma mark - 属性值
#pragma mark 原始数据
///外设
@property (nonatomic, strong) CBPeripheral *peripheral;
///蓝牙外设的信号(0:设备离开可连接的范围)
@property (nonatomic, strong) NSNumber *RSSI;
///广播值
@property (nonatomic, strong) NSDictionary<NSString *, id> *advertisementData;

#pragma mark 封装后的数据
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *identifier;
@property (nonatomic, assign, readonly) DVBlePeripheralState state;
@property (nonatomic, assign, readonly) BOOL isConnected;


#pragma mark 广播值解析后的值
/*   这些值在扫描的时候就可以获取到, 所以筛选扫描到的设备的时候也可以根据这些值来判断  */
@property (nonatomic, strong) NSString *localName;
@property (nonatomic, strong) NSData *manufacturerData;
@property (nonatomic, strong) NSDictionary<CBUUID *,NSData *> *serviceData;
///服务UUID数组   这个值和 services 区分开。这个值在扫描的时候就可以获取到的广播值
@property (nonatomic, strong) NSArray<CBUUID *> *serviceUUIDs;
@property (nonatomic, strong) NSArray<CBUUID *> *overflowServiceUUIDs;
@property (nonatomic, strong) NSNumber *txPowerLevel;
///是否可连接。 区分 isConnected
@property (nonatomic, strong) NSNumber *isConnectable;
@property (nonatomic, strong) NSArray<CBUUID *> *solicitedServiceUUIDs;

#pragma mark *逻辑值,用于设置的值
/**
 当前尝连连接的次数
 连接成功时 该值会归零。 连接失败时 会尝试重连，并加1
 非正常断开连接时都会进行重连, 重连次数不会超过 最大重连次数(在DVBleOptions.h中设置)
 当超过最大的自动重连次数后，会提示连接失败。
 */
@property (nonatomic, assign) NSInteger reconnectTimes;

///协议
@property (nonatomic, weak) id<DVBlePeripheralDelegate> delegate;
@property (nonatomic, strong, readonly) NSArray<CBService *> *allServices;
@property (nonatomic, strong, readonly) NSArray<CBCharacteristic *> *allCharacteristics;

#pragma mark - 初始化方法
/**
 初始化方法
 */
- (instancetype)initWithPeripheral:(CBPeripheral *)peripheral;

#pragma mark - 公共方法

/**
 重置数据 (主要重置了 重连次数和信号量)
 */
- (void)reset;


/**
 更新RSSI信号
 */
- (void)resetRSSI;

/**
 发现所有的服务和特征值, 一般连接成功后，需要发现下服务和特征值
 */
- (void)discoverAllServicesAndCharacteristics;

/**
 查找当前的服务和特征值中是否有符合的设备

 @param serviceUUID 服务的UUID
 @param characteristicUUIDs 特征值UUID的数组
 @return 是否包含该服务和特征值
 */
- (BOOL)filterService:(NSString *)serviceUUID characteristics:(NSArray <NSString *> *)characteristicUUIDs;

/**
 写入数据

 @param data 数据
 @param uuidStr 特征值ID
 @param timeInterval 超时时间
 */
- (void)writeData:(nullable NSData *)data onCharacteristicsUUID:(NSString *)uuidStr timeoutInterval:(NSTimeInterval)timeInterval;


/**
 单次读取数据

 @param uuidStr 读取特征值 ID
 */
- (void)readDataOnCharacteristicsUUID:(NSString *)uuidStr timeoutInterval:(NSTimeInterval)timeInterval;


/**
 监听特征值  长时间读取数据

 @param uuidStr 特征值UUID
 */
- (void)startNotifyCharacteristicUUID:(NSString *)uuidStr;

/**
 取消监听特征值

 @param uuidStr 特征值UUID
 */
- (void)stopNotifyCharacteristicUUID:(NSString *)uuidStr;
@end


NS_ASSUME_NONNULL_END
