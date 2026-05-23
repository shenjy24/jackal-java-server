package com.tech.util;

import com.google.common.base.Joiner;
import com.google.common.base.Splitter;
import org.apache.commons.lang3.StringUtils;
import org.springframework.util.CollectionUtils;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.Collections;
import java.util.List;

/**
 * StringUtil
 *
 * @author shenjy
 * @version 1.0
 * @date 2025-01-07
 */
public class StrUtil {

    public static List<String> split(String str) {
        if (StringUtils.isBlank(str)) {
            return Collections.emptyList();
        }
        Splitter split = Splitter.on(',').trimResults().omitEmptyStrings(); // 去前后空格&&去空string
        return split.splitToList(str);
    }

    public static String join(List<String> list) {
        if (CollectionUtils.isEmpty(list)) {
            return "";
        }
        return Joiner.on(",").join(list);
    }

    /**
     * 去掉括号里的文本
     *
     * @param str 文本
     * @return 文本
     */
    public static String removeBracketsContent(String str) {
        // 使用正则表达式匹配中文括号（）和英文括号()
        return str.replaceAll("（.*?）|\\(.*?\\)", "");
    }

    /**
     * URL编码
     * 使用UTF-8字符集按照RFC3986规则编码请求参数和参数取值。
     */
    public static String percentEncode(String value) {
        return value != null ? URLEncoder.encode(value, StandardCharsets.UTF_8).replace("+", "%20")
                .replace("*", "%2A").replace("%7E", "~") : null;
    }

    public static String convertFenToYuan(int fen) {
        BigDecimal yuan = BigDecimal.valueOf(fen)
                .divide(BigDecimal.valueOf(100), 2, RoundingMode.DOWN);
        return yuan.toPlainString();
    }

    public static String convertFenToYuan2(int fen) {
        BigDecimal yuan = BigDecimal.valueOf(fen)
                .divide(BigDecimal.valueOf(100), 2, RoundingMode.DOWN);

        // 转换为字符串并检查是否为整数
        String result = yuan.toPlainString();
        if (result.endsWith(".00")) {
            // 去除末尾的 ".00"
            result = result.substring(0, result.length() - 3);
        }
        return result;
    }
}
