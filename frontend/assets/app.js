const state = {
  posts: [],
  categories: [],
  tags: [],
  settings: null,
  keyword: '',
  category: '',
  tag: '',
};

const api = async (url, options = {}) => {
  const response = await fetch(url, {
    headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
    ...options,
  });
  const body = await response.json();
  if (!response.ok || body.code !== 0) throw new Error(body.msg || '请求失败');
  return body.data;
};

const escapeHtml = value => String(value ?? '').replace(/[&<>"']/g, char => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
}[char]));

const formatDate = value => new Date(value).toLocaleDateString('zh-CN', {
  year: 'numeric', month: '2-digit', day: '2-digit',
});

async function loadSettings() {
  state.settings = await api('/api/settings');
  document.title = state.settings.siteTitle;
  document.getElementById('siteTitle').textContent = state.settings.siteTitle;
  document.getElementById('siteDescription').textContent = state.settings.siteDescription;
  document.getElementById('authorName').textContent = state.settings.authorName;
  document.getElementById('authorBio').textContent = state.settings.authorBio;
  if (state.settings.authorAvatar) document.getElementById('authorAvatar').src = state.settings.authorAvatar;
}

async function loadTaxonomy() {
  const data = await api('/api/taxonomy');
  state.categories = data.categories;
  state.tags = data.tags;
  renderTaxonomy();
}

async function loadPosts() {
  const params = new URLSearchParams();
  if (state.keyword) params.set('keyword', state.keyword);
  if (state.category) params.set('category', state.category);
  if (state.tag) params.set('tag', state.tag);
  const data = await api(`/api/posts?${params.toString()}`);
  state.posts = data.items;
  renderPosts(data.total);
}

function renderTaxonomy() {
  document.getElementById('categoryList').innerHTML = state.categories.map(category => `
    <div class="category-row">
      <button data-category="${escapeHtml(category.slug)}">${escapeHtml(category.name)}</button>
      <b>${category.postCount}</b>
    </div>
  `).join('');
  document.getElementById('tagList').innerHTML = state.tags.map(tag => `
    <button class="tag" data-tag="${escapeHtml(tag.slug)}">${escapeHtml(tag.name)}</button>
  `).join('');
  document.querySelectorAll('[data-category]').forEach(button => {
    button.addEventListener('click', () => {
      state.category = button.dataset.category;
      state.tag = '';
      loadPosts();
    });
  });
  document.querySelectorAll('[data-tag]').forEach(button => {
    button.addEventListener('click', () => {
      state.tag = button.dataset.tag;
      state.category = '';
      loadPosts();
    });
  });
}

function renderPosts(total) {
  document.getElementById('postDetail').classList.add('hidden');
  document.getElementById('postList').classList.remove('hidden');
  const active = state.keyword || state.category || state.tag;
  document.getElementById('listTitle').textContent = active ? '筛选结果' : '最新文章';
  document.getElementById('listSummary').textContent = `共 ${total} 篇文章`;
  if (!state.posts.length) {
    document.getElementById('postList').innerHTML = '<section class="panel"><p>没有找到匹配的文章。</p></section>';
    return;
  }
  document.getElementById('postList').innerHTML = state.posts.map(post => `
    <article class="post-card">
      <img src="${escapeHtml(post.coverUrl)}" alt="${escapeHtml(post.title)}">
      <div>
        <div class="post-meta">
          <span>${formatDate(post.publishTime)}</span>
          <span>${escapeHtml(post.categoryName)}</span>
          <span>${post.readCount} 次阅读</span>
        </div>
        <h3><a href="#post-${escapeHtml(post.slug)}" data-slug="${escapeHtml(post.slug)}">${escapeHtml(post.title)}</a></h3>
        <p>${escapeHtml(post.summary)}</p>
        <div>${post.tags.map(tag => `<button class="tag" data-tag="${escapeHtml(tag.slug)}">${escapeHtml(tag.name)}</button>`).join('')}</div>
      </div>
    </article>
  `).join('');
  document.querySelectorAll('[data-slug]').forEach(link => {
    link.addEventListener('click', event => {
      event.preventDefault();
      showPost(link.dataset.slug);
    });
  });
  document.querySelectorAll('#postList [data-tag]').forEach(button => {
    button.addEventListener('click', () => {
      state.tag = button.dataset.tag;
      state.category = '';
      loadPosts();
    });
  });
}

async function showPost(slug) {
  const post = await api(`/api/posts/${encodeURIComponent(slug)}`);
  document.getElementById('postList').classList.add('hidden');
  const detail = document.getElementById('postDetail');
  detail.classList.remove('hidden');
  detail.innerHTML = `
    <div class="detail-cover" style="background-image:url('${escapeHtml(post.coverUrl)}')"></div>
    <div class="detail-body">
      <button class="outline-btn" id="backToList">返回列表</button>
      <div class="post-meta" style="margin-top:18px;">
        <span>${formatDate(post.publishTime)}</span>
        <span>${escapeHtml(post.categoryName)}</span>
        <span>${post.readCount} 次阅读</span>
      </div>
      <h1>${escapeHtml(post.title)}</h1>
      <p>${escapeHtml(post.summary)}</p>
      <div>${post.tags.map(tag => `<span class="tag">${escapeHtml(tag.name)}</span>`).join('')}</div>
      <div class="article-content">${escapeHtml(post.content)}</div>
      <section class="comment-form">
        <h3>评论</h3>
        <div id="detailComments">
          ${post.comments.length ? post.comments.map(renderComment).join('') : '<p>还没有评论，欢迎留下第一条讨论。</p>'}
        </div>
        <form id="commentForm">
          <div class="form-grid">
            <input id="commentNickname" placeholder="昵称" required>
            <input id="commentEmail" placeholder="邮箱" type="email" required>
          </div>
          <textarea id="commentContent" rows="4" placeholder="写下你的评论，审核通过后展示" required></textarea>
          <button class="primary-btn" type="submit">提交评论</button>
          <div class="form-message" id="commentMessage"></div>
        </form>
      </section>
    </div>
  `;
  document.getElementById('backToList').addEventListener('click', () => {
    detail.classList.add('hidden');
    document.getElementById('postList').classList.remove('hidden');
  });
  document.getElementById('commentForm').addEventListener('submit', async event => {
    event.preventDefault();
    const message = document.getElementById('commentMessage');
    try {
      await api('/api/comments', {
        method: 'POST',
        body: JSON.stringify({
          postId: post.id,
          nickname: document.getElementById('commentNickname').value.trim(),
          email: document.getElementById('commentEmail').value.trim(),
          content: document.getElementById('commentContent').value.trim(),
        }),
      });
      event.target.reset();
      message.textContent = '评论已提交，审核通过后会展示。';
    } catch (error) {
      message.textContent = error.message;
      message.classList.add('error');
    }
  });
  detail.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

function renderComment(comment) {
  return `
    <div class="comment-item">
      <b>${escapeHtml(comment.nickname)}</b>
      <span>${formatDate(comment.createTime)}</span>
      <p>${escapeHtml(comment.content)}</p>
      ${comment.replyContent ? `<p><b>作者回复：</b>${escapeHtml(comment.replyContent)}</p>` : ''}
    </div>
  `;
}

document.getElementById('searchForm').addEventListener('submit', event => {
  event.preventDefault();
  state.keyword = document.getElementById('keywordInput').value.trim();
  state.category = '';
  state.tag = '';
  loadPosts();
});

document.getElementById('clearFilter').addEventListener('click', () => {
  state.keyword = '';
  state.category = '';
  state.tag = '';
  document.getElementById('keywordInput').value = '';
  loadPosts();
});

Promise.all([loadSettings(), loadTaxonomy()]).then(loadPosts).catch(error => {
  document.getElementById('postList').innerHTML = `<section class="panel"><p>${escapeHtml(error.message)}</p></section>`;
});
