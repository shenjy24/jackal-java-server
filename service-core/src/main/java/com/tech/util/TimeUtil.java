package com.tech.util;

import com.tech.common.constant.Constants;

import java.sql.Timestamp;
import java.time.*;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;

/**
 * 时间工具类
 *
 * @author shenjy
 * @version 1.0
 * @date 2025-01-06
 */
public class TimeUtil {
    public static final String FORMAT_YYYY_MM_DD = "yyyy-MM-dd";
    public static final String FORMAT_YYYY_MM_DD_HH_MM_SS = "yyyy-MM-dd HH:mm:ss";
    public static final String FORMAT_ZERO_ZONE = "yyyy-MM-dd'T'HH:mm:ss'Z'";
    public static final Integer MINUTE_SECOND = 60;
    public static final Integer HOUR_SECOND = 60 * 60;
    public static final Integer DAY_SECOND = HOUR_SECOND * 24;
    public static final Integer MONTH_SECOND = DAY_SECOND * 30;
    public static final Integer YEAR_SECOND = MONTH_SECOND * 12;

    public static String getStringFromDate(LocalDate date) {
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern(FORMAT_YYYY_MM_DD);
        return formatter.format(date);
    }

    public static String getStringFromDateTime(LocalDateTime dateTime) {
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern(FORMAT_YYYY_MM_DD_HH_MM_SS);
        return formatter.format(dateTime);
    }

    /**
     * 毫秒时间戳 转化为 "yyyy-MM-dd"
     *
     * @param stamp 毫秒时间戳
     * @return "yyyy-MM-dd"格式时间字符串
     */
    public static String getDateStringFromStamp(Long stamp) {
        LocalDate localDate = Instant.ofEpochMilli(stamp).atZone(ZoneId.systemDefault()).toLocalDate();
        return localDate.format(DateTimeFormatter.ofPattern(FORMAT_YYYY_MM_DD));
    }

    /**
     * 毫秒时间戳 转化为 "yyyy-MM-dd HH:mm:ss"
     *
     * @param stamp 毫秒时间戳
     * @return "yyyy-MM-dd HH:mm:ss"格式时间字符串
     */
    public static String getDateTimeStringFromStamp(Long stamp) {
        LocalDate localDate = Instant.ofEpochMilli(stamp).atZone(ZoneId.systemDefault()).toLocalDate();
        return localDate.format(DateTimeFormatter.ofPattern(FORMAT_YYYY_MM_DD_HH_MM_SS));
    }

    /**
     * "yyyy-MM-dd"格式 转化为 毫秒时间戳
     *
     * @param date "yyyy-MM-dd"格式日期
     * @return 毫秒时间戳
     */
    public static Long getStampFromDate(String date) {
        LocalDate localDate = LocalDate.parse(date, DateTimeFormatter.ofPattern(FORMAT_YYYY_MM_DD));
        LocalDateTime localDateTime = localDate.atStartOfDay();
        return localDateTime.toInstant(ZoneOffset.of("+8")).toEpochMilli();
    }

    /**
     * "yyyy-MM-dd HH:mm:ss"格式 转化为 毫秒时间戳
     *
     * @param dateTime "yyyy-MM-dd HH:mm:ss"日期
     * @return 毫秒时间戳
     */
    public static Long getStampFromDateTime(String dateTime) {
        LocalDateTime localDateTime = LocalDateTime.parse(dateTime, DateTimeFormatter.ofPattern(FORMAT_YYYY_MM_DD_HH_MM_SS));
        return localDateTime.toInstant(ZoneOffset.of("+8")).toEpochMilli();
    }

    public static Long getStampFromDateTime(LocalDateTime dateTime) {
        return dateTime.toInstant(ZoneOffset.of("+8")).toEpochMilli();
    }

    /**
     * 处理0时区时间为本地时间
     *
     * @param time 处理0时区时间
     * @return 毫秒时间戳
     */
    public static Long getStampFromZeroZoneTime(String time) {
        LocalDateTime localDateTime = LocalDateTime.parse(time, DateTimeFormatter.ofPattern(FORMAT_ZERO_ZONE));
        return localDateTime.toInstant(ZoneOffset.UTC).toEpochMilli();
    }

    public static String getZeroZoneTimeString() {
        LocalDateTime now = LocalDateTime.now(ZoneOffset.UTC);
        return now.format(DateTimeFormatter.ofPattern(FORMAT_ZERO_ZONE));
    }

    public static String currentDate() {
        LocalDate now = LocalDate.now();
        return now.format(DateTimeFormatter.ofPattern(FORMAT_YYYY_MM_DD));
    }

    public static String currentDateTime() {
        LocalDateTime now = LocalDateTime.now();
        return now.format(DateTimeFormatter.ofPattern(FORMAT_YYYY_MM_DD_HH_MM_SS));
    }

    /**
     * 秒时间戳
     */
    public static int currentSecond() {
        return Long.valueOf(System.currentTimeMillis() / 1000).intValue();
    }

    /**
     * 当前时间
     */
    public static Timestamp currentTimestamp() {
        return new Timestamp(System.currentTimeMillis());
    }

    /**
     * 秒时间戳
     */
    public static int toSecond(Long millisecond) {
        return Long.valueOf(millisecond / 1000).intValue();
    }

    public static LocalDateTime getDateTime(String dateTime) {
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern(FORMAT_YYYY_MM_DD_HH_MM_SS);
        return LocalDateTime.parse(dateTime, formatter);
    }

    public static LocalDateTime getDateTime(Long timestamp) {
        Instant instant = Instant.ofEpochSecond(timestamp);
        return LocalDateTime.ofInstant(instant, ZoneId.systemDefault());
    }

    /**
     * 获取token的过期时间
     *
     * @return token的过期时间
     */
    public static Timestamp getTokenExpireTime() {
        long timestamp = System.currentTimeMillis() + Constants.TOKEN_EXPIRED_MS;
        return new Timestamp(timestamp);
    }

    /**
     * 获取某天的开始
     *
     * @param timestamp 指定时间
     * @return 某天的开始
     */
    public static Timestamp getDayStart(Timestamp timestamp) {
        LocalDateTime dateTime = getDateTime(timestamp.getTime());
        LocalDateTime dayStart = LocalDateTime.of(dateTime.toLocalDate(), LocalTime.of(0, 0, 0));
        return new Timestamp(getStampFromDateTime(dayStart));
    }

    /**
     * 获取某天的结束
     *
     * @param timestamp 指定时间
     * @return 某天的结束
     */
    public static Timestamp getDayEnd(Timestamp timestamp) {
        LocalDateTime dateTime = getDateTime(timestamp.getTime());
        LocalDateTime dayEnd = LocalDateTime.of(dateTime.toLocalDate(), LocalTime.of(23, 59, 59));
        return new Timestamp(getStampFromDateTime(dayEnd));
    }

    public static Timestamp getNextTimestamp(Timestamp startDay, Integer durationValue, ChronoUnit unit) {
        LocalDate localDate = startDay.toLocalDateTime().toLocalDate();
        LocalDate nextDate = localDate.plus(durationValue, unit);
        LocalTime nextTime = LocalTime.of(23, 59, 59);
        LocalDateTime nextDateTime = LocalDateTime.of(nextDate, nextTime);
        return new Timestamp(nextDateTime.toInstant(ZoneOffset.ofHours(8)).toEpochMilli());
    }
}
