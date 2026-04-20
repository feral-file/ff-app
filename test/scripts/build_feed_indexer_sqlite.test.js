const assert = require('node:assert/strict');
const fs = require('node:fs');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const {execFileSync, spawn} = require('node:child_process');

const {
  extractChannelsFromChannelRegistry,
  extractChannelsFromPublishArtifact,
} = require('../../scripts/build_feed_indexer_sqlite.js');

const ROOT = path.resolve(__dirname, '..', '..');
const SCRIPT_PATH = path.join(ROOT, 'scripts', 'build_feed_indexer_sqlite.js');
const OUTPUT_DB_PATH = path.join(ROOT, 'scripts', 'ff_feed_indexer_seed.sqlite');

test('extractChannelsFromPublishArtifact preserves source attribution by origin', () => {
  const channels = extractChannelsFromPublishArtifact({
    exhibitions: [
      {
        status: 'success',
        channel: {url: 'https://source-a.example/api/v1/channels/channel-a'},
      },
      {
        status: 'success',
        channel: {url: 'https://source-b.example/api/v1/channels/channel-b'},
      },
    ],
  });

  assert.equal(channels.length, 2);
  assert.deepEqual(
    channels.map((channel) => ({
      id: channel.id,
      publisherId: channel.publisherId,
      publisherTitle: channel.publisherTitle,
    })),
    [
      {
        id: 'channel-a',
        publisherId: 1,
        publisherTitle: 'source-a.example',
      },
      {
        id: 'channel-b',
        publisherId: 2,
        publisherTitle: 'source-b.example',
      },
    ],
  );
});

test('extractChannelsFromPublishArtifact keeps same-title sources distinct when origins differ', () => {
  const channels = extractChannelsFromPublishArtifact({
    exhibitions: [
      {
        status: 'success',
        publisher: {name: 'Shared Publisher'},
        channel: {url: 'https://source-a.example/api/v1/channels/channel-a'},
      },
      {
        status: 'success',
        publisher: {name: 'Shared Publisher'},
        channel: {url: 'https://source-b.example/api/v1/channels/channel-b'},
      },
    ],
  });

  assert.equal(channels.length, 2);
  assert.deepEqual(
    channels.map((channel) => channel.publisherId),
    [1, 2],
  );
  assert.deepEqual(
    channels.map((channel) => channel.publisherTitle),
    ['Shared Publisher', 'Shared Publisher'],
  );
});

test('extractChannelsFromPublishArtifact keeps same explicit publisher ids distinct when origins differ', () => {
  const channels = extractChannelsFromPublishArtifact({
    exhibitions: [
      {
        status: 'success',
        publisher: {id: 1, name: 'Shared Publisher'},
        channel: {url: 'https://source-a.example/api/v1/channels/channel-a'},
      },
      {
        status: 'success',
        publisher: {id: 1, name: 'Shared Publisher'},
        channel: {url: 'https://source-b.example/api/v1/channels/channel-b'},
      },
    ],
  });

  assert.equal(channels.length, 2);
  assert.deepEqual(
    channels.map((channel) => channel.publisherId),
    [1, 2],
  );
  assert.deepEqual(
    channels.map((channel) => channel.publisherTitle),
    ['Shared Publisher', 'Shared Publisher'],
  );
});

test('extractChannelsFromChannelRegistry maps static vs living to channelKind', () => {
  const channels = extractChannelsFromChannelRegistry({
    publishers: [
      {
        name: 'Demo',
        static: ['https://feed.example/api/v1/channels/ch-s'],
        living: ['https://feed.example/api/v1/channels/ch-l'],
      },
    ],
  });
  const byId = new Map(channels.map((c) => [c.id, c]));
  assert.equal(byId.get('ch-s').channelKind, 'static');
  assert.equal(byId.get('ch-l').channelKind, 'living');
});

test('extractChannelsFromChannelRegistry keeps publisher linkage stable across input reorder', () => {
  const registryA = {
    publishers: [
      {
        id: 7,
        name: 'Publisher B',
        static: ['https://source-b.example/api/v1/channels/channel-b'],
        living: [],
      },
      {
        id: 3,
        name: 'Publisher A',
        static: ['https://source-a.example/api/v1/channels/channel-a'],
        living: [],
      },
    ],
  };
  const registryB = {
    publishers: [...registryA.publishers].reverse(),
  };

  const channelsA = extractChannelsFromChannelRegistry(registryA);
  const channelsB = extractChannelsFromChannelRegistry(registryB);

  assert.deepEqual(
    summarizeChannelPublisherLinks(channelsA),
    summarizeChannelPublisherLinks(channelsB),
  );
  assert.deepEqual(
    summarizeChannelPublisherLinks(channelsA),
    [
      {id: 'channel-a', publisherId: 1, publisherTitle: 'Publisher A'},
      {id: 'channel-b', publisherId: 2, publisherTitle: 'Publisher B'},
    ],
  );
});

test('extractChannelsFromChannelRegistry keeps one explicit publisher across multiple origins', () => {
  const channels = extractChannelsFromChannelRegistry({
    publishers: [
      {
        id: 7,
        name: 'Publisher A',
        static: [
          'https://source-a.example/api/v1/channels/channel-a',
          'https://source-b.example/api/v1/channels/channel-b',
        ],
        living: [],
      },
    ],
  });

  assert.deepEqual(
    summarizeChannelPublisherLinks(channels),
    [
      {id: 'channel-a', publisherId: 1, publisherTitle: 'Publisher A'},
      {id: 'channel-b', publisherId: 1, publisherTitle: 'Publisher A'},
    ],
  );
});

test('extractChannelsFromChannelRegistry synthesizes a title for explicit publisher ids without a name', () => {
  const channels = extractChannelsFromChannelRegistry({
    publishers: [
      {
        id: 7,
        static: ['https://source-a.example/api/v1/channels/channel-a'],
        living: [],
      },
    ],
  });

  assert.deepEqual(
    summarizeChannelPublisherLinks(channels),
    [
      {id: 'channel-a', publisherId: 1, publisherTitle: 'Publisher 7'},
    ],
  );
});

test('extractChannelsFromChannelRegistry keeps duplicate-name publishers distinct when no explicit id exists', () => {
  const channels = extractChannelsFromChannelRegistry({
    publishers: [
      {
        name: 'Shared Publisher',
        static: ['https://source-a.example/api/v1/channels/channel-a'],
        living: [],
      },
      {
        name: 'Shared Publisher',
        static: ['https://source-b.example/api/v1/channels/channel-b'],
        living: [],
      },
    ],
  });

  assert.deepEqual(
    summarizeChannelPublisherLinks(channels),
    [
      {id: 'channel-a', publisherId: 1, publisherTitle: 'Shared Publisher'},
      {id: 'channel-b', publisherId: 2, publisherTitle: 'Shared Publisher'},
    ],
  );
});

test('extractChannelsFromChannelRegistry keeps no-id publisher linkage stable across channel url reorder', () => {
  const registryA = {
    publishers: [
      {
        name: 'Shared Publisher',
        static: [
          'https://source-b.example/api/v1/channels/channel-b',
          'https://source-a.example/api/v1/channels/channel-a',
        ],
        living: [],
      },
      {
        name: 'Shared Publisher',
        static: ['https://source-c.example/api/v1/channels/channel-c'],
        living: [],
      },
    ],
  };
  const registryB = {
    publishers: [
      {
        name: 'Shared Publisher',
        static: [
          'https://source-a.example/api/v1/channels/channel-a',
          'https://source-b.example/api/v1/channels/channel-b',
        ],
        living: [],
      },
      registryA.publishers[1],
    ],
  };

  assert.deepEqual(
    summarizeChannelPublisherLinks(extractChannelsFromChannelRegistry(registryA)),
    summarizeChannelPublisherLinks(extractChannelsFromChannelRegistry(registryB)),
  );
});

test('dryrun feed-endpoint ingest does not hardcode publisher attribution', async () => {
  const server = await startFeedServer({
    channels: [
      {
        id: 'channel-a',
        title: 'Channel A',
        playlists: [{id: 'playlist-a', title: 'Playlist A'}],
      },
    ],
  });

  try {
    cleanupOutputDatabase();
    await runBuilder(['--channels-feed-endpoint', server.origin, '--dryrun', '--threads', '1']);

    const publishers = queryRows(
      "SELECT id || '|' || title FROM publishers ORDER BY id;",
    );
    assert.equal(publishers.length, 1);
    assert.equal(
      publishers[0],
      `1|${new URL(server.origin).host}`,
    );
    assert.ok(!publishers[0].includes('Feral File'));
  } finally {
    await server.close();
    cleanupOutputDatabase();
  }
});

test('dryrun feed-endpoint ingest prefers channel detail attribution over host fallback', async () => {
  const server = await startFeedServer({
    channels: [
      {
        id: 'channel-a',
        title: 'Channel A',
        publisher: {id: 7, name: 'Detail Publisher'},
        playlists: [{id: 'playlist-a', title: 'Playlist A'}],
      },
    ],
  });

  try {
    cleanupOutputDatabase();
    await runBuilder(['--channels-feed-endpoint', server.origin, '--dryrun', '--threads', '1']);

    const publishers = queryRows(
      "SELECT id || '|' || title FROM publishers ORDER BY id;",
    );
    assert.deepEqual(publishers, ['1|Detail Publisher']);
  } finally {
    await server.close();
    cleanupOutputDatabase();
  }
});

test('dryrun publish-artifact ingest keeps publisher rows and channel links consistent for multi-source input', async () => {
  const serverA = await startFeedServer({
    channels: [
      {
        id: 'channel-a',
        title: 'Channel A',
        playlists: [{id: 'playlist-a', title: 'Playlist A'}],
      },
    ],
  });
  const serverB = await startFeedServer({
    channels: [
      {
        id: 'channel-b',
        title: 'Channel B',
        playlists: [{id: 'playlist-b', title: 'Playlist B'}],
      },
    ],
  });
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'ff-feed-indexer-'));
  const artifactPath = path.join(tempDir, 'publish-artifact.json');

  fs.writeFileSync(
    artifactPath,
    JSON.stringify({
      exhibitions: [
        {
          status: 'success',
          channel: {url: `${serverA.origin}/api/v1/channels/channel-a`},
        },
        {
          status: 'success',
          channel: {url: `${serverB.origin}/api/v1/channels/channel-b`},
        },
      ],
    }),
  );

  try {
    cleanupOutputDatabase();
    await runBuilder(['--channels-source', artifactPath, '--dryrun', '--threads', '1']);

    const expectedPublishers = [serverA.origin, serverB.origin]
      .map((origin) => new URL(origin).host)
      .sort((left, right) => left.localeCompare(right))
      .map((host, index) => `${index + 1}|${host}`);
    const publishers = queryRows(
      "SELECT id || '|' || title FROM publishers ORDER BY id;",
    );
    const channelLinks = queryRows(`
SELECT c.id || '|' || p.title
FROM channels c
JOIN publishers p ON p.id = c.publisher_id
ORDER BY c.id;
    `);

    assert.deepEqual(publishers, expectedPublishers);
    assert.deepEqual(channelLinks, [
      `channel-a|${new URL(serverA.origin).host}`,
      `channel-b|${new URL(serverB.origin).host}`,
    ]);
  } finally {
    await serverA.close();
    await serverB.close();
    fs.rmSync(tempDir, {recursive: true, force: true});
    cleanupOutputDatabase();
  }
});

test('dryrun feed-endpoint ingest preserves legacy and structured playlist signatures', async () => {
  const server = await startFeedServer({
    channels: [
      {
        id: 'channel-a',
        title: 'Channel A',
        playlists: [
          {
            id: 'playlist-a',
            title: 'Playlist A',
            signature: 'legacy-signature',
            signatures: [{sig: 'structured-signature'}],
          },
        ],
      },
    ],
  });

  try {
    cleanupOutputDatabase();
    await runBuilder(['--channels-feed-endpoint', server.origin, '--dryrun', '--threads', '1']);

    const signatures = queryRows(
      "SELECT COALESCE(signature, 'NULL') || '|' || signatures FROM playlists WHERE id = 'playlist-a';",
    );
    assert.deepEqual(signatures, ['legacy-signature|[{"sig":"structured-signature"}]']);
  } finally {
    await server.close();
    cleanupOutputDatabase();
  }
});

test('dryrun feed-endpoint emits schema version 5', async () => {
  const server = await startFeedServer({
    channels: [
      {
        id: 'channel-a',
        title: 'Channel A',
        playlists: [{id: 'playlist-a', title: 'Playlist A'}],
      },
    ],
  });

  try {
    cleanupOutputDatabase();
    await runBuilder(['--channels-feed-endpoint', server.origin, '--dryrun', '--threads', '1']);

    const userVersion = queryRows('PRAGMA user_version;');
    assert.deepEqual(userVersion, ['5']);
  } finally {
    await server.close();
    cleanupOutputDatabase();
  }
});

test('dryrun feed-endpoint registry maps living list to channels.type=2', async () => {
  const server = await startFeedServer({
    channels: [
      {
        id: 'channel-static',
        title: 'Static',
        playlists: [{id: 'pl-s', title: 'P'}],
      },
      {
        id: 'channel-living',
        title: 'Living',
        playlists: [{id: 'pl-l', title: 'P'}],
      },
    ],
    livingChannelIds: ['channel-living'],
  });

  try {
    cleanupOutputDatabase();
    await runBuilder(['--channels-feed-endpoint', server.origin, '--dryrun', '--threads', '1']);

    const types = queryRows(
      'SELECT id || \'|\' || type FROM channels ORDER BY id;',
    );
    assert.deepEqual(types, [
      'channel-living|2',
      'channel-static|0',
    ]);
  } finally {
    await server.close();
    cleanupOutputDatabase();
  }
});

test('dryrun registry ingest keeps a multi-origin registry publisher unified', async () => {
  const serverA = await startFeedServer({
    channels: [
      {
        id: 'channel-a',
        title: 'Channel A',
        playlists: [{id: 'playlist-a', title: 'Playlist A'}],
      },
    ],
  });
  const serverB = await startFeedServer({
    channels: [
      {
        id: 'channel-b',
        title: 'Channel B',
        playlists: [{id: 'playlist-b', title: 'Playlist B'}],
      },
    ],
  });
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'ff-feed-indexer-'));
  const registryPath = path.join(tempDir, 'channels-registry.json');

  fs.writeFileSync(
    registryPath,
    JSON.stringify({
      publishers: [
        {
          id: 7,
          name: 'Registry Publisher',
          static: [
            `${serverA.origin}/api/v1/channels/channel-a`,
            `${serverB.origin}/api/v1/channels/channel-b`,
          ],
          living: [],
        },
      ],
    }),
  );

  try {
    cleanupOutputDatabase();
    await runBuilder(['--channels-source', registryPath, '--dryrun', '--threads', '1']);

    const publishers = queryRows(
      "SELECT id || '|' || title FROM publishers ORDER BY id;",
    );
    const channelLinks = queryRows(`
SELECT c.id || '|' || COALESCE(CAST(c.publisher_id AS TEXT), 'NULL') || '|' || p.title
FROM channels c
JOIN publishers p ON p.id = c.publisher_id
ORDER BY c.id;
    `);

    assert.deepEqual(publishers, ['1|Registry Publisher']);
    assert.deepEqual(channelLinks, [
      'channel-a|1|Registry Publisher',
      'channel-b|1|Registry Publisher',
    ]);
  } finally {
    await serverA.close();
    await serverB.close();
    fs.rmSync(tempDir, {recursive: true, force: true});
    cleanupOutputDatabase();
  }
});

test('dryrun registry ingest keeps registry identity when detail responses repeat explicit ids', async () => {
  const sharedPublisher = {id: 7, name: 'Registry Publisher'};
  const serverA = await startFeedServer({
    channels: [
      {
        id: 'channel-a',
        title: 'Channel A',
        publisher: sharedPublisher,
        playlists: [{id: 'playlist-a', title: 'Playlist A'}],
      },
    ],
  });
  const serverB = await startFeedServer({
    channels: [
      {
        id: 'channel-b',
        title: 'Channel B',
        publisher: sharedPublisher,
        playlists: [{id: 'playlist-b', title: 'Playlist B'}],
      },
    ],
  });
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'ff-feed-indexer-'));
  const registryPath = path.join(tempDir, 'channels-registry.json');

  fs.writeFileSync(
    registryPath,
    JSON.stringify({
      publishers: [
        {
          id: 7,
          name: 'Registry Publisher',
          static: [
            `${serverA.origin}/api/v1/channels/channel-a`,
            `${serverB.origin}/api/v1/channels/channel-b`,
          ],
          living: [],
        },
      ],
    }),
  );

  try {
    cleanupOutputDatabase();
    await runBuilder(['--channels-source', registryPath, '--dryrun', '--threads', '1']);

    const publishers = queryRows(
      "SELECT id || '|' || title FROM publishers ORDER BY id;",
    );
    const channelLinks = queryRows(`
SELECT c.id || '|' || COALESCE(CAST(c.publisher_id AS TEXT), 'NULL') || '|' || p.title
FROM channels c
JOIN publishers p ON p.id = c.publisher_id
ORDER BY c.id;
    `);

    assert.deepEqual(publishers, ['1|Registry Publisher']);
    assert.deepEqual(channelLinks, [
      'channel-a|1|Registry Publisher',
      'channel-b|1|Registry Publisher',
    ]);
  } finally {
    await serverA.close();
    await serverB.close();
    fs.rmSync(tempDir, {recursive: true, force: true});
    cleanupOutputDatabase();
  }
});

function runBuilder(args) {
  return new Promise((resolve, reject) => {
    const child = spawn('node', [SCRIPT_PATH, ...args], {
      cwd: ROOT,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let stdout = '';
    let stderr = '';

    child.stdout.on('data', (chunk) => {
      stdout += String(chunk);
    });
    child.stderr.on('data', (chunk) => {
      stderr += String(chunk);
    });
    child.on('error', reject);
    child.on('close', (code) => {
      if (code === 0) {
        resolve({stdout, stderr});
        return;
      }
      reject(new Error(
        `builder failed with code ${code}\nstdout:\n${stdout}\nstderr:\n${stderr}`,
      ));
    });
  });
}

function queryRows(sql) {
  const output = execFileSync('sqlite3', [OUTPUT_DB_PATH, sql], {
    cwd: ROOT,
    stdio: 'pipe',
    encoding: 'utf8',
  });
  return output
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);
}

function cleanupOutputDatabase() {
  for (const suffix of ['', '-shm', '-wal']) {
    fs.rmSync(`${OUTPUT_DB_PATH}${suffix}`, {force: true});
  }
}

function summarizeChannelPublisherLinks(channels) {
  return [...channels]
    .map((channel) => ({
      id: channel.id,
      publisherId: channel.publisherId,
      publisherTitle: channel.publisherTitle,
    }))
    .sort((left, right) => left.id.localeCompare(right.id));
}

async function startFeedServer({channels, registryPublisherName, livingChannelIds}) {
  const channelById = new Map(channels.map((channel) => [channel.id, channel]));
  const sockets = new Set();
  const server = http.createServer((req, res) => {
    const url = new URL(req.url, 'http://127.0.0.1');
    res.setHeader('Content-Type', 'application/json');

    if (req.method === 'GET' && url.pathname === '/api/v1/registry/channels') {
      const host = req.headers.host || '127.0.0.1';
      const origin = `http://${host}`;
      const publisherTitle = registryPublisherName
        || channels[0]?.publisher?.name
        || new URL(origin).host;
      const livingSet = livingChannelIds instanceof Set
        ? livingChannelIds
        : new Set(livingChannelIds || []);
      const staticUrls = [];
      const livingUrls = [];
      for (const ch of channels) {
        const channelUrl = `${origin}/api/v1/channels/${encodeURIComponent(ch.id)}`;
        if (livingSet.has(ch.id)) {
          livingUrls.push(channelUrl);
        } else {
          staticUrls.push(channelUrl);
        }
      }
      res.end(JSON.stringify({
        publishers: [
          {
            name: publisherTitle,
            static: staticUrls,
            living: livingUrls,
          },
        ],
      }));
      return;
    }

    const channelMatch = url.pathname.match(/^\/api\/v1\/channels\/([^/]+)$/u);
    if (req.method === 'GET' && channelMatch) {
      const channel = channelById.get(decodeURIComponent(channelMatch[1]));
      if (!channel) {
        res.statusCode = 404;
        res.end(JSON.stringify({error: 'not found'}));
        return;
      }
      res.end(JSON.stringify({
        id: channel.id,
        title: channel.title,
        publisher: channel.publisher || null,
        source: channel.source || null,
        created: '2024-01-01T00:00:00Z',
      }));
      return;
    }

    if (req.method === 'GET' && url.pathname === '/api/v1/playlists') {
      const channelId = url.searchParams.get('channel');
      const channel = channelId ? channelById.get(channelId) : null;
      if (!channel) {
        res.statusCode = 404;
        res.end(JSON.stringify({error: 'not found'}));
        return;
      }
      res.end(JSON.stringify({
        items: (channel.playlists || []).map((playlist) => ({
          id: playlist.id,
          title: playlist.title,
          created: '2024-01-02T00:00:00Z',
          items: [],
          signature: playlist.signature,
          signatures: playlist.signatures,
          dpVersion: playlist.dpVersion,
          slug: playlist.slug,
          defaults: playlist.defaults,
          dynamicQueries: playlist.dynamicQueries,
        })),
        hasMore: false,
      }));
      return;
    }

    res.statusCode = 404;
    res.end(JSON.stringify({error: 'not found'}));
  });
  server.keepAliveTimeout = 1;
  server.on('connection', (socket) => {
    sockets.add(socket);
    socket.on('close', () => {
      sockets.delete(socket);
    });
  });

  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  return {
    origin: `http://127.0.0.1:${address.port}`,
    close: () => new Promise((resolve, reject) => {
      for (const socket of sockets) {
        socket.destroy();
      }
      server.close((error) => {
        if (error) {
          reject(error);
          return;
        }
        resolve();
      });
    }),
  };
}
