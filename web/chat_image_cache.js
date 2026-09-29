(() => {
  if (!('caches' in window)) {
    window.mangoTalkChatImageCacheGet = async () => '';
    window.mangoTalkChatImageCacheFetch = async (
      _key, _userId, url, _mimeType, width, height,
    ) => JSON.stringify({
      source: url,
      isObjectUrl: false,
      width: width || null,
      height: height || null,
    });
    window.mangoTalkChatImageCacheRemove = async () => {};
    window.mangoTalkChatImageCacheClearUser = async () => {};
    window.mangoTalkChatImageCacheRelease = () => {};
    return;
  }

  const CACHE_PREFIX = 'mangotalk-chat-images-';
  const CACHE_NAME = `${CACHE_PREFIX}v1`;
  const INDEX_KEY = `${CACHE_NAME}:index`;
  const MAX_BYTES = 64 * 1024 * 1024;
  const MAX_ENTRIES = 100;
  const MAX_CONCURRENT = 4;
  const pending = new Map();
  const queue = [];
  let active = 0;
  let saveTimer;
  let index;

  const loadIndex = () => {
    if (index) return index;
    try {
      index = JSON.parse(localStorage.getItem(INDEX_KEY) || '{}');
    } catch (_) {
      index = {};
    }
    return index;
  };

  const scheduleSave = () => {
    clearTimeout(saveTimer);
    saveTimer = setTimeout(() => {
      try { localStorage.setItem(INDEX_KEY, JSON.stringify(loadIndex())); }
      catch (_) { /* Cache is an optional optimization. */ }
    }, 1000);
  };

  const requestFor = (key) => new Request(
    `${location.origin}${location.pathname.replace(/[^/]*$/, '')}__chat_image_cache__/${encodeURIComponent(key)}`,
  );

  const runLimited = (operation) => new Promise((resolve, reject) => {
    queue.push({ operation, resolve, reject });
    const pump = () => {
      while (active < MAX_CONCURRENT && queue.length) {
        const item = queue.shift();
        active++;
        item.operation().then(item.resolve, item.reject).finally(() => {
          active--;
          pump();
        });
      }
    };
    pump();
  });

  const toResult = async (response, meta) => {
    const blob = await response.blob();
    if (!blob.size || !blob.type.startsWith('image/')) throw new Error('invalid-image');
    const source = URL.createObjectURL(blob);
    return JSON.stringify({
      source,
      isObjectUrl: true,
      width: meta.width || null,
      height: meta.height || null,
    });
  };

  const measureBlob = async (blob) => {
    if ('createImageBitmap' in window) {
      const bitmap = await createImageBitmap(blob);
      const dimensions = { width: bitmap.width, height: bitmap.height };
      bitmap.close();
      return dimensions;
    }
    return new Promise((resolve, reject) => {
      const source = URL.createObjectURL(blob);
      const image = new Image();
      image.onload = () => {
        URL.revokeObjectURL(source);
        resolve({ width: image.naturalWidth, height: image.naturalHeight });
      };
      image.onerror = () => {
        URL.revokeObjectURL(source);
        reject(new Error('image-decode-failed'));
      };
      image.src = source;
    });
  };

  const trim = async (cache) => {
    const values = Object.entries(loadIndex());
    let maxBytes = MAX_BYTES;
    try {
      const estimate = await navigator.storage?.estimate?.();
      if (estimate?.quota) maxBytes = Math.min(maxBytes, Math.floor(estimate.quota * 0.2));
    } catch (_) { /* Use conservative defaults. */ }
    values.sort((a, b) => (a[1].lastAccess || 0) - (b[1].lastAccess || 0));
    let total = values.reduce((sum, entry) => sum + (entry[1].size || 0), 0);
    while (values.length > MAX_ENTRIES || total > maxBytes) {
      const [key, meta] = values.shift();
      await cache.delete(requestFor(key));
      total -= meta.size || 0;
      delete loadIndex()[key];
    }
    scheduleSave();
  };

  const remove = async (key) => {
    const cache = await caches.open(CACHE_NAME);
    await cache.delete(requestFor(key));
    delete loadIndex()[key];
    scheduleSave();
  };

  window.mangoTalkChatImageCacheGet = async (key, userId) => {
    try {
      const meta = loadIndex()[key];
      if (!meta || meta.userId !== userId) return '';
      const cache = await caches.open(CACHE_NAME);
      const response = await cache.match(requestFor(key));
      if (!response) {
        delete loadIndex()[key];
        scheduleSave();
        return '';
      }
      meta.lastAccess = Date.now();
      scheduleSave();
      return await toResult(response, meta);
    } catch (_) {
      return '';
    }
  };

  window.mangoTalkChatImageCacheFetch = (key, userId, url, mimeType, width, height) => {
    const operationKey = `${userId}:${key}`;
    if (pending.has(operationKey)) return pending.get(operationKey);
    const operation = runLimited(async () => {
      const response = await fetch(url, { credentials: 'omit' });
      if (!response.ok) throw new Error(`image-http-${response.status}`);
      const blob = await response.blob();
      if (!blob.size || !blob.type.startsWith('image/')) throw new Error('invalid-image');
      let measuredWidth = width || 0;
      let measuredHeight = height || 0;
      if (!measuredWidth || !measuredHeight) {
        const dimensions = await measureBlob(blob);
        measuredWidth = dimensions.width;
        measuredHeight = dimensions.height;
      }
      const cache = await caches.open(CACHE_NAME);
      const storedResponse = () => new Response(blob, {
        headers: { 'Content-Type': blob.type || mimeType },
      });
      try {
        await cache.put(requestFor(key), storedResponse());
      } catch (_) {
        await trim(cache);
        await cache.put(requestFor(key), storedResponse());
      }
      loadIndex()[key] = {
        userId,
        mimeType: blob.type || mimeType,
        size: blob.size,
        width: measuredWidth,
        height: measuredHeight,
        createdAt: Date.now(),
        lastAccess: Date.now(),
      };
      await trim(cache);
      return toResult(new Response(blob, { headers: { 'Content-Type': blob.type || mimeType } }), loadIndex()[key]);
    }).finally(() => pending.delete(operationKey));
    pending.set(operationKey, operation);
    return operation;
  };

  window.mangoTalkChatImageCacheRemove = remove;
  window.mangoTalkChatImageCacheClearUser = async (userId) => {
    const keys = Object.entries(loadIndex())
      .filter((entry) => entry[1].userId === userId)
      .map((entry) => entry[0]);
    await Promise.all(keys.map(remove));
  };
  window.mangoTalkChatImageCacheRelease = (source) => {
    if (source.startsWith('blob:')) URL.revokeObjectURL(source);
  };

  caches.keys().then((names) => Promise.all(
    names.filter((name) => name.startsWith(CACHE_PREFIX) && name !== CACHE_NAME)
      .map((name) => caches.delete(name)),
  ));
})();
