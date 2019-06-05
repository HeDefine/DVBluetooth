//
//  HexData.h
//  SleepMonitor
//
//  Created by Devine.He on 2017/8/1.
//  Copyright © 2017年 refinedchina. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HexData : NSObject


/**
 将对应16进制字符串转换为相应NSData
 
 @param str 16进制字符串，例：@“FF”
 @return 相应NSData，例子：ff
 */
+ (NSData*)hexStrToData:(NSString *)str;

/**
 将数据转换成相应的十六进制字符串

 @param data 数据
 @return 十六进制字符串
 */
+ (NSString *)dataToHexStr:(NSData *)data;

/**
 将数据转换成相应的十六进制字符串

 @param data 数据
 @param seperator 分隔符
 @return 十六进制字符串
 */
+ (NSString *)dataToHexStr:(NSData *)data seperator:(NSString *)seperator;

/**
 计算校验码，求和取反
 
 @param data Byte数组
 @param len Byte数组长度
 @return 校验码
 */
+ (uint8_t)checksum:(Byte *)data length:(int)len;


/**
 int 转 NSData (4 个字节长度)

 @param Id int型
 @return NSData
 */
+ (NSData *)hexIntToData:(int)Id;

/**
 uint型转data，占 1 (2,4) 个字节

 @param val -
 @param isReverse 是否反转
 @return NSData
 */
+ (NSData *)byteFromUInt8:(uint8_t)val isReverse:(BOOL)isReverse;
+ (NSData *)bytesFromUInt16:(uint16_t)val isReverse:(BOOL)isReverse;
+ (NSData *)bytesFromUInt32:(uint32_t)val isReverse:(BOOL)isReverse;


/**
 NSData转uint型

 @param fData NSData
 @return uINT
 */
+ (uint8_t)uint8FromBytes:(NSData *)fData;
+ (uint16_t)uint16FromBytes:(NSData *)fData;
+ (uint32_t)uint32FromBytes:(NSData *)fData;

//反转字节
+ (NSData *)dataWithReverse:(NSData *)srcData ;

@end


@interface NSString (HexData)

+ (instancetype)hexStringFromData:(NSData *)data;

+ (instancetype)hexStringFromData:(NSData *)data seperator:(NSString *)seperator;
@end

@interface NSData (HexData)

+ (instancetype) dataFromHexString:(NSString *)hexStr;
@end
