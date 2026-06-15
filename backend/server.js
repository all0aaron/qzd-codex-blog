const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const PORT = 8942;
const ROOT = path.resolve(__dirname, '..');
const FRONTEND_DIR = path.join(ROOT, 'frontend');
const STORE_PATH = path.join(__dirname, 'data', 'store.json');
const sessions = new Map();

function readStore() {
  return JSON.parse(fs.readFileSync(STORE_PATH, 'utf8'));
}

function writeStore(store) {
  fs.writeFileSync(STORE_PATH, JSON.stringify(store, null, 2), 'utf8');
}

function sendJson(res, code, msg, data = null, status = 200) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify({ code, msg, data }));
}

function notFound(res) {
  sendJson(res, 404, '资源不存在', null, 404);
}

function getBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', chunk => {
      body += chunk;
      if (body.length > 1024 * 1024) {
        reject(new Error('请求体过大'));
        req.destroy();
      }
    });
    req.on('end', () => {
      if (!body) return resolve({});
      try {
        resolve(JSON.parse(body));
      } catch {
        reject(new Error('JSON 格式错误'));
      }
    });
  });
}

function requireAuth(req, res) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  if (!token || !sessions.has(token)) {
    sendJson(res, 401, '请先登录', null, 401);
    return null;
  }
  return sessions.get(token);
}

function publicPost(store, post, includeContent = false) {
  const category = store.categories.find(item => item.id === post.categoryId);
  const tags = post.tagIds.map(id => store.tags.find(tag => tag.id === id)).filter(Boolean);
  const base = {
    id: post.id,
    title: post.title,
    slug: post.slug,
    summary: post.summary,
    coverUrl: post.coverUrl,
    categoryId: post.categoryId,
    categoryName: category ? category.name : '',
    tags,
    status: post.status,
    featured: post.featured,
    readCount: post.readCount,
    publishTime: post.publishTime,
    updateTime: post.updateTime,
  };
  if (includeContent) {
    base.content = post.content;
    base.comments = store.comments
      .filter(comment => comment.postId === post.id && comment.status === 'approved' && !comment.isDeleted)
      .sort((a, b) => new Date(a.createTime) - new Date(b.createTime));
  }
  return base;
}

function slugify(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9\u4e00-\u9fa5]+/g, '-')
    .replace(/^-+|-+$/g, '') || `post-${Date.now()}`;
}

function nextId(items) {
  return items.reduce((max, item) => Math.max(max, item.id), 0) + 1;
}

function ensureTags(store, names) {
  return names.map(name => {
    const trimmed = String(name).trim();
    let tag = store.tags.find(item => item.name === trimmed);
    if (!tag) {
      tag = { id: nextId(store.tags), name: trimmed, slug: slugify(trimmed), color: '#0f766e' };
      store.tags.push(tag);
    }
    return tag.id;
  });
}

function validatePost(payload) {
  const required = ['title', 'summary', 'content', 'slug', 'categoryId', 'status'];
  for (const key of required) {
    if (payload[key] === undefined || payload[key] === null || payload[key] === '') {
      throw new Error(`缺少字段：${key}`);
    }
  }
  if (!['draft', 'published'].includes(payload.status)) throw new Error('文章状态不合法');
}

function handlePosts(req, res, url) {
  const store = readStore();
  const keyword = (url.searchParams.get('keyword') || '').toLowerCase();
  const category = url.searchParams.get('category') || '';
  const tag = url.searchParams.get('tag') || '';
  let items = store.posts.filter(post => !post.isDeleted && post.status === 'published');
  if (keyword) {
    items = items.filter(post =>
      post.title.toLowerCase().includes(keyword) ||
      post.summary.toLowerCase().includes(keyword) ||
      post.content.toLowerCase().includes(keyword)
    );
  }
  if (category) {
    const current = store.categories.find(item => item.slug === category);
    items = current ? items.filter(post => post.categoryId === current.id) : [];
  }
  if (tag) {
    const current = store.tags.find(item => item.slug === tag);
    items = current ? items.filter(post => post.tagIds.includes(current.id)) : [];
  }
  items.sort((a, b) => new Date(b.publishTime || b.updateTime) - new Date(a.publishTime || a.updateTime));
  sendJson(res, 0, 'ok', { total: items.length, items: items.map(post => publicPost(store, post)) });
}

function handleTaxonomy(req, res) {
  const store = readStore();
  const visiblePosts = store.posts.filter(post => !post.isDeleted && post.status === 'published');
  const categories = store.categories
    .slice()
    .sort((a, b) => a.sortOrder - b.sortOrder)
    .map(category => ({
      ...category,
      postCount: visiblePosts.filter(post => post.categoryId === category.id).length,
    }));
  const tags = store.tags.map(tag => ({
    ...tag,
    postCount: visiblePosts.filter(post => post.tagIds.includes(tag.id)).length,
  })).filter(tag => tag.postCount > 0);
  sendJson(res, 0, 'ok', { categories, tags });
}

function serveStatic(req, res, url) {
  let pathname = decodeURIComponent(url.pathname);
  if (pathname === '/') pathname = '/index.html';
  if (pathname === '/admin') pathname = '/admin.html';
  const filePath = path.resolve(FRONTEND_DIR, `.${pathname}`);
  if (!filePath.startsWith(FRONTEND_DIR)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }
  fs.readFile(filePath, (error, data) => {
    if (error) {
      res.writeHead(404);
      res.end('Not Found');
      return;
    }
    const ext = path.extname(filePath);
    const type = {
      '.html': 'text/html; charset=utf-8',
      '.css': 'text/css; charset=utf-8',
      '.js': 'application/javascript; charset=utf-8',
      '.png': 'image/png',
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.svg': 'image/svg+xml',
    }[ext] || 'application/octet-stream';
    res.writeHead(200, { 'Content-Type': type });
    res.end(data);
  });
}

async function handleApi(req, res, url) {
  const method = req.method;
  const pathname = url.pathname;

  if (method === 'GET' && pathname === '/api/settings') return sendJson(res, 0, 'ok', readStore().settings);
  if (method === 'GET' && pathname === '/api/taxonomy') return handleTaxonomy(req, res);
  if (method === 'GET' && pathname === '/api/posts') return handlePosts(req, res, url);

  const postMatch = pathname.match(/^\/api\/posts\/([^/]+)$/);
  if (method === 'GET' && postMatch) {
    const store = readStore();
    const slug = decodeURIComponent(postMatch[1]);
    const post = store.posts.find(item => item.slug === slug && item.status === 'published' && !item.isDeleted);
    if (!post) return notFound(res);
    post.readCount += 1;
    post.updateTime = new Date().toISOString();
    writeStore(store);
    return sendJson(res, 0, 'ok', publicPost(store, post, true));
  }

  if (method === 'POST' && pathname === '/api/comments') {
    const payload = await getBody(req);
    if (!payload.postId || !payload.nickname || !payload.email || !payload.content) {
      return sendJson(res, 400, '昵称、邮箱和评论内容不能为空', null, 400);
    }
    const store = readStore();
    const post = store.posts.find(item => item.id === Number(payload.postId) && item.status === 'published' && !item.isDeleted);
    if (!post) return sendJson(res, 404, '文章不存在', null, 404);
    const now = new Date().toISOString();
    const comment = {
      id: nextId(store.comments),
      postId: post.id,
      nickname: String(payload.nickname).slice(0, 40),
      email: String(payload.email).slice(0, 120),
      content: String(payload.content).slice(0, 1000),
      status: 'pending',
      replyContent: '',
      createTime: now,
      updateTime: now,
      isDeleted: false,
    };
    store.comments.push(comment);
    writeStore(store);
    return sendJson(res, 0, '评论已提交，等待审核', comment);
  }

  if (method === 'POST' && pathname === '/api/auth/login') {
    const payload = await getBody(req);
    const store = readStore();
    const user = store.admins.find(item => item.username === payload.username && item.password === payload.password && item.status === 'enabled');
    if (!user) return sendJson(res, 401, '账号或密码错误', null, 401);
    const token = crypto.randomBytes(24).toString('hex');
    sessions.set(token, { id: user.id, username: user.username, role: user.role });
    return sendJson(res, 0, '登录成功', { token, user: { id: user.id, username: user.username, role: user.role } });
  }

  if (pathname.startsWith('/api/admin')) {
    if (!requireAuth(req, res)) return;
    return handleAdmin(req, res, url);
  }

  return notFound(res);
}

async function handleAdmin(req, res, url) {
  const method = req.method;
  const pathname = url.pathname;

  if (method === 'GET' && pathname === '/api/admin/stats') {
    const store = readStore();
    const posts = store.posts.filter(post => !post.isDeleted);
    const pending = store.comments.filter(comment => comment.status === 'pending' && !comment.isDeleted);
    return sendJson(res, 0, 'ok', {
      postCount: posts.length,
      readCount: posts.reduce((sum, post) => sum + Number(post.readCount || 0), 0),
      pendingComments: pending.length,
      draftCount: posts.filter(post => post.status === 'draft').length,
      recentPosts: posts.slice().sort((a, b) => new Date(b.updateTime) - new Date(a.updateTime)).slice(0, 5).map(post => publicPost(store, post)),
      pendingList: pending.slice(0, 5).map(comment => ({
        ...comment,
        postTitle: (store.posts.find(post => post.id === comment.postId) || {}).title || '',
      })),
    });
  }

  if (method === 'GET' && pathname === '/api/admin/posts') {
    const store = readStore();
    const keyword = (url.searchParams.get('keyword') || '').toLowerCase();
    const status = url.searchParams.get('status') || '';
    let items = store.posts.filter(post => !post.isDeleted);
    if (keyword) items = items.filter(post => post.title.toLowerCase().includes(keyword) || post.summary.toLowerCase().includes(keyword));
    if (status) items = items.filter(post => post.status === status);
    items.sort((a, b) => new Date(b.updateTime) - new Date(a.updateTime));
    return sendJson(res, 0, 'ok', { total: items.length, items: items.map(post => publicPost(store, post)) });
  }

  const adminPostMatch = pathname.match(/^\/api\/admin\/posts\/(\d+)$/);
  if (method === 'GET' && adminPostMatch) {
    const store = readStore();
    const post = store.posts.find(item => item.id === Number(adminPostMatch[1]) && !item.isDeleted);
    if (!post) return notFound(res);
    return sendJson(res, 0, 'ok', publicPost(store, post, true));
  }

  if ((method === 'POST' && pathname === '/api/admin/posts') || (method === 'PUT' && adminPostMatch)) {
    const payload = await getBody(req);
    validatePost(payload);
    const store = readStore();
    const now = new Date().toISOString();
    const tagIds = ensureTags(store, payload.tags || []);
    if (method === 'POST') {
      const post = {
        id: nextId(store.posts),
        title: payload.title,
        slug: slugify(payload.slug),
        summary: payload.summary,
        content: payload.content,
        coverUrl: payload.coverUrl || '',
        categoryId: Number(payload.categoryId),
        tagIds,
        status: payload.status,
        featured: Boolean(payload.featured),
        readCount: 0,
        publishTime: payload.status === 'published' ? now : null,
        createTime: now,
        updateTime: now,
        isDeleted: false,
      };
      store.posts.push(post);
      writeStore(store);
      return sendJson(res, 0, '文章已创建', publicPost(store, post, true));
    }
    const post = store.posts.find(item => item.id === Number(adminPostMatch[1]) && !item.isDeleted);
    if (!post) return notFound(res);
    Object.assign(post, {
      title: payload.title,
      slug: slugify(payload.slug),
      summary: payload.summary,
      content: payload.content,
      coverUrl: payload.coverUrl || '',
      categoryId: Number(payload.categoryId),
      tagIds,
      status: payload.status,
      featured: Boolean(payload.featured),
      publishTime: post.publishTime || (payload.status === 'published' ? now : null),
      updateTime: now,
    });
    writeStore(store);
    return sendJson(res, 0, '文章已更新', publicPost(store, post, true));
  }

  if (method === 'DELETE' && adminPostMatch) {
    const store = readStore();
    const post = store.posts.find(item => item.id === Number(adminPostMatch[1]) && !item.isDeleted);
    if (!post) return notFound(res);
    post.isDeleted = true;
    post.updateTime = new Date().toISOString();
    writeStore(store);
    return sendJson(res, 0, '文章已删除');
  }

  if (method === 'GET' && pathname === '/api/admin/comments') {
    const store = readStore();
    const items = store.comments
      .filter(comment => !comment.isDeleted)
      .sort((a, b) => new Date(b.createTime) - new Date(a.createTime))
      .map(comment => ({
        ...comment,
        postTitle: (store.posts.find(post => post.id === comment.postId) || {}).title || '',
      }));
    return sendJson(res, 0, 'ok', { total: items.length, items });
  }

  const commentStatusMatch = pathname.match(/^\/api\/admin\/comments\/(\d+)\/status$/);
  if (method === 'PUT' && commentStatusMatch) {
    const payload = await getBody(req);
    if (!['pending', 'approved', 'hidden'].includes(payload.status)) return sendJson(res, 400, '评论状态不合法', null, 400);
    const store = readStore();
    const comment = store.comments.find(item => item.id === Number(commentStatusMatch[1]) && !item.isDeleted);
    if (!comment) return notFound(res);
    comment.status = payload.status;
    comment.updateTime = new Date().toISOString();
    writeStore(store);
    return sendJson(res, 0, '评论状态已更新', comment);
  }

  const commentDeleteMatch = pathname.match(/^\/api\/admin\/comments\/(\d+)$/);
  if (method === 'DELETE' && commentDeleteMatch) {
    const store = readStore();
    const comment = store.comments.find(item => item.id === Number(commentDeleteMatch[1]) && !item.isDeleted);
    if (!comment) return notFound(res);
    comment.isDeleted = true;
    comment.updateTime = new Date().toISOString();
    writeStore(store);
    return sendJson(res, 0, '评论已删除');
  }

  if (method === 'PUT' && pathname === '/api/admin/settings') {
    const payload = await getBody(req);
    const store = readStore();
    store.settings = { ...store.settings, ...payload };
    writeStore(store);
    return sendJson(res, 0, '设置已保存', store.settings);
  }

  return notFound(res);
}

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
    if (url.pathname.startsWith('/api/')) {
      await handleApi(req, res, url);
    } else {
      serveStatic(req, res, url);
    }
  } catch (error) {
    sendJson(res, 500, error.message || '服务器错误', null, 500);
  }
});

server.listen(PORT, () => {
  console.log(`Blog system running at http://localhost:${PORT}`);
});
