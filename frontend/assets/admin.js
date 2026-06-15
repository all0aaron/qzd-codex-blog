let token = localStorage.getItem('blog_admin_token') || '';
let categories = [];
let currentView = 'dashboard';

const viewMap = {
  dashboard: ['dashboardView', '仪表盘', '站点内容运行概览'],
  posts: ['postsView', '文章管理', '管理文章草稿、发布和删除'],
  editor: ['editorView', '文章编辑', '编辑文章正文和发布配置'],
  comments: ['commentsView', '评论管理', '审核、隐藏和删除评论'],
  settings: ['settingsView', '站点设置', '维护前台展示信息和 SEO'],
};

const api = async (url, options = {}) => {
  const response = await fetch(url, {
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(options.headers || {}),
    },
    ...options,
  });
  const body = await response.json();
  if (!response.ok || body.code !== 0) throw new Error(body.msg || '请求失败');
  return body.data;
};

const escapeHtml = value => String(value ?? '').replace(/[&<>"']/g, char => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
}[char]));

const statusText = value => ({ published: '已发布', draft: '草稿', pending: '待审核', approved: '已通过', hidden: '已隐藏' }[value] || value);

function setMessage(id, text, error = false) {
  const el = document.getElementById(id);
  el.textContent = text;
  el.classList.toggle('error', error);
}

function showWorkspace() {
  document.getElementById('loginView').classList.add('hidden');
  document.getElementById('workspace').classList.remove('hidden');
  showView(currentView);
}

function showLogin() {
  document.getElementById('loginView').classList.remove('hidden');
  document.getElementById('workspace').classList.add('hidden');
}

function showView(view) {
  currentView = view;
  Object.values(viewMap).forEach(([id]) => document.getElementById(id).classList.add('hidden'));
  const [id, title, subtitle] = viewMap[view];
  document.getElementById(id).classList.remove('hidden');
  document.getElementById('adminTitle').textContent = title;
  document.getElementById('adminSubtitle').textContent = subtitle;
  document.querySelectorAll('.admin-nav').forEach(button => {
    button.classList.toggle('active', button.dataset.view === view);
  });
  if (view === 'dashboard') loadDashboard();
  if (view === 'posts') loadPosts();
  if (view === 'comments') loadComments();
  if (view === 'settings') loadSettings();
}

async function bootstrap() {
  if (!token) {
    showLogin();
    return;
  }
  try {
    await loadTaxonomy();
    showWorkspace();
  } catch {
    localStorage.removeItem('blog_admin_token');
    token = '';
    showLogin();
  }
}

async function loadTaxonomy() {
  const data = await api('/api/taxonomy');
  categories = data.categories;
  document.getElementById('postCategory').innerHTML = categories.map(category => `<option value="${category.id}">${escapeHtml(category.name)}</option>`).join('');
}

async function loadDashboard() {
  const data = await api('/api/admin/stats');
  document.getElementById('statsGrid').innerHTML = `
    <div class="stat-card"><span>文章总数</span><b>${data.postCount}</b></div>
    <div class="stat-card"><span>总阅读量</span><b>${data.readCount}</b></div>
    <div class="stat-card"><span>待审核评论</span><b>${data.pendingComments}</b></div>
    <div class="stat-card"><span>草稿</span><b>${data.draftCount}</b></div>
  `;
  document.getElementById('recentPosts').innerHTML = data.recentPosts.map(post => `
    <div class="comment-item">
      <b>${escapeHtml(post.title)}</b>
      <span>${statusText(post.status)} / ${post.readCount} 次阅读</span>
    </div>
  `).join('');
  document.getElementById('pendingComments').innerHTML = data.pendingList.length ? data.pendingList.map(comment => `
    <div class="comment-item">
      <b>${escapeHtml(comment.nickname)}</b>
      <span>${escapeHtml(comment.postTitle)}</span>
      <p>${escapeHtml(comment.content)}</p>
    </div>
  `).join('') : '<p>暂无待审核评论。</p>';
}

async function loadPosts() {
  const params = new URLSearchParams();
  const keyword = document.getElementById('adminPostKeyword').value.trim();
  const status = document.getElementById('adminPostStatus').value;
  if (keyword) params.set('keyword', keyword);
  if (status) params.set('status', status);
  const data = await api(`/api/admin/posts?${params.toString()}`);
  document.getElementById('adminPostTable').innerHTML = data.items.map(post => `
    <tr>
      <td><b>${escapeHtml(post.title)}</b><br><span class="post-meta">${escapeHtml(post.slug)}</span></td>
      <td>${escapeHtml(post.categoryName)}</td>
      <td><span class="status-pill status-${post.status}">${statusText(post.status)}</span></td>
      <td>${post.readCount}</td>
      <td>${escapeHtml(post.updateTime.replace('T', ' ').slice(0, 16))}</td>
      <td>
        <div class="table-actions">
          <button data-edit="${post.id}">编辑</button>
          <button data-delete="${post.id}">删除</button>
        </div>
      </td>
    </tr>
  `).join('');
  document.querySelectorAll('[data-edit]').forEach(button => button.addEventListener('click', () => editPost(Number(button.dataset.edit))));
  document.querySelectorAll('[data-delete]').forEach(button => button.addEventListener('click', () => deletePost(Number(button.dataset.delete))));
}

async function editPost(id) {
  const post = await api(`/api/admin/posts/${id}`);
  document.getElementById('postId').value = post.id;
  document.getElementById('postTitle').value = post.title;
  document.getElementById('postSummary').value = post.summary;
  document.getElementById('postContent').value = post.content;
  document.getElementById('postSlug').value = post.slug;
  document.getElementById('postCategory').value = post.categoryId;
  document.getElementById('postTags').value = post.tags.map(tag => tag.name).join(', ');
  document.getElementById('postCover').value = post.coverUrl;
  document.getElementById('postStatus').value = post.status;
  document.getElementById('postFeatured').checked = post.featured;
  setMessage('postMessage', '');
  showView('editor');
}

function newPost() {
  document.getElementById('postForm').reset();
  document.getElementById('postId').value = '';
  document.getElementById('postStatus').value = 'draft';
  setMessage('postMessage', '');
  showView('editor');
}

async function savePost(event) {
  event.preventDefault();
  const id = document.getElementById('postId').value;
  const payload = {
    title: document.getElementById('postTitle').value.trim(),
    summary: document.getElementById('postSummary').value.trim(),
    content: document.getElementById('postContent').value.trim(),
    slug: document.getElementById('postSlug').value.trim(),
    categoryId: Number(document.getElementById('postCategory').value),
    tags: document.getElementById('postTags').value.split(',').map(item => item.trim()).filter(Boolean),
    coverUrl: document.getElementById('postCover').value.trim(),
    status: document.getElementById('postStatus').value,
    featured: document.getElementById('postFeatured').checked,
  };
  try {
    await api(id ? `/api/admin/posts/${id}` : '/api/admin/posts', {
      method: id ? 'PUT' : 'POST',
      body: JSON.stringify(payload),
    });
    setMessage('postMessage', '文章已保存。');
    await loadTaxonomy();
    showView('posts');
  } catch (error) {
    setMessage('postMessage', error.message, true);
  }
}

async function deletePost(id) {
  if (!confirm('确认删除这篇文章？')) return;
  await api(`/api/admin/posts/${id}`, { method: 'DELETE' });
  loadPosts();
}

async function loadComments() {
  const data = await api('/api/admin/comments');
  document.getElementById('commentList').innerHTML = data.items.map(comment => `
    <article class="admin-comment">
      <div>
        <h3>${escapeHtml(comment.nickname)} <span class="status-pill status-${comment.status}">${statusText(comment.status)}</span></h3>
        <span class="post-meta">${escapeHtml(comment.email)} / ${escapeHtml(comment.postTitle)}</span>
        <p>${escapeHtml(comment.content)}</p>
      </div>
      <div class="table-actions">
        <button data-comment-status="${comment.id}:approved">通过</button>
        <button data-comment-status="${comment.id}:hidden">隐藏</button>
        <button data-comment-delete="${comment.id}">删除</button>
      </div>
    </article>
  `).join('');
  document.querySelectorAll('[data-comment-status]').forEach(button => {
    button.addEventListener('click', async () => {
      const [id, status] = button.dataset.commentStatus.split(':');
      await api(`/api/admin/comments/${id}/status`, { method: 'PUT', body: JSON.stringify({ status }) });
      loadComments();
    });
  });
  document.querySelectorAll('[data-comment-delete]').forEach(button => {
    button.addEventListener('click', async () => {
      if (!confirm('确认删除这条评论？')) return;
      await api(`/api/admin/comments/${button.dataset.commentDelete}`, { method: 'DELETE' });
      loadComments();
    });
  });
}

async function loadSettings() {
  const settings = await api('/api/settings');
  document.getElementById('settingSiteName').value = settings.siteName;
  document.getElementById('settingSiteTitle').value = settings.siteTitle;
  document.getElementById('settingSiteDescription').value = settings.siteDescription;
  document.getElementById('settingKeywords').value = settings.keywords || '';
  document.getElementById('settingAuthorName').value = settings.authorName;
  document.getElementById('settingAuthorBio').value = settings.authorBio;
  document.getElementById('settingAuthorAvatar').value = settings.authorAvatar || '';
  setMessage('settingsMessage', '');
}

async function saveSettings(event) {
  event.preventDefault();
  try {
    await api('/api/admin/settings', {
      method: 'PUT',
      body: JSON.stringify({
        siteName: document.getElementById('settingSiteName').value.trim(),
        siteTitle: document.getElementById('settingSiteTitle').value.trim(),
        siteDescription: document.getElementById('settingSiteDescription').value.trim(),
        keywords: document.getElementById('settingKeywords').value.trim(),
        authorName: document.getElementById('settingAuthorName').value.trim(),
        authorBio: document.getElementById('settingAuthorBio').value.trim(),
        authorAvatar: document.getElementById('settingAuthorAvatar').value.trim(),
      }),
    });
    setMessage('settingsMessage', '设置已保存。');
  } catch (error) {
    setMessage('settingsMessage', error.message, true);
  }
}

document.getElementById('loginForm').addEventListener('submit', async event => {
  event.preventDefault();
  try {
    const data = await api('/api/auth/login', {
      method: 'POST',
      body: JSON.stringify({
        username: document.getElementById('loginUsername').value.trim(),
        password: document.getElementById('loginPassword').value,
      }),
    });
    token = data.token;
    localStorage.setItem('blog_admin_token', token);
    await loadTaxonomy();
    showWorkspace();
  } catch (error) {
    setMessage('loginMessage', error.message, true);
  }
});

document.getElementById('logoutBtn').addEventListener('click', () => {
  localStorage.removeItem('blog_admin_token');
  token = '';
  showLogin();
});
document.querySelectorAll('.admin-nav').forEach(button => button.addEventListener('click', () => showView(button.dataset.view)));
document.getElementById('newPostBtn').addEventListener('click', newPost);
document.getElementById('adminPostSearch').addEventListener('click', loadPosts);
document.getElementById('postForm').addEventListener('submit', savePost);
document.getElementById('cancelEdit').addEventListener('click', () => showView('posts'));
document.getElementById('settingsForm').addEventListener('submit', saveSettings);

bootstrap();
