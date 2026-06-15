USE `blog_db`;

INSERT INTO `post` (`id`, `category_id`, `title`, `slug`, `summary`, `content`, `cover_url`, `status`, `featured`, `read_count`, `publish_time`) VALUES
(1, 1, '一个小型内容系统从 0 到 1 的架构取舍', 'content-system-architecture', '从页面、接口、数据库和发布流程四个层面拆解博客系统。', '一个博客系统看起来简单，但真正落地时会同时牵涉内容模型、发布状态、评论审核、检索体验和后台权限。', 'https://images.unsplash.com/photo-1555066931-4365d14bab8c?auto=format&fit=crop&w=900&q=80', 'published', 1, 2846, '2026-06-12 10:18:00'),
(2, 3, '如何设计一个不会变成杂物间的标签系统', 'tag-system-design', '标签不是越多越好，命名、合并、颜色和归档策略会影响内容查找效率。', '标签系统的目标不是展示数量，而是帮助读者在不同文章之间建立主题连接。', 'https://images.unsplash.com/photo-1456324504439-367cee3b3c32?auto=format&fit=crop&w=900&q=80', 'published', 0, 1982, '2026-06-08 21:06:00'),
(3, 2, '后台管理页为什么要先服务高频动作', 'admin-high-frequency-actions', '后台管理页应该优先服务文章发布、评论审核和站点配置。', '后台不是展示页面，而是工作台。真正高频的动作包括新建文章、保存草稿、发布、审核评论和查看异常状态。', 'https://images.unsplash.com/photo-1497366811353-6870744d04b2?auto=format&fit=crop&w=900&q=80', 'published', 1, 1260, '2026-06-14 16:30:00'),
(4, 3, '一次评论审核策略调整记录', 'comment-review-policy', '记录从开放评论到审核评论的策略变化。', '评论系统应该默认保护前台内容质量。未审核评论进入待处理列表，管理员通过后再展示。', 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=900&q=80', 'draft', 0, 0, NULL),
(5, 1, '接口返回格式统一之后排错效率提高了多少', 'api-response-format', '用统一响应格式降低前后端联调成本。', '统一响应格式能让前端错误处理、后端日志追踪和测试脚本都更稳定。', 'https://images.unsplash.com/photo-1558494949-ef010cbdcc31?auto=format&fit=crop&w=900&q=80', 'published', 0, 735, '2026-05-28 09:00:00'),
(6, 2, '从一个发布按钮看后台权限设计', 'publish-button-permission', '按钮背后是角色、状态和审计记录。', '发布按钮不能只看 UI，它连接的是权限、状态流转和操作审计。', 'https://images.unsplash.com/photo-1518005020951-eccb494ad742?auto=format&fit=crop&w=900&q=80', 'published', 0, 812, '2026-05-21 17:20:00'),
(7, 3, '长期写作的目录结构如何设计', 'writing-directory-structure', '目录结构决定内容能否长期维护。', '长期写作需要稳定分类和阶段性归档，避免所有文章堆在同一个列表里。', 'https://images.unsplash.com/photo-1499750310107-5fef28a66643?auto=format&fit=crop&w=900&q=80', 'published', 0, 1420, '2026-05-12 20:10:00'),
(8, 4, '一次离线写作周末的记录', 'offline-writing-weekend', '关掉通知之后重新整理自己的写作系统。', '离线写作的价值在于减少上下文切换，让想法被完整展开。', 'https://images.unsplash.com/photo-1517486808906-6ca8b3f04846?auto=format&fit=crop&w=900&q=80', 'published', 0, 530, '2026-04-30 11:30:00'),
(9, 1, '为什么首版不应该过早引入复杂权限', 'avoid-complex-permission-first', '权限模型应该跟业务阶段匹配。', '在首版系统中，管理员和编辑两个角色通常已经足够覆盖真实使用场景。', 'https://images.unsplash.com/photo-1516321497487-e288fb19713f?auto=format&fit=crop&w=900&q=80', 'published', 0, 990, '2026-04-18 14:45:00'),
(10, 2, '评论区如何避免变成运营负担', 'comment-section-operation', '评论审核、状态和通知策略需要一起设计。', '评论区要有审核入口、隐藏机制和清晰状态，才能在内容增长后仍然可控。', 'https://images.unsplash.com/photo-1497366412874-3415097a27e7?auto=format&fit=crop&w=900&q=80', 'published', 0, 675, '2026-04-08 08:40:00');

INSERT INTO `post_tag` (`post_id`, `tag_id`) VALUES
(1, 1), (1, 2), (1, 3),
(2, 4), (2, 6),
(3, 5), (3, 6),
(4, 4), (4, 5),
(5, 1), (5, 2),
(6, 5), (6, 6),
(7, 4), (7, 6),
(8, 4),
(9, 1), (9, 5),
(10, 5), (10, 6);

INSERT INTO `comment` (`post_id`, `nickname`, `email`, `content`, `status`, `reply_content`, `create_time`) VALUES
(1, '林北辰', 'linbeichen@example.com', '这篇对分类和标签的边界解释得很清楚，准备按这个思路整理自己的站点。', 'approved', '', '2026-06-13 10:24:00'),
(1, '周予安', 'zhouyuan@example.com', '后台高频动作优先这个点很实用，尤其是评论审核和草稿入口。', 'approved', '是的，后台首屏应该优先服务日常动作。', '2026-06-13 14:48:00'),
(2, '匿名读者', 'reader@example.com', '能否再写一篇关于标签合并策略的文章？我现在遇到多个近义标签重复的问题。', 'pending', '', '2026-06-15 09:58:00'),
(3, '许令仪', 'xulingyi@example.com', '把后台定义成工作台这个说法很准确。', 'approved', '', '2026-06-14 19:12:00'),
(5, '赵以航', 'zhaoyihang@example.com', '统一响应格式确实能减少很多重复判断。', 'approved', '', '2026-05-29 12:05:00'),
(6, '顾南风', 'gunanfeng@example.com', '权限和状态机一起看，这个角度有帮助。', 'approved', '', '2026-05-22 09:40:00'),
(7, '陈砚', 'chenyan@example.com', '我准备把自己的文章也按年度和主题重新整理。', 'approved', '', '2026-05-13 22:18:00'),
(8, '沈栖迟', 'shenqichi@example.com', '离线写作很适合做复盘。', 'approved', '', '2026-05-01 08:10:00'),
(9, '唐一白', 'tangyibai@example.com', '首版权限过重真的会拖慢开发。', 'approved', '', '2026-04-19 16:22:00'),
(10, '叶清和', 'yeqinghe@example.com', '评论区治理应该提前做基础规则。', 'pending', '', '2026-04-09 11:33:00');
