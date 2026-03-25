const assert = require('node:assert/strict');
const fs = require('node:fs');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const {execFileSync, spawn} = require('node:child_process');

const {
  extractChannelsFromPublishArtifact,
  extractChannelsFromRegistry,
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

test('extractChannelsFromRegistry keeps publisher linkage stable across input reorder', () => {
  const registryA = [
    {
      id: 7,
      name: 'Publisher B',
      channel_urls: ['https://source-b.example/api/v1/channels/channel-b'],
    },
    {
      id: 3,
      name: 'Publisher A',
      channel_urls: ['https://source-a.example/api/v1/channels/channel-a'],
    },
  ];
  const registryB = [...registryA].reverse();

  const channelsA = extractChannelsFromRegistry(registryA);
  const channelsB = extractChannelsFromRegistry(registryB);

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

async function startFeedServer({channels}) {
  const channelById = new Map(channels.map((channel) => [channel.id, channel]));
  const sockets = new Set();
  const server = http.createServer((req, res) => {
    const url = new URL(req.url, 'http://127.0.0.1');
    res.setHeader('Content-Type', 'application/json');

    if (req.method === 'GET' && url.pathname === '/api/v1/channels') {
      res.end(JSON.stringify({
        items: channels.map((channel) => ({id: channel.id})),
        hasMore: false,
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
