package com.tech.config.thread;

import lombok.extern.slf4j.Slf4j;
import org.springframework.aop.interceptor.AsyncUncaughtExceptionHandler;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Lazy;
import org.springframework.scheduling.TaskScheduler;
import org.springframework.scheduling.annotation.AsyncConfigurer;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;
import org.springframework.scheduling.concurrent.ThreadPoolTaskScheduler;

import java.util.concurrent.Executor;
import java.util.concurrent.ThreadPoolExecutor;

/**
 * 异步线程池配置
 * <p>
 * 提供两类线程池实现资源隔离，均面向 IO 密集型场景：
 * - bizExecutor：@Async 注解默认池，处理 DB/Cache 等业务 IO 操作
 * - okHttpExecutor：HTTP 调用池，处理外部 HTTP 请求（高延迟）
 *
 * @author shenjy
 * @version 1.0
 * @since 2025-01-06
 */
@Slf4j
@EnableAsync
@EnableScheduling
@Configuration
public class AsyncExecutorConfig implements AsyncConfigurer {

    private final int cores = Runtime.getRuntime().availableProcessors();

    /**
     * 懒加载注入 Spring 管理的 bizExecutor 单例，避免直接调用 @Bean 方法依赖 CGLIB 代理。
     */
    @Lazy
    @Autowired
    @Qualifier("bizExecutor")
    private Executor bizExecutor;

    /**
     * scheduled 注解默认线程池
     */
    @Bean
    public TaskScheduler taskScheduler() {
        ThreadPoolTaskScheduler taskScheduler = new ThreadPoolTaskScheduler();
        taskScheduler.setPoolSize(10);
        taskScheduler.setThreadNamePrefix("scheduled-");
        return taskScheduler;
    }

    /**
     * 业务线程池（@Async 默认使用）
     * 策略：IO 密集型，处理 DB/Cache 操作，中等并发
     */
    @Bean("bizExecutor")
    public Executor bizExecutor() {
        return createExecutor("biz-", cores * 3, cores * 6, 300);
    }

    /**
     * OkHttp 线程池（通过 @Async("okHttpExecutor") 使用）
     * 策略：IO 密集型，线程数多，队列大，适应外部 HTTP 高延迟等待
     */
    @Bean("okHttpExecutor")
    public Executor okHttpExecutor() {
        return createExecutor("okHttp-", cores * 2, cores * 8, 500);
    }

    @Override
    public Executor getAsyncExecutor() {
        return this.bizExecutor;
    }

    @Override
    public AsyncUncaughtExceptionHandler getAsyncUncaughtExceptionHandler() {
        return (ex, method, params) -> log.error("线程池执行任务发送未知错误,执行方法：{}", method.getName(), ex);
    }

    private ThreadPoolTaskExecutor createExecutor(String prefix, int coreSize, int maxSize, int queueCapacity) {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(coreSize);
        executor.setMaxPoolSize(maxSize);
        executor.setQueueCapacity(queueCapacity);
        executor.setKeepAliveSeconds(120);
        executor.setThreadNamePrefix(prefix);
        executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        executor.initialize();
        return executor;
    }
}
