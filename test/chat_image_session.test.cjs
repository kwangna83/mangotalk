const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const vm = require('node:vm');

function harness() {
  const entries = new Map();
  const revoked = [];
  let created = 0;
  let fetched = 0;
  const cache = {
    async put(request, response) { entries.set(request.url, response); },
    async match(request) { return entries.get(request.url)?.clone(); },
    async delete(request) { return entries.delete(request.url); },
  };
  const context = {
    Request, Response, Blob,
    location: { origin: 'https://example.test', pathname: '/mangotalk/' },
    localStorage: { getItem: () => null, setItem() {} },
    navigator: {},
    setTimeout: () => 0, clearTimeout() {},
    caches: { open: async () => cache, keys: async () => [] },
    URL: {
      createObjectURL() { return `blob:test-${++created}`; },
      revokeObjectURL(source) { revoked.push(source); },
    },
    fetch: async () => {
      fetched++;
      return new Response(new Blob(['image'], { type: 'image/png' }));
    },
  };
  context.window = context;
  vm.runInNewContext(readFileSync('web/chat_image_cache.js', 'utf8'), context);
  return {
    api: context, revoked,
    counts: () => ({ created, fetched }),
    download: async (key, user = 'alice') => JSON.parse(
      await context.mangoTalkChatImageCacheFetch(key, user, 'https://example.test/image', 'image/png', 100, 100),
    ),
  };
}

test('scroll-out and synchronous reentry reuse the URL without downloading', async () => {
  const h = harness();
  const image = await h.download('a');
  h.api.mangoTalkChatImageCacheRelease(image.source);
  const again = JSON.parse(h.api.mangoTalkChatImageCachePeek('a', 'alice'));
  assert.equal(again.source, image.source);
  assert.deepEqual(h.counts(), { created: 1, fetched: 1 });
  assert.deepEqual(h.revoked, []);
});

test('LRU evicts unused URLs but preserves active consumers', async () => {
  const h = harness();
  const active = await h.download('active');
  h.api.mangoTalkChatImageCacheRetain(active.source);
  h.api.mangoTalkChatImageCacheRelease(active.source);
  const oldest = await h.download('oldest');
  h.api.mangoTalkChatImageCacheRelease(oldest.source);
  for (let i = 0; i < 49; i++) {
    const image = await h.download(`image-${i}`);
    h.api.mangoTalkChatImageCacheRelease(image.source);
  }
  assert.deepEqual(h.revoked, [oldest.source]);
  assert.equal(h.api.mangoTalkChatImageCachePeek('oldest', 'alice'), '');
  assert.equal(JSON.parse(h.api.mangoTalkChatImageCachePeek('active', 'alice')).source, active.source);
  const restored = JSON.parse(await h.api.mangoTalkChatImageCacheGet('oldest', 'alice'));
  assert.notEqual(restored.source, oldest.source);
  assert.equal(h.counts().fetched, 51);
});

test('logout revokes the owner URLs and cannot return another user image', async () => {
  const h = harness();
  const alice = await h.download('a');
  const bob = await h.download('b', 'bob');
  assert.equal(h.api.mangoTalkChatImageCachePeek('a', 'bob'), '');
  await h.api.mangoTalkChatImageCacheClearUser('alice');
  assert.equal(h.api.mangoTalkChatImageCachePeek('a', 'alice'), '');
  assert.equal(await h.api.mangoTalkChatImageCacheGet('a', 'alice'), '');
  assert.deepEqual(h.revoked, [alice.source]);
  assert.equal(JSON.parse(h.api.mangoTalkChatImageCachePeek('b', 'bob')).source, bob.source);
});
