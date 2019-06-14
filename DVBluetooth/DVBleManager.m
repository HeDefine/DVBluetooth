//
//  DVBleManager.m
//  DVBluetooth
//
//  Created by Devine.He on 2019/4/19.
//  Copyright © 2019 Devine. All rights reserved.
//

#import "DVBleManager.h"
#import <CoreBluetooth/CoreBluetooth.h>

#define DV_LASTCONNECTED_PERIPHERALS_KEY @"kDVBleManagerLastConnectedPeripheralUUIDsKey"

@interface DVBleManager () <CBCentralManagerDelegate,DVBlePeripheralDelegate>
@property (nonatomic, strong) CBCentralManager *manager;

@property (nonatomic, strong) NSMutableArray<NSString *> *tempLastConnectedPeripheralUUIDs;
@property (nonatomic, strong) NSArray<NSString *> *mLastConnectedPeripheralUUIDs;

///从第一次扫描开始，每次扫描就保存下所有的设备
@property (nonatomic, strong) NSMutableDictionary<NSString *,DVBlePeripheral *> *mAllPeripheralDictionary;
///当次扫描到的设备UUID
@property (nonatomic, strong) NSMutableArray<NSString *> *mScannedPeripheralUUIDs;
///已经连接的设备UUID列表
@property (nonatomic, strong) NSMutableArray<NSString *> *mConnectPeripheralUUIDs;
///需要重连的设备UUID列表。这个数组一般是包括用来打开蓝牙开关的时候，需要重连的设备
@property (nonatomic, strong) NSMutableArray<NSString *> *mReconnectPeripheralUUIDs;

///连接超时  计时器
@property (nonatomic, strong) NSTimer *mConnectTimer;
///重连间隔  计时器
@property (nonatomic, strong) NSTimer *mReconnectTimer;
@end

@implementation DVBleManager
+ (instancetype)shared {
    static DVBleManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DVBleManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSArray *backgroundModes = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"UIBackgroundModes"];
        BOOL isEnableBleBackgroundModes = [backgroundModes containsObject:@"bluetooth-central"];
        NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
        [options setObject:[NSNumber numberWithInt:YES] forKey:CBCentralManagerOptionShowPowerAlertKey];
        if (isEnableBleBackgroundModes) {
            //只有开启了后台才会用到这个重新连接的方法
            [options setObject:@"DVBluetoothRestoreId" forKey:CBCentralManagerOptionRestoreIdentifierKey];
        }
        _manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:options];
        _state = DVBleManagerStateUnAvaiable;
        
        _mAllPeripheralDictionary = [[NSMutableDictionary alloc] init];
        _mScannedPeripheralUUIDs = [[NSMutableArray alloc] init];
        _mConnectPeripheralUUIDs = [[NSMutableArray alloc] init];
        _mReconnectPeripheralUUIDs = [[NSMutableArray alloc] init];

        _tempLastConnectedPeripheralUUIDs = self.mLastConnectedPeripheralUUIDs.mutableCopy;
        
        _maxConnectedPeripheralsCount = 1;
        _connectTimeoutInterval = 10;
        
        _enableReconnect = YES;
        _maxReconnectTimes = 3;
        _reconnectDuration = 10;
        
        _writeDataTimeoutInterval = 10;
        _readDataTimeoutInterval = 10;
        
        _enableAutoReconnectLastPeripherals = YES;
        _needDiscoverAllServicesAndCharacteristics = YES;
        
    }
    return self;
}

#pragma mark - 扫描设备
/**
 扫描设备, 默认是扫描10s。
 */
- (void)scanPeripherals {
    [self scanPeripheralsForSeconds:10 filter:nil];
}

/**
 扫描设备
 
 @param seconds 扫描时间.如果扫描时间为<=0时,会一直扫描设备
 */
- (void)scanPeripheralsForSeconds:(NSInteger)seconds {
    [self scanPeripheralsForSeconds:seconds filter:nil];
}

/**
 扫描设备基础方法
 
 @param seconds 扫描时间.如果扫描时间为<=0时,会一直扫描设备
 @param filter 筛选掉一些设备
 */
- (void)scanPeripheralsForSeconds:(NSInteger)seconds filter:(nullable ScannedPeripheralsFilterBlock)filter {
    //先判断当前蓝牙是否可用，不可用的话，会进入不可用回调
    if (self.state != DVBleManagerStatePowerOn) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(didBluetoothStateChanged:)]) {
            [self.delegate didBluetoothStateChanged:self.state];
        }
        return;
    }
    //筛选扫描到的设备
    if (filter) {
        [self setScannedPeriFilterBlock:filter];
    }
    //如果当前设备在扫描,先停止原先扫描，重开一次扫描
    if (self.manager.isScanning) {
        [self.manager stopScan];
    }
    //清空数值并重置信号
    [_mScannedPeripheralUUIDs removeAllObjects];
    for (DVBlePeripheral *peri in _mAllPeripheralDictionary.allValues) {
        [peri resetRSSI];
    }
    //*** 这里回调是为了防止设备列表reload的时候, 突然清空数据, 会造成数组溢出
    if (self.delegate && [self.delegate respondsToSelector:@selector(didScanPeripheralState:newPeripheral:)]) {
        [self.delegate didScanPeripheralState:DVBleManagerScanBegin newPeripheral:nil];
    }
    //扫描设备
    [self.manager scanForPeripheralsWithServices:nil options:nil];
    //定时关闭
    [NSThread cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(stopScanPeripherals)
                                               object:nil];
    if (seconds > 0) {
        [self performSelector:@selector(stopScanPeripherals)
                   withObject:nil
                   afterDelay:seconds];
    }
}

/**
 停止扫描设备
 */
- (void)stopScanPeripherals {
    if (self.manager.isScanning) {
        [self.manager stopScan];
        if (self.delegate && [self.delegate respondsToSelector:@selector(didScanPeripheralState:newPeripheral:)]) {
            [self.delegate didScanPeripheralState:DVBleManagerScanEnd newPeripheral:nil];
        }
    }
}

#pragma mark - 连接设备
/**
 连接最后一次连接的设备, 一般是App打开时会用到
 */
- (void)connectToLastConnectedPeripheral {
    _tempLastConnectedPeripheralUUIDs = self.mLastConnectedPeripheralUUIDs.mutableCopy;
    _enableAutoReconnectLastPeripherals = YES;
    [self scanPeripherals];
}

/**
 通过UUID来连接到外设
 
 @param UUIDStr 设备的UUID
 */
- (void)connectToPeripheralUUID:(NSString *)UUIDStr {
    DVBlePeripheral *peripheral = [self.mAllPeripheralDictionary objectForKey:UUIDStr];
    if (peripheral) {
        [self connectToPeripheral:peripheral];
    }
}

/**
 连接到外设
 
 @param peripheral 外设
 */
- (void)connectToPeripheral:(DVBlePeripheral *)peripheral {
    [self connectToPeripheral:peripheral filter:nil];
}

/**
 连接到外设。并过滤特征值
 
 @param peripheral 外设
 @param filter 过滤块
 */
- (void)connectToPeripheral:(DVBlePeripheral *)peripheral filter:(nullable ConnectedPeripheralsFilterBlock)filter {
    //先判断当前蓝牙是否可用，不可用的话，会进入不可用回调
    if (self.state != DVBleManagerStatePowerOn) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(didBluetoothStateChanged:)]) {
            [self.delegate didBluetoothStateChanged:self.state];
        }
        return;
    }
    //筛选连接的设备，不满足后会主动断开连接
    if (filter) {
        [self setConnectPeriFilterBlock:filter];
    }
    //如果当前设备正在扫描,停止扫描
    if (self.manager.isScanning) {
        [self stopScanPeripherals];
    }
    //连接新设备的时候，首先会取消重连
    [self cancelReconnect];
    
    //如果 超过“最大可连接的设备数” 的话。会先断开一开始的
    if (self.mConnectPeripheralUUIDs.count >= self.maxConnectedPeripheralsCount) {
        NSString *uuidStr =  self.mConnectPeripheralUUIDs.firstObject;
        DVBlePeripheral *peri = [self.mAllPeripheralDictionary objectForKey:uuidStr];
        if (peri) {
            //再断开已经连接的设备。 先连接的先断开
            NSLog(@"超过 最大可连接的设备数");
            NSLog(@"%@ 会先断开连接", peri.name);
            [self disConnectToPeripheral:peri];
            //开始断开回调
            if (self.delegate && [self.delegate respondsToSelector:@selector(didDisConnectedToPeripheral:isActive:)]) {
                [self.delegate didDisConnectedToPeripheral:peri isActive:YES];
            }
        } else {
            [self.mConnectPeripheralUUIDs removeObject:uuidStr];
            self.mLastConnectedPeripheralUUIDs = self.mConnectPeripheralUUIDs.mutableCopy;
        }
    }
    //连接设备
    NSLog(@"外设(%@)......开始连接",peripheral.name);
    [self.manager connectPeripheral:peripheral.peripheral options:nil];
    //进入回调
    if (self.delegate && [self.delegate respondsToSelector:@selector(didConnectToPeripheral:state:)]) {
        [self.delegate didConnectToPeripheral:peripheral state:DVBleManagerConnectBegin];
    }
    //连接超时操作
    self.mConnectTimer = [NSTimer scheduledTimerWithTimeInterval:self.connectTimeoutInterval
                                                         target:self
                                                       selector:@selector(connectTimeout:)
                                                       userInfo:peripheral
                                                        repeats:NO];
}

- (void)connectTimeout:(NSTimer *)timer {
    DVBlePeripheral *peri = (DVBlePeripheral *)timer.userInfo;
    NSLog(@"外设(%@)......连接失败(原因:超时,可能设备已超出连接范围)",peri.name);
    //断开正在连接的设备
    [self.manager cancelPeripheralConnection:peri.peripheral];
    //进入回调
    if (self.delegate && [self.delegate respondsToSelector:@selector(didConnectFailedToPeripheral:error:)]) {
        [self.delegate didConnectFailedToPeripheral:peri error:DVBleManagerConnectErrorTimeout];
    }
}

/**
 通过UUID来断开外设连接
 */
- (void)disConnectToPeripheralUUID:(NSString *)UUIDStr {
    DVBlePeripheral *peripheral = [self.mAllPeripheralDictionary objectForKey:UUIDStr];
    if (peripheral) {
        [self disConnectToPeripheral:peripheral];
    }
}

/**
 断开外设连接
 */
- (void)disConnectToPeripheral:(DVBlePeripheral *)peripheral {
    [self.manager cancelPeripheralConnection:peripheral.peripheral];
}

/**
 开启重连. 会在以前连接失败的设备重连.
 */
- (void)reconnect {
    //先判断当前蓝牙是否可用，不可用的话，会进入不可用回调
    if (self.state != DVBleManagerStatePowerOn) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(didBluetoothStateChanged:)]) {
            [self.delegate didBluetoothStateChanged:self.state];
        }
        [self.mReconnectTimer invalidate];
        self.mReconnectTimer = nil;
        return;
    }
    //没有打开自动重连的功能
    if (!self.isEnableReconnect) {
        NSLog(@"未打开自动重连功能");
        [self.mReconnectTimer invalidate];
        self.mReconnectTimer = nil;
        return;
    }
    //如果重连列表为空的时候，结束重连。
    if (self.mReconnectPeripheralUUIDs.count == 0) {
        NSLog(@"没有需要重连的设备, 结束重连");
        [self cancelReconnect];
        return;
    }

    NSLog(@"------开始重连-------");
    _isReconnecting = YES;
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(didReconnectedToPeripherals:status:)]) {
        [self.delegate didReconnectedToPeripherals:self.reconnectPeripherals status:DVBleManagerReconnectBegin];
    }
    
    //开始重连
    if (!self.mReconnectTimer) {
        // **先立刻走一遍重连方法，因为mReconnectTimer会延迟[reconnectDuration]执行
        [self sel_reconnect];
        self.mReconnectTimer = [NSTimer scheduledTimerWithTimeInterval:self.reconnectDuration
                                                                target:self
                                                              selector:@selector(sel_reconnect)
                                                              userInfo:nil
                                                               repeats:YES];
    }
    
}

/**
 取消当前重连
 */
- (void)cancelReconnect {
    _isReconnecting = NO;
    //停止当前所有的正在重连的设备
    NSLog(@"------结束重连-------");
    for (DVBlePeripheral *peri in self.reconnectPeripherals) {
        if (peri) {
            [self.manager cancelPeripheralConnection:peri.peripheral];
        }
    }
    //清空重连列表
    [self.mReconnectPeripheralUUIDs removeAllObjects];
    //清除 重连计时器
    [self.mReconnectTimer invalidate];
    self.mReconnectTimer = nil;
    //回调数据
    if (self.delegate && [self.delegate respondsToSelector:@selector(didReconnectedToPeripherals:status:)]) {
        [self.delegate didReconnectedToPeripherals:nil status:DVBleManagerReconnectEnd];
    }
}

/**
 重连计时器的 selector
 */
- (void)sel_reconnect {
    _isReconnecting = YES;

    NSLog(@"-----------------");
    //先判断当前蓝牙是否可用，不可用的话，会进入不可用回调
    if (self.state != DVBleManagerStatePowerOn) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(didBluetoothStateChanged:)]) {
            [self.delegate didBluetoothStateChanged:self.state];
        }
        [self cancelReconnect];
        return;
    }

    for (DVBlePeripheral *peri in self.reconnectPeripherals) {
        if (self.maxReconnectTimes == -1 || peri.reconnectTimes < self.maxReconnectTimes) {
            //无限重连   或者是  还有重连的机会
            if (peri.reconnectTimes != 0) {
                NSLog(@"外设(%@)......第 %d 次重连失败",peri.name, (int)peri.reconnectTimes);
            }
            NSLog(@"外设(%@)......尝试第 %d 次重连",peri.name, (int)peri.reconnectTimes+1);
            peri.reconnectTimes ++;
            [self.manager connectPeripheral:peri.peripheral options:nil];
        } else {
            NSLog(@"外设(%@)......超过重连次数(%d次),不再重连",peri.name, (int)peri.reconnectTimes);
            //取消原来的连接
            [self.manager cancelPeripheralConnection:peri.peripheral];
            //超过重连次数的话, 会从当前可重连的设备列表中移除
            [self.mReconnectPeripheralUUIDs removeObject:peri.identifier];
            [peri reset];
            if (self.delegate && [self.delegate respondsToSelector:@selector(didConnectFailedToPeripheral:error:)]) {
                [self.delegate didConnectFailedToPeripheral:peri error:DVBleManagerConnectErrorTimeout];
            }
        }
    }
    if (self.mReconnectPeripheralUUIDs.count > 0) {
        //回调本次需要重连的设备
        if (self.delegate && [self.delegate respondsToSelector:@selector(didReconnectedToPeripherals:status:)]) {
            [self.delegate didReconnectedToPeripherals:self.reconnectPeripherals status:DVBleManagerReconnecting];
        }
    } else {
        //没有需要重连的设备
        NSLog(@"没有需要重连的设备");
        [self cancelReconnect];
    }
}

#pragma mark - 数据读写
/**
 写入数据
 */
- (void)writeDataToPeripheral:(DVBlePeripheral *)peripheral onCharacteristicUUID:(NSString *)uuid withData:(NSData *)data {
    //先判断当前蓝牙是否可用，不可用的话，会进入不可用回调
    if (self.state != DVBleManagerStatePowerOn) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(didBluetoothStateChanged:)]) {
            [self.delegate didBluetoothStateChanged:self.state];
        }
        return;
    }
    //写入操作
    [peripheral writeData:data
    onCharacteristicsUUID:uuid
          timeoutInterval:self.writeDataTimeoutInterval];
}

/**
 读取数据
 */
- (void)readDataFromPeripheral:(DVBlePeripheral *)peripheral onCharacteristicUUID:(NSString *)uuid {
    //先判断当前蓝牙是否可用，不可用的话，会进入不可用回调
    if (self.state != DVBleManagerStatePowerOn) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(didBluetoothStateChanged:)]) {
            [self.delegate didBluetoothStateChanged:self.state];
        }
        return;
    }
    [peripheral readDataOnCharacteristicsUUID:uuid
                              timeoutInterval:self.readDataTimeoutInterval];
}

/**
 监听数据
 */
- (void)notifyValueToPeripheral:(DVBlePeripheral *)peripheral onCharacteristicUUID:(NSString *)uuid enable:(BOOL)enable {
    //先判断当前蓝牙是否可用，不可用的话，会进入不可用回调
    if (self.state != DVBleManagerStatePowerOn) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(didBluetoothStateChanged:)]) {
            [self.delegate didBluetoothStateChanged:self.state];
        }
        return;
    }
    if (enable) {
        [peripheral startNotifyCharacteristicUUID:uuid];
    } else {
        [peripheral stopNotifyCharacteristicUUID:uuid];
    }
}


#pragma mark - CBCentralManegerDelegate
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    switch (central.state) {
        case CBManagerStatePoweredOn:
            NSLog(@">>>>>> 蓝牙已打开 <<<<<<");
            _state = DVBleManagerStatePowerOn;
            [self scanPeripherals];
            if (self.isEnableReconnect && self.mReconnectPeripheralUUIDs.count > 0) {
                //开始重新连接设备
                [self reconnect];
            }
            break;
        case CBManagerStatePoweredOff:
            NSLog(@">>>>>> 蓝牙已关闭 <<<<<<");
            //蓝牙关闭的时候，清空扫描到的所有设备
            [self.mScannedPeripheralUUIDs removeAllObjects];
            //停止重连操作
            [self cancelReconnect];
            //添加到已连接的设备到重连设备列表
            [self.mReconnectPeripheralUUIDs addObjectsFromArray:self.mConnectPeripheralUUIDs];
            //清空已连接的设备
            [self.mConnectPeripheralUUIDs removeAllObjects];
            //如果超过最大的可连接的
            while (self.mReconnectPeripheralUUIDs.count > self.maxConnectedPeripheralsCount) {
                [self.mReconnectPeripheralUUIDs removeObject:self.mReconnectPeripheralUUIDs.firstObject];
            }
            _state = DVBleManagerStatePowerOff;
            break;
        default:
            NSLog(@">>>>>> 蓝牙不可用 <<<<<<");
            _state = DVBleManagerStateUnAvaiable;
            break;
    }
    
    if (_delegate && [_delegate respondsToSelector:@selector(didBluetoothStateChanged:)]) {
        [_delegate didBluetoothStateChanged:self.state];
    }
}

- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary<NSString *, id> *)dict {
    
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI {
    DVBlePeripheral *peri = [[DVBlePeripheral alloc] initWithPeripheral:peripheral];
    peri.RSSI = RSSI;
    peri.advertisementData = advertisementData;

    //根据用户的过滤规则规律一遍新扫描到的设备
    if (self.scannedPeriFilterBlock && !self.scannedPeriFilterBlock(peri)) {
        //如果不符合过滤规则，跳过这个设备
        return;
    }
    //新增/更新 扫描到的设备
    [self.mAllPeripheralDictionary setObject:peri forKey:peri.identifier];
    if (![self.mScannedPeripheralUUIDs containsObject:peri.identifier]) {
        [self.mScannedPeripheralUUIDs addObject:peri.identifier];
        
        //自动重连到上次连接的设备
        if (self.isEnableAutoReconnectLastPeripherals && self.tempLastConnectedPeripheralUUIDs.count > 0) {
            if ([self.tempLastConnectedPeripheralUUIDs containsObject:peri.identifier]) {
                [self.mReconnectPeripheralUUIDs addObject:peri.identifier];
                [self reconnect];
                [self.tempLastConnectedPeripheralUUIDs removeObject:peri.identifier];
            }
            
            if (self.tempLastConnectedPeripheralUUIDs.count == 0) {
                _enableAutoReconnectLastPeripherals = NO;
                [self stopScanPeripherals];
            }
        }
        //回调扫描到的新设备
        if (self.delegate && [self.delegate respondsToSelector:@selector(didScanPeripheralState:newPeripheral:)]) {
            [self.delegate didScanPeripheralState:DVBleManagerScanning newPeripheral:nil];
        }
    } else {
        //回调扫描到的新设备
        if (self.delegate && [self.delegate respondsToSelector:@selector(didScanPeripheralState:newPeripheral:)]) {
            [self.delegate didScanPeripheralState:DVBleManagerScanning newPeripheral:peri];
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    DVBlePeripheral *peri = [self.mAllPeripheralDictionary objectForKey:peripheral.identifier.UUIDString];
    if (!peri) {
        peri = [[DVBlePeripheral alloc] initWithPeripheral:peripheral];
    }

    //连接成功后,会把该设备从重连设备中移除.
    [self.mReconnectPeripheralUUIDs removeObject:peri.identifier];
    //如果没有重连的设备，立刻进入取消重连的步骤，而不是等一段时间后再去判断
    if (self.mReconnectPeripheralUUIDs.count == 0) {
        [self cancelReconnect];
    }
    //重置信号量, 清空服务值, 重置重连次数
    [peri reset];
    [peri setDelegate:self];

    NSLog(@"外设(%@)......建立临时连接",peri.name);
    if (self.needDiscoverAllServicesAndCharacteristics) {
        //建立连接后，会去搜索服务和特征值
        if (self.delegate && [self.delegate respondsToSelector:@selector(didConnectToPeripheral:state:)]) {
            [self.delegate didConnectToPeripheral:peri state:DVBleManagerConnectDiscovering];
        }
        [peri discoverAllServicesAndCharacteristics];
    } else {
        NSLog(@"搜索服务和特征值......不需要");
        NSLog(@"外设(%@)......正式连接",peripheral.name);
        [self.mConnectTimer invalidate];
        //添加到已连接的设备
        if (![self.mConnectPeripheralUUIDs containsObject:peri.identifier]) {
            [self.mConnectPeripheralUUIDs addObject:peri.identifier];
            self.mLastConnectedPeripheralUUIDs = self.mConnectPeripheralUUIDs.mutableCopy;
        }
        //监听值
        if (self.notifyPeriCharacteristicBlock) {
            self.notifyPeriCharacteristicBlock(peri);
        }

        //回调已连接
        if (self.delegate && [self.delegate respondsToSelector:@selector(didConnectToPeripheral:state:)]) {
            [self.delegate didConnectToPeripheral:peri state:DVBleManagerConnectSuccess];
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    DVBlePeripheral *peri = [self.mAllPeripheralDictionary objectForKey:peripheral.identifier.UUIDString];
    if (!peri) {
        peri = [[DVBlePeripheral alloc] initWithPeripheral:peripheral];
    }

    //添加到重连列表中. 当超过最多重连次数, 会自动移除
    if (![self.mReconnectPeripheralUUIDs containsObject:peri.identifier]) {
        //重置信号量, 清空服务值, 重置重连次数
        [peri reset];
        //添加到重连列表中的
        [self.mReconnectPeripheralUUIDs addObject:peri.identifier];
    }
    //尝试重连
    if (self.isEnableReconnect && (self.maxReconnectTimes == -1 || peri.reconnectTimes < self.maxReconnectTimes)) {
        //打开了重连, 并且当前还有重连的机会的时候, 执行 重连 操作
        [self reconnect];
    } else {
        //不开启重连 或者 重连失败
        //连接失败的回调
        NSLog(@"外设(%@)......连接失败(原因:%@)",peripheral.name,error.description);
        if (self.delegate && [self.delegate respondsToSelector:@selector(didConnectFailedToPeripheral:error:)]) {
            [self.delegate didConnectFailedToPeripheral:peri error:DVBleManagerConnectErrorConnectFailed];
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    DVBlePeripheral *peri = [self.mAllPeripheralDictionary objectForKey:peripheral.identifier.UUIDString];
    if (!peri) {
        peri = [[DVBlePeripheral alloc] initWithPeripheral:peripheral];
    }
    if (!error) {
        //判断是不是当前连接中的设备
        if ([self.mConnectPeripheralUUIDs containsObject:peri.identifier]) {
            //对已经连接成功(如果开启了发现特征值的, 包括已经发现服务和特征值)的设备 断开连接.
            NSLog(@"外设(%@)......用户主动断开连接",peri.name);
            //从当前连接的设备中删掉
            [self.mConnectPeripheralUUIDs removeObject:peri.identifier];
            self.mLastConnectedPeripheralUUIDs = self.mConnectPeripheralUUIDs.mutableCopy;
            //回调断开连接
            if (self.delegate && [self.delegate respondsToSelector:@selector(didDisConnectedToPeripheral:isActive:)]) {
                [self.delegate didDisConnectedToPeripheral:peri isActive:YES];
            }
        } else {
            //对连接过程中(包括发现服务和特征值的过程中)的设备 取消连接. 不需要做任何操作
            NSLog(@"外设(%@)......(取消连接或断开临时连接)",peri.name);
        }
    } else {
        //从当前连接的设备中删掉
        [self.mConnectPeripheralUUIDs removeObject:peri.identifier];
        //非正常断开连接, 进入断开的回调
        NSLog(@"外设(%@)......非正常断开连接(原因:%@)",peri.name, error.description);
        if (self.delegate && [self.delegate respondsToSelector:@selector(didDisConnectedToPeripheral:isActive:)]) {
            [self.delegate didDisConnectedToPeripheral:peri isActive:NO];
        }
        /*非主动断开连接，会尝试重连*/
        //添加到重连列表中. 当超过最多重连次数, 会自动移除
        if (![self.mReconnectPeripheralUUIDs containsObject:peri.identifier]) {
            //如果是新添加到重连列表中的
            [self.mReconnectPeripheralUUIDs addObject:peri.identifier];
            //重置信号量, 清空服务值, 重置重连次数
            [peri reset];
        }
        if (self.isEnableReconnect && (self.maxReconnectTimes == -1 || peri.reconnectTimes < self.maxReconnectTimes)) {
            //打开了重连, 并且当前还有重连的机会的时候, 执行 重连 操作
            [self reconnect];
        }
    }
}

#pragma mark - DVPeripheralDelegate
- (void)didPeripheralFinishDiscoveredServicesAndCharacteristics:(DVBlePeripheral *)peripheral error:(nullable NSError *)error {
    //取消连接超时
    [self.mConnectTimer invalidate];
    if (error) {
        // 发现服务和特征值有问题
        //     .......   (如果是因为这个原因而失败的话, 不会开启<重连>的功能. 因为连接是没有问题的.)
        NSLog(@"查找所需服务和特征值......失败(原因: %@)", error);
        NSLog(@"外设(%@)......连接失败(未找到所需服务和特征值)",peripheral.name);
        [self.manager cancelPeripheralConnection:peripheral.peripheral];
        if (self.delegate && [self.delegate respondsToSelector:@selector(didConnectFailedToPeripheral:error:)]) {
            [self.delegate didConnectFailedToPeripheral:peripheral error:DVBleManagerConnectErrorNotParied];
        }
    }
    //筛选服务和特征值
    if (self.connectPeriFilterBlock) {
        //如果有设置筛选条件的话
        //回调已连接
        if (self.delegate && [self.delegate respondsToSelector:@selector(didConnectToPeripheral:state:)]) {
            [self.delegate didConnectToPeripheral:peripheral state:DVBleManagerConnectFiltering];
        }
        if (self.connectPeriFilterBlock(peripheral)) {
            //符合筛选条件
            NSLog(@"查找所需服务和特征值......成功");
            NSLog(@"外设(%@)......正式连接",peripheral.name);
            //添加到已连接的设备
            if (![self.mConnectPeripheralUUIDs containsObject:peripheral.identifier]) {
                [self.mConnectPeripheralUUIDs addObject:peripheral.identifier];
                self.mLastConnectedPeripheralUUIDs = self.mConnectPeripheralUUIDs.mutableCopy;
            }
            //监听值
            if (self.notifyPeriCharacteristicBlock) {
                self.notifyPeriCharacteristicBlock(peripheral);
            }

            //回调已连接
            if (self.delegate && [self.delegate respondsToSelector:@selector(didConnectToPeripheral:state:)]) {
                [self.delegate didConnectToPeripheral:peripheral state:DVBleManagerConnectSuccess];
            }
        } else {
            //不符合筛选条件.
            //     .......   (如果是因为这个原因而失败的话, 不会开启<重连>的功能. 理由不赘述)
            NSLog(@"查找所需服务和特征值......失败");
            NSLog(@"外设(%@)......连接失败(未找到所需服务和特征值)",peripheral.name);
            [self.manager cancelPeripheralConnection:peripheral.peripheral];
            if (self.delegate && [self.delegate respondsToSelector:@selector(didConnectFailedToPeripheral:error:)]) {
                [self.delegate didConnectFailedToPeripheral:peripheral error:DVBleManagerConnectErrorNotParied];
            }
        }
    } else {
        //如果没有设置筛选条件
        NSLog(@"外设(%@)......正式连接",peripheral.name);
        //监听值
        if (self.notifyPeriCharacteristicBlock) {
            self.notifyPeriCharacteristicBlock(peripheral);
        }
        //添加到已连接的设备
        if (![self.mConnectPeripheralUUIDs containsObject:peripheral.identifier]) {
            [self.mConnectPeripheralUUIDs addObject:peripheral.identifier];
            self.mLastConnectedPeripheralUUIDs = self.mConnectPeripheralUUIDs.mutableCopy;
        }
        //回调已连接
        if (self.delegate && [self.delegate respondsToSelector:@selector(didConnectToPeripheral:state:)]) {
            [self.delegate didConnectToPeripheral:peripheral state:DVBleManagerConnectSuccess];
        }
    }
}


#pragma mark - 数据回调
/**
 写入 回调
 
 @param peripheral 写入的外设
 @param result 写入结果
 */
- (void)didPeripheralWriteData:(DVBlePeripheral *)peripheral
            characteristicUUID:(NSString *)characteristicUUID
                   resultState:(DVBlePeripheralWriteState)result {
    if (result == DVBlePeripheralWriteStateSuccess) {
        NSLog(@"外设(%@)......发送数据成功",peripheral.name);
    } else {
        NSLog(@"外设(%@)......发送数据失败",peripheral.name);
    }
    self.writeDataCallbackBlock(peripheral, result, characteristicUUID);
}


/**
 读取回调
 
 @param peripheral 读取外设
 @param characteristicUUID 读取特征值
 @param data 数据
 @param result 结果
 */
- (void)didPeripheralReadData:(DVBlePeripheral *)peripheral
           characteristicUUID:(NSString *)characteristicUUID
                         data:(nullable NSData *)data
                  resultState:(DVBlePeripheralReadState)result {
    
    if (result == DVBlePeripheralReadStateSuccess) {
        NSLog(@"外设(%@)......读取数据成功:%@",peripheral.name,data);
    } else {
        NSLog(@"外设(%@)......读取数据失败",peripheral.name);
    }
    self.readDataCallbackBlock(peripheral, result, characteristicUUID, data);
}

#pragma mark - Setter && Getter
- (NSArray<DVBlePeripheral *> *)allPeripherals {
    return self.mAllPeripheralDictionary.allValues;
}

- (NSArray<DVBlePeripheral *> *)scannedPeripherals {
    NSMutableArray *tempArr = [[NSMutableArray alloc] init];
    for (NSString *uuid in self.mScannedPeripheralUUIDs) {
        DVBlePeripheral *peri = [self.mAllPeripheralDictionary objectForKey:uuid];
        //排除掉已经连接的设备
        if (peri && ![self.mConnectPeripheralUUIDs containsObject:uuid]) {
            [tempArr addObject:peri];
        }
    }
    return tempArr;
}

- (NSArray<DVBlePeripheral *> *)connectedPeripherals {
    NSMutableArray<DVBlePeripheral *> *peripheralArr = [[NSMutableArray alloc] init];
    NSMutableArray<NSString *> *unConnectedUUIDs = [[NSMutableArray alloc] init];
    
    for (NSString *uuidStr in self.mConnectPeripheralUUIDs) {
        DVBlePeripheral *peri = [self.mAllPeripheralDictionary objectForKey:uuidStr];
        if (peri && peri.state == DVBlePeripheralStateConnected) {
            [peripheralArr addObject:peri];
        } else {
            [unConnectedUUIDs addObject:uuidStr];
        }
    }
    //清掉没连接的
    [self.mConnectPeripheralUUIDs removeObjectsInArray:unConnectedUUIDs];
    return peripheralArr;
}

- (NSArray<DVBlePeripheral *> *)reconnectPeripherals {
    NSMutableArray<DVBlePeripheral *> *needReconnectPeripherals = [[NSMutableArray alloc] init];
    for (NSString *uuidStr in self.mReconnectPeripheralUUIDs) {
        DVBlePeripheral *peri = [self.mAllPeripheralDictionary objectForKey:uuidStr];
        if (peri) {
            [needReconnectPeripherals addObject:peri];
        }
    }
    return needReconnectPeripherals;
}

- (void)setMaxConnectedPeripheralsCount:(NSInteger)maxConnectedPeripheralsCount {
    NSAssert(maxConnectedPeripheralsCount >= 1, @"可以连接的外设数量至少1个");
    NSAssert(maxConnectedPeripheralsCount <= 8, @"可以连接的外设数量最多8个");
    _maxConnectedPeripheralsCount = maxConnectedPeripheralsCount;
}

- (void)setMLastConnectedPeripheralUUIDs:(NSArray<NSString *> *)mLastConnectedPeripheralUUIDs {
    [[NSUserDefaults standardUserDefaults] setObject:mLastConnectedPeripheralUUIDs forKey:DV_LASTCONNECTED_PERIPHERALS_KEY];
}

- (NSArray<NSString *> *)mLastConnectedPeripheralUUIDs {
    return [[NSUserDefaults standardUserDefaults] objectForKey:DV_LASTCONNECTED_PERIPHERALS_KEY];
}

- (void)setScannedPeriFilterBlock:(ScannedPeripheralsFilterBlock)scannedPeriFilterBlock {
    _scannedPeriFilterBlock = scannedPeriFilterBlock;
}

- (void)setConnectPeriFilterBlock:(ConnectedPeripheralsFilterBlock)connectPeriFilterBlock {
    _connectPeriFilterBlock = connectPeriFilterBlock;
}

- (void)setNotifyPeriCharacteristicBlock:(NotifyCharacteristicValueBlock)notifyPeriCharacteristicBlock {
    _notifyPeriCharacteristicBlock = notifyPeriCharacteristicBlock;
}

- (void)setWriteDataCallbackBlock:(WriteDataCallbackBlock)writeDataCallbackBlock {
    _writeDataCallbackBlock = writeDataCallbackBlock;
}

- (void)setReadDataCallbackBlock:(ReadDataCallbackBlock)readDataCallbackBlock {
    _readDataCallbackBlock = readDataCallbackBlock;
}
@end
