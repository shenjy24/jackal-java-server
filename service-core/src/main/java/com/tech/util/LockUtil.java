package com.tech.util;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;

/**
 * 单机用户锁
 */
public class LockUtil {
    private static final ConcurrentHashMap<String, Lock> lockMap = new ConcurrentHashMap<>();
    private static final Map<Long, Object> queueLockMap = new ConcurrentHashMap<>();
    private static final Map<Long, Object> notifyLockMap = new ConcurrentHashMap<>();

    public static boolean tryLock(Long lockId) {
        return tryLock(String.valueOf(lockId));
    }

    public static boolean tryLock(String LockId) {
        Lock lock = getLock(LockId);
        return lock.tryLock();
    }

    public static void unlock(Long lockId) {
        unlock(String.valueOf(lockId));
    }

    public static void unlock(String lockId) {
        Lock lock = lockMap.remove(lockId);
        if (lock != null) {
            lock.unlock();
        }
    }

    private static Lock getLock(String lockId) {
        lockMap.putIfAbsent(lockId, new ReentrantLock());
        return lockMap.get(lockId);
    }

    public static Object getQueueLock(long queueId) {
        return queueLockMap.computeIfAbsent(queueId, k -> new Object());
    }

    public static Object getNotifyLock(long queueId) {
        return notifyLockMap.computeIfAbsent(queueId, k -> new Object());
    }
}