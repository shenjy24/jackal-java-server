-- 允许 root 从任意主机连接并授予完整权限
RENAME USER 'root'@'localhost' TO 'root'@'%';
ALTER USER 'root'@'%' IDENTIFIED BY '123456';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;