package com.tech.service.aliyun;

import com.alibaba.fastjson2.JSON;
import com.aliyun.oss.ClientBuilderConfiguration;
import com.aliyun.oss.OSS;
import com.aliyun.oss.OSSClientBuilder;
import com.aliyun.oss.common.auth.CredentialsProvider;
import com.aliyun.oss.common.auth.DefaultCredentialProvider;
import com.aliyun.oss.common.comm.SignVersion;
import com.aliyun.oss.model.ObjectMetadata;
import com.aliyun.oss.model.PutObjectResult;
import com.tech.common.enums.ErrorCode;
import com.tech.common.enums.FileTypeEnum;
import com.tech.config.property.AliyunProperty;
import com.tech.config.response.bean.BizException;
import com.tech.util.IdUtil;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.SneakyThrows;
import lombok.extern.slf4j.Slf4j;
import org.apache.commons.collections.MapUtils;
import org.apache.commons.io.FilenameUtils;
import org.apache.commons.lang3.StringUtils;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Map;

/**
 * 阿里云OSS服务类
 *
 * @author shenjy
 * @version 1.0
 * @date 2024-09-08
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class OssInvoker {

    private final AliyunProperty property;
    private OSS ossClient;

    @PostConstruct
    public void init() {
        CredentialsProvider credentialsProvider =
                new DefaultCredentialProvider(property.getAccessKeyId(), property.getAccessKeySecret());

        // 创建OSSClient实例。
        ClientBuilderConfiguration clientBuilderConfiguration = new ClientBuilderConfiguration();
        clientBuilderConfiguration.setSignatureVersion(SignVersion.V4);
        ossClient = OSSClientBuilder.create()
                .endpoint(property.getOssEndpoint())
                .credentialsProvider(credentialsProvider)
                .clientConfiguration(clientBuilderConfiguration)
                .region(property.getOssRegion())
                .build();
    }

    /**
     * 上次Base64数据
     *
     * @param fileExtension 文件扩展名
     * @param fileType      文件类型
     * @param base64Data    Base64编码数据
     */
    public String upload(String fileExtension, Integer fileType, Map<String, Object> headers, String base64Data) {
        byte[] data = Base64.getDecoder().decode(base64Data.getBytes(StandardCharsets.UTF_8));
        return this.upload(fileExtension, fileType, headers, data);
    }

    /**
     * 上传某个图片链接
     *
     * @param fileExtension 文件后缀
     * @param fileType      文件类型{@link FileTypeEnum}
     * @param url           文件链接
     * @return 阿里云OSS链接
     */
    @SneakyThrows
    public String upload(String fileExtension, Integer fileType, String url) {
        // 下载图片
        try (InputStream inputStream = new URL(url).openStream()) {
            return upload(fileExtension, fileType, inputStream.readAllBytes());
        }
    }

    /**
     * 上传文件二进制数据
     *
     * @param fileExtension 文件后缀
     * @param fileType      文件类型{@link FileTypeEnum}
     * @param data          文件文件二进制数据链接
     * @return 阿里云OSS链接
     */
    public String upload(String fileExtension, Integer fileType, byte[] data) {
        FileTypeEnum fileTypeEnum = FileTypeEnum.getEnum(fileType);
        if (fileTypeEnum == null) {
            return "";
        }
        String objectName = fileTypeEnum.getPrefix() + "/" + IdUtil.uuid() + "." + fileExtension;
        return this.upload(property.getOssBucket(), objectName, data);
    }

    /**
     * 上传文件二进制数据
     *
     * @param fileExtension 文件后缀
     * @param fileType      文件类型{@link FileTypeEnum}
     * @param headers       头部信息
     * @param data          文件文件二进制数据链接
     * @return 阿里云OSS链接
     */
    public String upload(String fileExtension, Integer fileType, Map<String, Object> headers, byte[] data) {
        FileTypeEnum fileTypeEnum = FileTypeEnum.getEnum(fileType);
        if (fileTypeEnum == null) {
            return "";
        }
        String objectName = fileTypeEnum.getPrefix() + "/" + IdUtil.uuid() + "." + fileExtension;
        return this.upload(property.getOssBucket(), objectName, headers, data);
    }

    /**
     * 上传文件
     *
     * @param bucketName oss bucket
     * @param objectName 文件路径和文件名
     * @param data       文件数据
     */
    public String upload(String bucketName, String objectName, byte[] data) {
        if (StringUtils.isBlank(bucketName) || StringUtils.isBlank(objectName) || data == null || data.length == 0) {
            return "";
        }
        PutObjectResult result = ossClient.putObject(bucketName, objectName, new ByteArrayInputStream(data));
        log.info("oss upload binary data, result:{}", JSON.toJSONString(result));
        return property.getOssUrl() + objectName;
    }

    /**
     * 上传文件
     *
     * @param bucketName oss bucket
     * @param objectName 文件路径和文件名
     * @param data       文件数据
     */
    public String upload(String bucketName, String objectName, Map<String, Object> headers, byte[] data) {
        if (StringUtils.isBlank(bucketName)
                || StringUtils.isBlank(objectName)
                || MapUtils.isEmpty(headers)
                || data == null || data.length == 0) {
            return "";
        }

        // 创建 ObjectMetadata 并设置 Content-Type
        ObjectMetadata metadata = new ObjectMetadata();
        for (Map.Entry<String, Object> entry : headers.entrySet()) {
            metadata.setHeader(entry.getKey(), entry.getValue());
        }

        PutObjectResult result = ossClient.putObject(bucketName, objectName,
                new ByteArrayInputStream(data), metadata);
        log.info("oss upload binary data, result={}", JSON.toJSONString(result));
        return property.getOssUrl() + objectName;
    }

    /**
     * 上传文件
     *
     * @param file 文件
     * @return 文件路径
     */
    public String upload(MultipartFile file) {
        if (file == null) {
            return "";
        }
        String objectName = "default/";
        String contentType = file.getContentType();
        if (StringUtils.isNotBlank(contentType)) {
            // 判断是否为图片类型
            if (contentType.startsWith(FileTypeEnum.IMAGE.getPrefix())) {
                objectName = FileTypeEnum.IMAGE.getPrefix();
            }
            // 判断是否为音频类型
            else if (contentType.startsWith(FileTypeEnum.AUDIO.getPrefix())) {
                objectName = FileTypeEnum.AUDIO.getPrefix();
            }
            // 判断是否为视频类型
            else if (contentType.startsWith(FileTypeEnum.VIDEO.getPrefix())) {
                objectName = FileTypeEnum.VIDEO.getPrefix();
            }
        }
        objectName = objectName + "/" + IdUtil.uuid() + "."
                + FilenameUtils.getExtension(file.getOriginalFilename());
        try {
            return this.upload(property.getOssBucket(), objectName, file.getBytes());
        } catch (IOException e) {
            log.error("oss upload error", e);
            throw new BizException(ErrorCode.ALIYUN_ERROR1);
        }
    }

    /**
     * 删除OSS文件
     *
     * @param url 阿里云OSS链接
     */
    public void delete(String url) {
        if (StringUtils.isBlank(url)) {
            log.error("删除OSS数据，参数为空");
            return;
        }
        String objectName = url.substring(property.getOssUrl().length());
        ossClient.deleteObject(property.getOssBucket(), objectName);
        log.info("删除OSS数据, bucket:{}, objectName:{}", property.getOssBucket(), objectName);
    }

    /**
     * 异步删除OSS文件
     *
     * @param url 阿里云OSS链接
     */
    @Async
    public void deleteAsync(String url) {
        if (StringUtils.isNotBlank(url)) {
            this.delete(url);
        }
    }
}
