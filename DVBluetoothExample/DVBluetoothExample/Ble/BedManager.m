//
//  OREBedManager.m
//  DVBluetooth
//
//  Created by Devine.He on 2019/5/22.
//  Copyright © 2019 Devine. All rights reserved.
//

#import "BedManager.h"
#define UUIDWriteDataService  @"FFE5"
#define UUIDWriteDataCharateristic @"FFE9"
#define UUIDReadDataService  @"FFE0"
#define UUIDReadDataCharateristic @"FFE4"

#define UUIDInfoService  @"FF90"
#define UUIDDeviceNameCharateristic @"FF91"

@implementation BedManager

+ (instancetype)shared {
    static BedManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[BedManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self configuration];
    }
    return self;
}

/**
 初始化配置, 个性化配置
 */
- (void)configuration {
    //筛选掉扫描到的设备
    [self setScannedPeriFilterBlock:^BOOL(DVBlePeripheral *peripheral) {
        return peripheral.name && peripheral.name.length > 0;
    }];
    //筛选掉服务和特征值
    [self setConnectPeriFilterBlock:^BOOL(DVBlePeripheral *peripheral) {
        BOOL have1 = [peripheral filterService:UUIDWriteDataService
                               characteristics:@[UUIDWriteDataCharateristic]];
        BOOL have2 = [peripheral filterService:UUIDReadDataService
                               characteristics:@[UUIDReadDataCharateristic]];
        return have1 && have2;
    }];
    //监听值
    [self setNotifyPeriCharacteristicBlock:^(DVBlePeripheral *peripheral) {
        [peripheral startNotifyCharacteristicUUID:UUIDReadDataCharateristic];
    }];
    
    self.enableReconnect = YES;
    self.reconnectDuration = 5;
    self.maxReconnectTimes = 5;
    
    self.maxConnectedPeripheralsCount = 1;
}



#pragma mark - Override 复写
/**
 写入 回调
 
 @param peripheral 写入的外设
 @param result 写入结果
 */
- (void)didPeripheralWriteData:(DVBlePeripheral *)peripheral
            characteristicUUID:(NSString *)characteristicUUID
                   resultState:(DVBlePeripheralWriteState)result {
    if ([characteristicUUID isEqualToString:UUIDWriteDataCharateristic]) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(didWriteDataResultState:)]) {
            [(id)self.delegate didWriteDataResultState:result];
        }
    }
}


/**
 读取回调. 处理数据
 */
- (void)didPeripheralReadData:(DVBlePeripheral *)peripheral
           characteristicUUID:(NSString *)characteristicUUID
                         data:(nullable NSData *)data
                  resultState:(DVBlePeripheralReadState)result {
    if ([characteristicUUID isEqualToString:UUIDReadDataCharateristic]) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(didReadData:resultState:)]) {
            [(id)self.delegate didReadData:data resultState:result];
        }
        /****    处理数据      ***/
    }
}




#pragma mark - 个性化设置
- (void)writeData:(NSString *)dataStr {
    if (self.connectedPeripherals.count == 0) {
        NSLog(@"当前没有连接的设备");
        return;
    }
    NSData *data = [NSData dataFromHexString:dataStr];
    
    [self writeDataToPeripheral:self.connectedPeripherals.firstObject
           onCharacteristicUUID:UUIDWriteDataCharateristic
                       withData:data];
}


- (void)headup {
    [self writeData:@"FFFFFFFFFFFF"];
}
@end
