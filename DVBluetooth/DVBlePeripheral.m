//
//  DVBlePeripheral.m
//  DVBluetooth
//
//  Created by Devine.He on 2019/4/19.
//  Copyright © 2019 Devine. All rights reserved.
//

#import "DVBlePeripheral.h"
#import <CoreBluetooth/CoreBluetooth.h>

@interface DVBlePeripheral() <CBPeripheralDelegate>

@property (nonatomic, strong) NSMutableDictionary<NSString *, CBService *> *mServices;
@property (nonatomic, strong) NSTimer *findCharacteristicsTimer;
@property (nonatomic, strong) NSMutableDictionary<NSString *, CBCharacteristic *> *mCharacteristics;

@property (nonatomic, strong) NSTimer *mWriteTimer;
@property (nonatomic, strong) NSTimer *mReadTimer;
@end
@implementation DVBlePeripheral
- (instancetype)initWithPeripheral:(CBPeripheral *)peripheral {
    self = [super init];
    if (self) {
        self.peripheral = peripheral;
        self.peripheral.delegate =  self;

        _reconnectTimes = 0;
        _RSSI = [NSNumber numberWithInt:-255];
        _mServices = [[NSMutableDictionary alloc] init];
        _mCharacteristics = [[NSMutableDictionary alloc] init];
    }
    return self;
}

#pragma mark - OverWrite 复写方法
/**
 Overwrite 复写比较方法，用来排序或者对比大小.
 排序思路是:1.优先根据信号强度排序  2.其次根据设备名排序
 
 @param other 排序对象
 @return 排序结果
 */
- (NSComparisonResult)compare:(id)other {
    DVBlePeripheral *peri = (DVBlePeripheral *)other;
    NSComparisonResult result = [peri.RSSI compare:self.RSSI];
    if (result == NSOrderedSame) {
        result = [peri.name compare:self.name];
    }
    return result;
}


/**
 Overwrite 复写，用来判断两个对象是否是同一个
 判断思路: 如果两个对象的identifier一致的话, 那么这两个设备是同一个设备
 
 @param other 判断对象
 @return 判断结果
 */
- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    } else if (![other isKindOfClass:[DVBlePeripheral class]]) {
        return NO;
    } else {
        DVBlePeripheral *peri = (DVBlePeripheral *)other;
        return [self.identifier isEqualToString:peri.identifier];
    }
}

/**
 Overwrite 复写,也是用来判断同一个对象的辅助方法之一
 同样也是对象的唯一性就是根据identifier来判断的
 
 @return hash值
 */
- (NSUInteger)hash {
    return self.identifier.hash;
}

#pragma mark - Public Methods 公共方法
- (void)reset {
    self.reconnectTimes = 0;
    if (self.state == DVBlePeripheralStateConnected) {
        //如果已经连接的状态，扫描到的设备读取RSSI
        [self.peripheral readRSSI];
    } else {
        //如果非连接状态, 重置信号量, 清空服务
        self.RSSI = [NSNumber numberWithInt:0];
    }
}

/**
 重置RSSI信号
 */
- (void)resetRSSI {
    if (self.state == DVBlePeripheralStateConnected) {
        //如果已经连接的状态，扫描到的设备读取RSSI
        [self.peripheral readRSSI];
    } else {
        //如果非连接状态, 重置信号量, 清空服务
        self.RSSI = [NSNumber numberWithInt:0];
    }
}

/**
 发现所有的服务和特征值
 */
- (void)discoverAllServicesAndCharacteristics {
    //NSLog(@"搜索服务和特征值......开始");
    [self.mServices removeAllObjects];
    [self.peripheral discoverServices:nil];
}
//搜索所有特征值超时
- (void)discoverAllServicesAndCharacteristicsTimeout {
    //NSLog(@"搜索服务和特征值......超时,结束搜索");
    if (self.delegate && [self.delegate respondsToSelector:@selector(didPeripheralFinishDiscoveredServicesAndCharacteristics:error:)]) {
        [self.delegate didPeripheralFinishDiscoveredServicesAndCharacteristics:self error:@"Timeout"];
    }
}

/**
 判断是否有该服务值及其特征值
 
 @param serviceUUID 服务值UUID
 @param characteristicUUIDs 特征值UUID
 @return 判断结果
 */
- (BOOL)filterService:(NSString *)serviceUUID characteristics:(NSArray <NSString *> *)characteristicUUIDs {
    for (CBService *service in self.allServices) {
        if ([service.UUID.UUIDString isEqualToString:serviceUUID]) {
            NSSet<NSString *> *needSet = [NSSet setWithArray:characteristicUUIDs];
            NSMutableSet<NSString *> *allSet = [[NSMutableSet alloc] init];
            for (CBCharacteristic *characteristic in service.characteristics) {
                [allSet addObject:characteristic.UUID.UUIDString];
            }
            //查看所需的特征值是不是所有特征值的子集.
            return [needSet isSubsetOfSet:allSet];
        }
    }
    return NO;
}

#pragma mark - 写入数据
/**
 写入数据
 
 @param data 数据
 @param uuidStr 特征值ID
 @param timeInterval 超时时间
 */
- (void)writeData:(nullable NSData *)data onCharacteristicsUUID:(NSString *)uuidStr timeoutInterval:(NSTimeInterval)timeInterval {
    //排除当前设备未连接的状态
    if (self.state != DVBlePeripheralStateConnected) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(didPeripheralWriteData:characteristicUUID:resultState:)]) {
            [self.delegate didPeripheralWriteData:self
                               characteristicUUID:uuidStr
                                      resultState:DVBlePeripheralWriteStateUnConnected];
        }
        return;
    }
    //排除没有数据的情况
    if (!data) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(didPeripheralWriteData:characteristicUUID:resultState:)]) {
            [self.delegate didPeripheralWriteData:self
                               characteristicUUID:uuidStr
                                      resultState:DVBlePeripheralWriteStateNoData];
        }
        return;
    }
    //排除没有该特征值
    CBCharacteristic *characteristic = [self.mCharacteristics objectForKey:uuidStr];
    if (!characteristic) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(didPeripheralWriteData:characteristicUUID:resultState:)]) {
            [self.delegate didPeripheralWriteData:self
                               characteristicUUID:uuidStr
                                      resultState:DVBlePeripheralWriteStateNoCharacteristic];
        }
        return;
    }
    //写入数据
    [self.peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
    
    [self.mWriteTimer invalidate];
    self.mWriteTimer = [NSTimer scheduledTimerWithTimeInterval:timeInterval
                                                        target:self
                                                      selector:@selector(writeDataTimeout:)
                                                      userInfo:uuidStr
                                                       repeats:NO];
}

/**
 写入超时
 */
- (void)writeDataTimeout:(NSTimer *)tiemr {
    NSString *uuidStr = (NSString *)tiemr.userInfo;
    if (self.delegate && [self.delegate respondsToSelector:@selector(didPeripheralWriteData:characteristicUUID:resultState:)]) {
        [self.delegate didPeripheralWriteData:self characteristicUUID:uuidStr resultState:DVBlePeripheralWriteStateTimeout];
    }
}


/**
 单次读取数据
 
 @param uuidStr 读取特征值 ID
 */
- (void)readDataOnCharacteristicsUUID:(NSString *)uuidStr timeoutInterval:(NSTimeInterval)timeInterval{
    //排除当前设备未连接的状态
    if (self.state != DVBlePeripheralStateConnected) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(didPeripheralReadData:characteristicUUID:data:resultState:)]) {
            [self.delegate didPeripheralReadData:self
                              characteristicUUID:uuidStr
                                            data:nil
                                     resultState:DVBlePeripheralReadStateUnConnected];
        }
        return;
    }
    //排除没有该特征值
    CBCharacteristic *characteristic = [self.mCharacteristics objectForKey:uuidStr];
    if (!characteristic) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(didPeripheralReadData:characteristicUUID:data:resultState:)]) {
            [self.delegate didPeripheralReadData:self
                              characteristicUUID:uuidStr
                                            data:nil
                                     resultState:DVBlePeripheralReadStateNoCharacteristic];
        }
        return;
    }
    
    [self.peripheral readValueForCharacteristic:characteristic];
    
    [self.mReadTimer invalidate];
    self.mReadTimer = [NSTimer scheduledTimerWithTimeInterval:timeInterval
                                                       target:self
                                                     selector:@selector(readDataTimeout:)
                                                     userInfo:uuidStr
                                                      repeats:NO];
}

- (void)readDataTimeout:(NSTimer *)timer {
    NSString *uuidStr = (NSString *)timer.userInfo;
    if (self.delegate && [self.delegate respondsToSelector:@selector(didPeripheralReadData:characteristicUUID:data:resultState:)]) {
        [self.delegate didPeripheralReadData:self
                          characteristicUUID:uuidStr
                                        data:nil
                                 resultState:DVBlePeripheralReadStateTimeout];
    }
}

/**
 监听特征值  长时间读取数据
 */
- (void)startNotifyCharacteristicUUID:(NSString *)uuidStr {
    //排除没有该特征值
    CBCharacteristic *characteristic = [self.mCharacteristics objectForKey:uuidStr];
    if (!characteristic) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(didPeripheralReadData:characteristicUUID:data:resultState:)]) {
            [self.delegate didPeripheralReadData:self
                              characteristicUUID:uuidStr
                                            data:nil
                                     resultState:DVBlePeripheralReadStateNoCharacteristic];
        }
        return;
    }
    //监听
    [self.peripheral setNotifyValue:YES forCharacteristic:characteristic];
}

/**
 取消监听特征值
 */
- (void)stopNotifyCharacteristicUUID:(NSString *)uuidStr {
    //排除没有该特征值
    CBCharacteristic *characteristic = [self.mCharacteristics objectForKey:uuidStr];
    if (!characteristic) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(didPeripheralReadData:characteristicUUID:data:resultState:)]) {
            [self.delegate didPeripheralReadData:self
                              characteristicUUID:uuidStr
                                            data:nil
                                     resultState:DVBlePeripheralReadStateNoCharacteristic];
        }
        return;
    }
    //监听
    [self.peripheral setNotifyValue:NO forCharacteristic:characteristic];
}


#pragma mark - CBPeripheralDelegate
- (void)peripheralDidUpdateName:(CBPeripheral *)peripheral {
    self.name = peripheral.name;
}

- (void)peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(nullable NSError *)error {
    if (!error) {
        self.RSSI = RSSI;
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didModifyServices:(NSArray<CBService *> *)invalidatedServices {
    
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(nullable NSError *)error {
    if (error) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(didPeripheralFinishDiscoveredServicesAndCharacteristics:error:)]) {
            [self.delegate didPeripheralFinishDiscoveredServicesAndCharacteristics:self error:error.description];
        }
        return;
    }

    //遍历所有的服务中，查找服务中的特征值
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(nullable NSError *)error {
    if (self.findCharacteristicsTimer) {
        [self.findCharacteristicsTimer invalidate];
    }
    //如果错误的话
    if (error) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(didPeripheralFinishDiscoveredServicesAndCharacteristics:error:)]) {
            [self.delegate didPeripheralFinishDiscoveredServicesAndCharacteristics:self error:error.description];
        }
        return;
    }
    //赋值mService
    [self.mServices setObject:service forKey:service.UUID.UUIDString];
    //赋值mCharacteristic
    for (CBCharacteristic *characteristic in service.characteristics) {
        [self.mCharacteristics setObject:characteristic forKey:characteristic.UUID.UUIDString];
    }
    //判断是否已经全部搜索完成
    if (self.mServices.count == peripheral.services.count) {
        //结束搜索服务和特征值
        if (self.delegate && [self.delegate respondsToSelector:@selector(didPeripheralFinishDiscoveredServicesAndCharacteristics:error:)]) {
            [self.delegate didPeripheralFinishDiscoveredServicesAndCharacteristics:self error:nil];
        }
    } else {
        //未发现所有的特征值,会开启一个超时操作。一般来说这个时间会影响连接成功的时间
        self.findCharacteristicsTimer = [NSTimer scheduledTimerWithTimeInterval:3
                                                                         target:self
                                                                       selector:@selector(discoverAllServicesAndCharacteristicsTimeout)
                                                                       userInfo:nil
                                                                        repeats:NO];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error {
    [self.mWriteTimer invalidate];
    if (self.delegate && [self.delegate respondsToSelector:@selector(didPeripheralWriteData:characteristicUUID:resultState:)]) {
        if (error) {
            NSLog(@"写入失败:%@",error.description);
        }
        [self.delegate didPeripheralWriteData:self
                           characteristicUUID:characteristic.UUID.UUIDString
                                  resultState:error == nil ? DVBlePeripheralWriteStateSuccess : DVBlePeripheralWriteStateError];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error {
    [self.mReadTimer invalidate];
    if (self.delegate && [self.delegate respondsToSelector:@selector(didPeripheralReadData:characteristicUUID:data:resultState:)]) {
        if (error) {
            NSLog(@"读取失败:%@",error.description);
        }
        [self.delegate didPeripheralReadData:self
                          characteristicUUID:characteristic.UUID.UUIDString
                                        data:characteristic.value
                                 resultState:error == nil ? DVBlePeripheralReadStateSuccess : DVBlePeripheralReadStateError];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error {
    if (error) {
        NSLog(@"订阅失败:%@",error.description);
        if (self.delegate && [self.delegate respondsToSelector:@selector(didPeripheralReadData:characteristicUUID:data:resultState:)]) {
            [self.delegate didPeripheralReadData:self
                              characteristicUUID:characteristic.UUID.UUIDString
                                            data:nil
                                     resultState:DVBlePeripheralReadStateNotifyFailed];
        }
    }
}



#pragma mark - Setter && Getter
- (void)setPeripheral:(CBPeripheral *)peripheral {
    _peripheral = peripheral;
    
    _name = peripheral.name;
    _identifier = peripheral.identifier.UUIDString;
}

- (void)setAdvertisementData:(NSDictionary<NSString *,id> *)advertisementData {
    _localName = [advertisementData objectForKey:CBAdvertisementDataLocalNameKey];
    _manufacturerData = [advertisementData objectForKey:CBAdvertisementDataManufacturerDataKey];
    _serviceUUIDs = [advertisementData objectForKey:CBAdvertisementDataServiceUUIDsKey];
    _overflowServiceUUIDs = [advertisementData objectForKey:CBAdvertisementDataOverflowServiceUUIDsKey];
    _txPowerLevel = [advertisementData objectForKey:CBAdvertisementDataTxPowerLevelKey];
    _solicitedServiceUUIDs = [advertisementData objectForKey:CBAdvertisementDataSolicitedServiceUUIDsKey];
    _serviceData = [advertisementData objectForKey:CBAdvertisementDataServiceDataKey];
    _isConnectable = [advertisementData objectForKey:CBAdvertisementDataIsConnectable];
}

- (BOOL)isConnected {
    return self.state == DVBlePeripheralStateConnected;
}

- (DVBlePeripheralState)state {
    if (!self.peripheral) {
        return DVBlePeripheralStateUnConnected;
    }
    switch (self.peripheral.state) {
        case CBPeripheralStateConnected:
            return DVBlePeripheralStateConnected;
        default:
            return DVBlePeripheralStateUnConnected;
            break;
    }
}

- (NSArray<CBService *> *)allServices {
    return self.mServices.allValues;
}

- (NSArray<CBCharacteristic *> *)allCharacteristics {
    return self.mCharacteristics.allValues;
}
@end
