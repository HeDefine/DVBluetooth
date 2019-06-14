# DVBluetooth

## 简介
该Manager 主要是在 CoreBluetooth 的基础上再次封装。

## 安装

### 1. 手动安装
1. 下载本项目Zip,并解压.
2. 拖取DVBluetooth/DVBluetooth文件夹到你的项目中
3. 导入本项目 `import "DVBluetooth/DVBluetooth.h"`

### 2.Cocoapod 安装
1. 安装Cocoapod, 并在根目录下运行 `pod init`
2. 在`Podfile`文件中输入
```
pod 'DVBluetooth','~> 0.3.0'
```
3. 命令行运行`pod update`

## 使用方法
建议新建一个类，继承原有的 DVBleManager 以及新建一个 Protocol . 对收到的数据处理后可以通过协议回调

根据自己项目的需求，在这个类里面可以自定义 1. 特征值的UUID  2.对回调数据的处理  3.处理发送数据的方式

#### 1. 配置
```objc
#define UUIDWriteDataService  @"FFE5"
#define UUIDWriteDataCharateristic @"FFE9"
#define UUIDReadDataService  @"FFE0"
#define UUIDReadDataCharateristic @"FFE4"

#define UUIDInfoService  @"FF90"
#define UUIDDeviceNameCharateristic @"FF91"

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
```
#### 2. 读取和写入回调的复写, 主要用来对回调数据的处理
```objc
/**
 写入 回调
 */
- (void)didPeripheralWriteData:(DVBlePeripheral *)peripheral
            characteristicUUID:(NSString *)characteristicUUID
                   resultState:(DVBlePeripheralWriteState)result {
    if ([characteristicUUID isEqualToString:UUIDWriteDataCharateristic]) {
        /****    发送数据回调    ****/
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
        /****    处理数据      ***/
    }
}
```
#### 3. 写入方法
```objc
#pragma mark - 个性化设置
- (void)writeData:(NSString *)dataStr {
    if (self.connectedPeripherals.count == 0) {
        NSLog(@"当前没有连接的设备");
        return;
    }
    //将十六进制字符串转换成NSData型。
    NSData *data = [NSData dataFromHexString:dataStr];
    //发送数据
    [self writeDataToPeripheral:self.connectedPeripherals.firstObject
           onCharacteristicUUID:UUIDWriteDataCharateristic
                       withData:data];
}

//头部抬起指令
- (void)headup {
    [self writeData:@"FFFFFFFFFFFF"];
}
```
