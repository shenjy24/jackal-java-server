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
     * scheduled 注解自定义线程池
     */
    @Bean
    public TaskScheduler taskScheduler() {
        ThreadPoolTaskScheduler taskScheduler = new ThreadPoolTaskScheduler();
        taskScheduler.setPoolSize(10);  // 设置线程池大小
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
        // 线程池维护线程的最大数量,只有在缓冲队列满了之后才会申请超过核心线程数的线程
        executor.setMaxPoolSize(maxSize);
        // 缓存队列
        executor.setQueueCapacity(queueCapacity);
        // 允许的空闲时间,当超过了核心线程出之外的线程在空闲时间到达之后会被销毁
        executor.setKeepAliveSeconds(120);
        // 异步方法内部线程名称前缀
        executor.setThreadNamePrefix(prefix);
        /*
         * 当线程池的任务缓存队列已满并且线程池中的线程数目达到maximumPoolSize，如果还有任务到来就会采取任务拒绝策略
         * 通常有以下四种策略：
         * ThreadPoolExecutor.AbortPolicy: 丢弃任务并抛出RejectedExecutionException异常。
         * ThreadPoolExecutor.DiscardPolicy：也是丢弃任务，但是不抛出异常。
         * ThreadPoolExecutor.DiscardOldestPolicy：丢弃队列最前面的任务，然后重新尝试执行任务（重复此过程）
         * ThreadPoolExecutor.CallerRunsPolicy：直接让提交任务的那个线程亲自去执行这个任务的 run() 方法
         */
        executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        executor.initialize();
        return executor;
    }
}
