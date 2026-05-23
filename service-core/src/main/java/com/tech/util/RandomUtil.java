package com.tech.util;

import java.security.SecureRandom;

/**
 * 随机工具类
 *
 * @author shenjy
 * @version 1.0
 * @date 2025-01-07
 */
public class RandomUtil {

    private static final SecureRandom random = new SecureRandom();

    private static final String UPPER_LETTER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    private static final String LOWE_LETTER = "abcdefghijklmnopqrstuvwxyz";
    private static final String UPPER_CHARACTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    private static final String LOWER_CHARACTERS = "abcdefghijklmnopqrstuvwxyz0123456789";

    /**
     * 获取范围内的随机数字
     *
     * @param min 最小值
     * @param max 最大值
     * @return 获取范围内的随机数字
     */
    public static int randomNumber(int min, int max) {
        return random.nextInt(max - min + 1) + min;
    }

    /**
     * 获取指定位数的随机码
     *
     * @param numberOfDigits 位数
     * @return 随机码
     */
    public static String randomCode(int numberOfDigits) {
        return randomCode(numberOfDigits, true);
    }

    /**
     * 获取指定位数的随机码
     *
     * @param numberOfDigits 位数
     * @param upper          是否大写
     * @return 随机码
     */
    public static String randomCode(int numberOfDigits, boolean upper) {
        StringBuilder code = new StringBuilder(numberOfDigits);
        String characters = upper ? UPPER_CHARACTERS : LOWER_CHARACTERS;
        for (int i = 0; i < numberOfDigits; i++) {
            int index = random.nextInt(characters.length());
            code.append(characters.charAt(index));
        }
        return code.toString();
    }

    /**
     * 字母开头
     *
     * @return 字母开头的随机字符串
     */
    public static String randomStr(int numberOfDigits) {
        StringBuilder code = new StringBuilder(numberOfDigits);
        for (int i = 0; i < numberOfDigits; i++) {
            if (i == 0) {
                // 以字母开头
                int index = random.nextInt(LOWE_LETTER.length());
                code.append(LOWE_LETTER.charAt(index));
            } else {
                int index = random.nextInt(LOWER_CHARACTERS.length());
                code.append(LOWER_CHARACTERS.charAt(index));
            }
        }
        return code.toString();
    }

    /**
     * 产生随机数
     *
     * @param numberOfDigits 随机数位数
     * @return 随机数
     */
    public static String randomNumber(int numberOfDigits) {
        SecureRandom secureRandom = new SecureRandom();

        // 计算出对应位数的最大值和最小值
        int minValue = (int) Math.pow(10, numberOfDigits - 1);
        int maxValue = (int) Math.pow(10, numberOfDigits) - 1;

        // 生成一个[minValue, maxValue]之间的随机数
        int code = secureRandom.nextInt(maxValue - minValue + 1) + minValue;
        return String.valueOf(code);
    }
}
