package com.tech.config.thread;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.aop.interceptor.AsyncUncaughtExceptionHandler;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
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
 *
 * @author shenjy
 * @version 1.0
 * @since 2025-01-06
 */
@Slf4j
@EnableAsync
@EnableScheduling
@Configuration
@RequiredArgsConstructor
public class AsyncExecutorConfig implements AsyncConfigurer {

    /**
     * Scheduled 注解自定义线程池
     */
    @Bean
    public TaskScheduler taskScheduler() {
        ThreadPoolTaskScheduler taskScheduler = new ThreadPoolTaskScheduler();
        taskScheduler.setPoolSize(10); // 设置线程池大小
        taskScheduler.setThreadNamePrefix("scheduled-task-"); // 设置线程名称前缀
        return taskScheduler;
    }

    /**
     * Async 注解使用的线程池
     */
    @Bean("asyncExecutor")
    public ThreadPoolTaskExecutor asyncExecutor() {
        return this.createExecutor("async-");
    }

    /**
     * 业务使用的线程池
     */
    @Bean("bizExecutor")
    public ThreadPoolTaskExecutor bizExecutor() {
        return this.createExecutor("biz-");
    }

    /**
     * okHttp 使用的线程池
     */
    @Bean("okHttpExecutor")
    public ThreadPoolTaskExecutor okHttpExecutor() {
        return this.createExecutor("okHttp-");
    }

    /**
     * 配置默认线程池
     *
     * @return 线程池实例
     */
    @Override
    public Executor getAsyncExecutor() {
        return asyncExecutor();
    }

    @Override
    public AsyncUncaughtExceptionHandler getAsyncUncaughtExceptionHandler() {
        return (ex, method, params) -> log.error("线程池执行任务发送未知错误,执行方法：{}", method.getName(), ex);
    }

    private ThreadPoolTaskExecutor createExecutor(String prefix) {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        // 核心线程数：CPU核数 * 2
        int cores = Runtime.getRuntime().availableProcessors();
        executor.setCorePoolSize(cores * 2);
        // 线程池维护线程的最大数量,只有在缓冲队列满了之后才会申请超过核心线程数的线程
        // 最大线程数：核心线程数的 5 倍
        executor.setMaxPoolSize(cores * 10);
        // 缓存队列
        executor.setQueueCapacity(100);
        // 允许的空闲时间,当超过了核心线程出之外的线程在空闲时间到达之后会被销毁
        executor.setKeepAliveSeconds(120);
        // 异步方法内部线程名称前缀
        executor.setThreadNamePrefix(prefix);
        /*
         * 当线程池的任务缓存队列已满并且线程池中的线程数目达到maximumPoolSize，如果还有任务到来就会采取任务拒绝策略
         * 通常有以下四种策略：
         * ThreadPoolExecutor.AbortPolicy:丢弃任务并抛出RejectedExecutionException异常。
         * ThreadPoolExecutor.DiscardPolicy：也是丢弃任务，但是不抛出异常。
         * ThreadPoolExecutor.DiscardOldestPolicy：丢弃队列最前面的任务，然后重新尝试执行任务（重复此过程）
         * ThreadPoolExecutor.CallerRunsPolicy：重试添加当前的任务，自动重复调用 execute() 方法，直到成功
         */
        executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        executor.initialize();
        return executor;
    }
}
