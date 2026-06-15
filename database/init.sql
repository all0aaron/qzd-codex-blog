CREATE DATABASE IF NOT EXISTS `blog_db`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE `blog_db`;

DROP TABLE IF EXISTS `post_tag`;
DROP TABLE IF EXISTS `comment`;
DROP TABLE IF EXISTS `post`;
DROP TABLE IF EXISTS `tag`;
DROP TABLE IF EXISTS `category`;
DROP TABLE IF EXISTS `site_setting`;
DROP TABLE IF EXISTS `admin_user`;

CREATE TABLE `admin_user` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `username` VARCHAR(50) NOT NULL COMMENT '管理员账号',
  `password_hash` VARCHAR(255) NOT NULL COMMENT '密码哈希',
  `role` VARCHAR(30) NOT NULL DEFAULT 'admin' COMMENT '角色',
  `status` VARCHAR(20) NOT NULL DEFAULT 'enabled' COMMENT '状态：enabled/disabled',
  `last_login_time` DATETIME NULL COMMENT '最后登录时间',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `is_deleted` TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除：0未删除，1已删除',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_admin_user_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='后台管理员表';

CREATE TABLE `category` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `name` VARCHAR(80) NOT NULL COMMENT '分类名称',
  `slug` VARCHAR(120) NOT NULL COMMENT '分类URL标识',
  `description` VARCHAR(255) NULL COMMENT '分类描述',
  `sort_order` INT NOT NULL DEFAULT 0 COMMENT '排序值',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `is_deleted` TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除：0未删除，1已删除',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_category_slug` (`slug`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='文章分类表';

CREATE TABLE `tag` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `name` VARCHAR(80) NOT NULL COMMENT '标签名称',
  `slug` VARCHAR(120) NOT NULL COMMENT '标签URL标识',
  `color` VARCHAR(20) NOT NULL DEFAULT '#0f766e' COMMENT '标签颜色',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `is_deleted` TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除：0未删除，1已删除',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_tag_slug` (`slug`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='文章标签表';

CREATE TABLE `post` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `category_id` BIGINT NOT NULL COMMENT '分类ID',
  `title` VARCHAR(180) NOT NULL COMMENT '文章标题',
  `slug` VARCHAR(180) NOT NULL COMMENT '文章URL标识',
  `summary` VARCHAR(500) NOT NULL COMMENT '文章摘要',
  `content` LONGTEXT NOT NULL COMMENT '文章正文',
  `cover_url` VARCHAR(500) NULL COMMENT '封面图地址',
  `status` VARCHAR(20) NOT NULL DEFAULT 'draft' COMMENT '状态：draft/published',
  `featured` TINYINT NOT NULL DEFAULT 0 COMMENT '是否首页推荐',
  `read_count` INT NOT NULL DEFAULT 0 COMMENT '阅读次数',
  `publish_time` DATETIME NULL COMMENT '发布时间',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `is_deleted` TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除：0未删除，1已删除',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_post_slug` (`slug`),
  KEY `idx_post_category_status` (`category_id`, `status`),
  KEY `idx_post_publish_time` (`publish_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='文章表';

CREATE TABLE `post_tag` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `post_id` BIGINT NOT NULL COMMENT '文章ID',
  `tag_id` BIGINT NOT NULL COMMENT '标签ID',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `is_deleted` TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除：0未删除，1已删除',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_post_tag` (`post_id`, `tag_id`),
  KEY `idx_post_tag_tag_id` (`tag_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='文章标签关联表';

CREATE TABLE `comment` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `post_id` BIGINT NOT NULL COMMENT '文章ID',
  `nickname` VARCHAR(80) NOT NULL COMMENT '评论昵称',
  `email` VARCHAR(120) NOT NULL COMMENT '评论邮箱',
  `content` VARCHAR(1200) NOT NULL COMMENT '评论内容',
  `status` VARCHAR(20) NOT NULL DEFAULT 'pending' COMMENT '状态：pending/approved/hidden',
  `reply_content` VARCHAR(1200) NULL COMMENT '作者回复内容',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `is_deleted` TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除：0未删除，1已删除',
  PRIMARY KEY (`id`),
  KEY `idx_comment_post_status` (`post_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='评论表';

CREATE TABLE `site_setting` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `setting_key` VARCHAR(80) NOT NULL COMMENT '配置键',
  `setting_value` TEXT NOT NULL COMMENT '配置值',
  `group_name` VARCHAR(50) NOT NULL DEFAULT 'base' COMMENT '配置分组',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `is_deleted` TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除：0未删除，1已删除',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_site_setting_key` (`setting_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='站点配置表';

INSERT INTO `admin_user` (`username`, `password_hash`, `role`, `status`)
VALUES ('admin', '$2b$10$demo.hash.replace.in.production', 'admin', 'enabled');

INSERT INTO `category` (`id`, `name`, `slug`, `description`, `sort_order`) VALUES
(1, '工程实践', 'engineering', '项目开发、架构和代码实践', 1),
(2, '产品复盘', 'product-review', '产品设计、业务流程和体验复盘', 2),
(3, '内容运营', 'content-ops', '写作、标签和内容组织', 3),
(4, '生活记录', 'life-notes', '工作之外的观察和记录', 4);

INSERT INTO `tag` (`id`, `name`, `slug`, `color`) VALUES
(1, '架构', 'architecture', '#0f766e'),
(2, 'Node.js', 'nodejs', '#2563eb'),
(3, 'MySQL', 'mysql', '#b45309'),
(4, '写作', 'writing', '#7c3aed'),
(5, '后台设计', 'admin-design', '#0f172a'),
(6, '信息架构', 'information-architecture', '#be123c');

INSERT INTO `site_setting` (`setting_key`, `setting_value`, `group_name`) VALUES
('siteName', '墨丘', 'base'),
('siteTitle', '墨丘 - 产品、代码与长期思考', 'base'),
('siteDescription', '墨丘博客聚合技术实践、产品复盘和个人知识库内容，帮助读者从真实项目中获得可复用的经验。', 'base'),
('keywords', '博客, 产品复盘, 工程实践, 内容系统', 'seo'),
('authorName', '秦知远', 'author'),
('authorBio', '产品工程师，关注内容系统、自动化工具和长期写作。', 'author'),
('authorAvatar', 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=200&q=80', 'author');
