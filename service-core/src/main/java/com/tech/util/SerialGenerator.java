package com.tech.util;

import java.text.SimpleDateFormat;
import java.util.Date;

/**
 * 订单号生成器
 *
 * @author Jonas
 * @version 1.0
 * @date 2025-09-24
 */
public class SerialGenerator {

    private static final SimpleDateFormat DATE_FORMAT = new SimpleDateFormat("yyMMddHHmmssSSS");

    /**
     * 生成订单号
     *
     * @return 生成的订单号字符串
     */
    public synchronized String nextId() {
        return nextId("");
    }

    /**
     * 生成订单号
     *
     * @param businessCode 业务类型代码
     * @return 生成的订单号字符串
     */
    public synchronized String nextId(String businessCode) {
        long currentTimestamp = System.currentTimeMillis();

        // 格式化时间戳
        String timestampStr = DATE_FORMAT.format(new Date(currentTimestamp));

        // 拼接订单号
        StringBuilder serial = new StringBuilder();
        serial.append(businessCode); // 业务码
        serial.append(timestampStr); // 时间戳

        try {
            Thread.sleep(10);
        } catch (InterruptedException e) {
            throw new RuntimeException(e);
        }
        return serial.toString();
    }

    public static void main(String[] args) {
        SerialGenerator g = new SerialGenerator();
        for (int i = 0; i < 10; i++) {
            System.out.println(g.nextId(""));
        }
    }
}
