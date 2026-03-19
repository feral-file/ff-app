#!/usr/bin/env node

/* eslint-disable no-console */
/* eslint-disable max-lines */
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const https = require('node:https');
const crypto = require('node:crypto');
const {execFileSync} = require('node:child_process');

const SCHEMA_VERSION = 3;
const SEED_FILENAME = 'ff_feed_indexer_seed.sqlite';
const DEFAULT_OUTPUT = path.resolve(
  __dirname,
  SEED_FILENAME,
);
const INDEXER_GET_TOKENS_QUERY = `
query getTokens(
  $owners: [String!]
  $chains: [String!]
  $contract_addresses: [String!]
  $token_ids: [Uint64!]
  $token_cids: [String!]
  $token_numbers: [String!]
  $limit: Uint8 = 20
  $offset: Uint64 = 0
  $sort_by: TokenSortBy = created_at
  $sort_order: Order = asc
) {
  tokens(
    owners: $owners
    chains: $chains
    contract_addresses: $contract_addresses
    token_ids: $token_ids
    token_cids: $token_cids
    token_numbers: $token_numbers
    limit: $limit
    offset: $offset
    sort_by: $sort_by
    sort_order: $sort_order
  ) {
    items {
      id
      chain
      contract_address
      standard
      token_cid
      token_number
      current_owner
      updated_at
      display {
        name
        image_url
        artists {
          name
          did
        }
      }
      owner_provenances {
        items {
          owner_address
          last_timestamp
          last_tx_index
        }
      }
      media_assets {
        source_url
        mime_type
        variants(keys: [xs, l, xl, xxl, dash, hls])
      }
    }
    offset
  }
}
`;
const REMOTE_CONFIG_URL =
  'https://dp1-feed-operator-api-prod.autonomy-system.workers.dev/api/v1/registry/channels';
const DEFAULT_CHANNEL_SOURCE = REMOTE_CONFIG_URL;
const INDEXER_API_URL = 'https://indexer-v2.feralfile.com';
const INDEXER_BATCH_SIZE = 50;

const ARGS = parseArgs(process.argv.slice(2));

const NOW_US = String(Date.now() * 1000);
const FALLBACK_THUMBNAIL_URI = 'assets/images/no_thumbnail.svg';

main().catch((error) => {
  console.error(`[error] ${error?.stack || String(error)}`);
  process.exit(1);
});

async function main() {
  ensureSqliteCli();

  const env = process.env;
  const indexerApiUrl = INDEXER_API_URL;
  const channelSource = ARGS.channelsSource || DEFAULT_CHANNEL_SOURCE;
  const channelsFeedEndpoint = ARGS.channelsFeedEndpoint;

  const outputPath = DEFAULT_OUTPUT;
  const s3Config = ARGS.dryrun
    ? null
    : resolveS3Config({
      args: ARGS,
      env,
    });
  fs.mkdirSync(path.dirname(outputPath), {recursive: true});
  removeSqliteSidecars(outputPath);
  if (fs.existsSync(outputPath)) {
    fs.unlinkSync(outputPath);
  }

  if (channelsFeedEndpoint) {
    console.log(`[build] channels_feed_endpoint=${channelsFeedEndpoint}`);
  } else {
    console.log(`[build] channels_source=${channelSource}`);
  }
  console.log(`[build] indexer=${indexerApiUrl}`);
  console.log(`[build] out=${outputPath}`);

  const channels = channelsFeedEndpoint
    ? await fetchChannelsFromFeedEndpoint(channelsFeedEndpoint)
    : await fetchChannelsFromSource(channelSource);
  if (channels.length === 0) {
    throw new Error('No channels fetched from source.');
  }
  enforceRequiredChannels(channels, ARGS.requireChannelIds);
  console.log(`[feed] channels=${channels.length}`);
  const threads = normalizeThreads(ARGS.threads);
  console.log(`[build] threads=${threads}`);

  const data = {
    publishers: new Map(),
    channels: new Map(),
    playlists: new Map(),
    items: new Map(),
    entries: new Map(),
    channelItemIds: new Map(),
  };

  const fetchedByOrder = new Array(channels.length);
  await runWithConcurrency(
    channels.map((channelRef, index) => ({channelRef, index})),
    threads,
    async ({channelRef, index}) => {
      const channel = await fetchChannelById(
        channelRef.baseUrl,
        channelRef.id,
      );
      if (!channel?.id) {
        return;
      }
      const channelPlaylists = await fetchPlaylistsForChannel(
        channelRef.baseUrl,
        channel.id,
        ARGS.maxPlaylistsPerChannel,
      );
      fetchedByOrder[index] = {
        channel,
        channelPlaylists,
        baseUrl: channelRef.baseUrl,
        publisherId: channelRef.publisherId,
        publisherTitle: channelRef.publisherTitle,
      };
    },
  );

  for (
    let channelSortOrder = 0;
    channelSortOrder < fetchedByOrder.length;
    channelSortOrder += 1
  ) {
    const fetched = fetchedByOrder[channelSortOrder];
    if (!fetched) {
      continue;
    }
    ingestChannel(
      data,
      fetched.channel,
      fetched.baseUrl,
      channelSortOrder,
      fetched.publisherId,
      fetched.publisherTitle,
    );
    ingestChannelPlaylists(
      data,
      fetched.channel,
      fetched.channelPlaylists,
      fetched.baseUrl,
    );
    console.log(
      `[feed] channel=${fetched.channel.id} playlists=${fetched.channelPlaylists.length}`,
    );
  }

  const cidToItemIds = collectCidToItemIds(data.items);
  console.log(
    `[feed] items=${data.items.size} entries=${data.entries.size} cids=${cidToItemIds.size}`,
  );

  if (cidToItemIds.size > 0) {
    const channelTasks = buildChannelEnrichmentTasks({
      channelItemIds: data.channelItemIds,
      items: data.items,
    });
    console.log(
      `[indexer] channels_to_enrich=${channelTasks.length} threads=${threads}`,
    );
    await runWithConcurrency(channelTasks, threads, async (task) => {
      const tokensByCid = await fetchIndexerTokensByCids({
        indexerApiUrl,
        cids: task.cids,
        batchSize: INDEXER_BATCH_SIZE,
        channelId: task.channelId,
      });
      applyIndexerEnrichment(data.items, task.cidToItemIds, tokensByCid);
    });
    console.log(
      `[indexer] enriched_item_rows=${countEnriched(data.items)}`,
    );
  }
  ensureAllItemsHaveThumbnail(data.items);

  const sql = buildSql({
    publishers: data.publishers,
    channels: data.channels,
    playlists: data.playlists,
    items: data.items,
    entries: data.entries,
  });
  execSqlite(outputPath, sql);
  validateOutputDatabase(outputPath);
  finalizeDatabaseFile(outputPath);
  if (ARGS.dryrun) {
    console.log('[dryrun] skipping S3 upload');
  } else if (s3Config) {
    const uploadResult = await uploadToS3({
      filePath: outputPath,
      config: s3Config,
    });
    console.log(`[upload] url=${uploadResult.url}`);
  }
  console.log('[done] sqlite artifact created');
}

function parseArgs(argv) {
  const out = {
    s3AccessKeyId: undefined,
    s3SecretAccessKey: undefined,
    s3Endpoint: undefined,
    maxPlaylistsPerChannel: undefined,
    threads: Math.max(1, Math.min(8, os.cpus().length || 4)),
    channelsSource: undefined,
    channelsFeedEndpoint: undefined,
    requireChannelIds: [],
    dryrun: false,
  };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = argv[i + 1];
    switch (arg) {
      case '--s3-access-key-id':
        out.s3AccessKeyId = next;
        i += 1;
        break;
      case '--s3-secret-access-key':
        out.s3SecretAccessKey = next;
        i += 1;
        break;
      case '--s3-endpoint':
        out.s3Endpoint = next;
        i += 1;
        break;
      case '--max-playlists-per-channel':
        out.maxPlaylistsPerChannel = Number(next);
        i += 1;
        break;
      case '--threads':
        out.threads = Number(next);
        i += 1;
        break;
      case '--channels-source':
        out.channelsSource = next;
        i += 1;
        break;
      case '--channels-feed-endpoint':
        out.channelsFeedEndpoint = next;
        i += 1;
        break;
      case '--require-channel-id':
        out.requireChannelIds.push(String(next || '').trim());
        i += 1;
        break;
      case '--dryrun':
        out.dryrun = true;
        break;
      default:
        if (arg.startsWith('-')) {
          throw new Error(`Unknown argument: ${arg}`);
        }
        break;
    }
  }
  return out;
}

function enforceRequiredChannels(channels, requiredChannelIds = []) {
  const required = requiredChannelIds.filter((id) => id);
  if (required.length === 0) {
    return;
  }
  const available = new Set(channels.map((channel) => channel.id));
  const missing = required.filter((id) => !available.has(id));
  if (missing.length > 0) {
    throw new Error(
      `Required channels are missing from source: ${missing.join(', ')}`
    );
  }
}

function ensureSqliteCli() {
  try {
    execFileSync('sqlite3', ['-version'], {stdio: 'ignore'});
  } catch {
    throw new Error('sqlite3 CLI is required but was not found in PATH.');
  }
}

async function fetchChannelsFromSource(source) {
  const payload = await loadJsonSource(source);
  if (Array.isArray(payload?.exhibitions)) {
    return extractChannelsFromPublishArtifact(payload);
  }
  if (Array.isArray(payload)) {
    return extractChannelsFromRegistry(payload);
  }
  throw new Error(
    'Invalid channels source format: expected registry format (array) or publish artifact format (object with exhibitions array)'
  );
}

async function fetchChannelsFromFeedEndpoint(rawFeedEndpoint) {
  const baseUrl = normalizeOrigin(rawFeedEndpoint);
  const channels = await fetchFeedPages({
    feedBaseUrl: baseUrl,
    route: '/api/v1/channels',
  });
  const out = [];
  for (const channel of channels) {
    if (!channel?.id) {
      continue;
    }
    out.push({
      id: String(channel.id),
      baseUrl,
      channelUrl: `${baseUrl}/api/v1/channels/${encodeURIComponent(channel.id)}`,
      publisherId: 1,
      publisherTitle: 'Feral File',
    });
  }
  const deduped = new Map();
  for (const channel of out) {
    deduped.set(`${channel.baseUrl}::${channel.id}`, channel);
  }
  return [...deduped.values()];
}

function normalizeOrigin(rawUrl) {
  if (typeof rawUrl !== 'string' || !rawUrl.trim()) {
    throw new Error('Invalid feed endpoint: expected non-empty URL');
  }
  let parsed;
  try {
    parsed = new URL(rawUrl);
  } catch {
    throw new Error(`Invalid feed endpoint URL: ${rawUrl}`);
  }
  if (!/^https?:$/.test(parsed.protocol)) {
    throw new Error(
      `Unsupported feed endpoint protocol: ${parsed.protocol} (expected http/https)`
    );
  }
  return parsed.origin;
}

function extractChannelsFromRegistry(publishers) {
  if (!Array.isArray(publishers)) {
    throw new Error('Invalid registry format: expected array of publishers');
  }

  const channels = [];
  for (let i = 0; i < publishers.length; i += 1) {
    const publisher = publishers[i];
    const publisherId = i + 1;
    const publisherTitle = String(publisher?.name || '').trim() || `Publisher ${publisherId}`;
    const channelUrls = Array.isArray(publisher?.channel_urls)
      ? publisher.channel_urls
      : [];
    for (const rawChannelUrl of channelUrls) {
      const parsed = parseChannelUrl(rawChannelUrl);
      if (parsed) {
        channels.push({
          ...parsed,
          publisherId,
          publisherTitle,
        });
      }
    }
  }

  const deduped = new Map();
  for (const channel of channels) {
    deduped.set(`${channel.baseUrl}::${channel.id}`, channel);
  }
  return [...deduped.values()];
}

function extractChannelsFromPublishArtifact(payload) {
  const exhibitions = payload.exhibitions;
  const channels = [];
  for (const exhibition of exhibitions) {
    if (!exhibition || exhibition.status !== 'success') {
      continue;
    }
    const parsed = parseChannelUrl(exhibition?.channel?.url);
    if (!parsed) {
      continue;
    }
    channels.push({
      ...parsed,
      publisherId: 1,
      publisherTitle: 'Feral File',
    });
  }
  const deduped = new Map();
  for (const channel of channels) {
    deduped.set(`${channel.baseUrl}::${channel.id}`, channel);
  }
  return [...deduped.values()];
}

async function loadJsonSource(source) {
  if (typeof source !== 'string' || source.trim() === '') {
    throw new Error('Invalid channels source: expected URL or file path');
  }
  const trimmed = source.trim();
  if (/^https?:\/\//.test(trimmed)) {
    return fetchJson(trimmed);
  }
  const filePath = path.resolve(trimmed);
  if (!fs.existsSync(filePath)) {
    throw new Error(`Channels source file not found: ${filePath}`);
  }
  const content = fs.readFileSync(filePath, 'utf-8');
  try {
    return JSON.parse(content);
  } catch (error) {
    throw new Error(`Invalid JSON in channels source file ${filePath}: ${error}`);
  }
}

function parseChannelUrl(rawChannelUrl) {
  if (typeof rawChannelUrl !== 'string' || !rawChannelUrl.trim()) {
    return null;
  }
  try {
    const uri = new URL(rawChannelUrl);
    const pathSegments = uri.pathname.split('/').filter(Boolean);
    const channelsIndex = pathSegments.lastIndexOf('channels');
    if (channelsIndex < 0 || channelsIndex >= pathSegments.length - 1) {
      return null;
    }
    const channelId = pathSegments[channelsIndex + 1];
    if (!channelId) {
      return null;
    }
    return {
      id: channelId,
      baseUrl: uri.origin,
      channelUrl: rawChannelUrl,
    };
  } catch {
    return null;
  }
}

async function fetchChannelById(feedBaseUrl, channelId) {
  return fetchJson(
    `${trimSlash(feedBaseUrl)}/api/v1/channels/${encodeURIComponent(channelId)}`,
    {
      headers: {
        'Content-Type': 'application/json',
      },
    },
  );
}

async function fetchPlaylistsForChannel(
  feedBaseUrl,
  channelId,
  maxPlaylistsPerChannel,
) {
  const playlists = await fetchFeedPages({
    feedBaseUrl,
    route: '/api/v1/playlists',
    extraParams: {channel: channelId},
    maxItems: maxPlaylistsPerChannel,
  });
  return playlists;
}

async function fetchFeedPages({
  feedBaseUrl,
  route,
  extraParams = {},
  maxItems,
}) {
  const items = [];
  let cursor = null;
  let hasMore = true;
  while (hasMore) {
    const params = new URLSearchParams({
      limit: '100',
      ...extraParams,
    });
    if (cursor) {
      params.set('cursor', cursor);
    }
    const url = `${trimSlash(feedBaseUrl)}${route}?${params.toString()}`;
    const payload = await fetchJson(url, {
      headers: {
        'Content-Type': 'application/json',
      },
    });
    const pageItems = Array.isArray(payload?.items) ? payload.items : [];
    for (const item of pageItems) {
      items.push(item);
      if (maxItems && items.length >= maxItems) {
        return items;
      }
    }
    hasMore = Boolean(payload?.hasMore);
    cursor = typeof payload?.cursor === 'string' ? payload.cursor : null;
    if (hasMore && !cursor) {
      break;
    }
  }
  return items;
}

function ingestChannel(
  data,
  channel,
  baseUrl,
  sortOrder,
  publisherId,
  publisherTitle,
) {
  if (!channel?.id) {
    return;
  }
  if (Number.isFinite(publisherId) && publisherId > 0) {
    data.publishers.set(publisherId, {
      id: publisherId,
      title: publisherTitle || `Publisher ${publisherId}`,
      created_at_us: NOW_US,
      updated_at_us: NOW_US,
    });
  }
  const createdAtUs = toMicros(channel.created) || NOW_US;
  data.channels.set(channel.id, {
    id: channel.id,
    type: 0,
    base_url: baseUrl,
    slug: channel.slug || null,
    publisher_id: Number.isFinite(publisherId) && publisherId > 0
      ? publisherId
      : null,
    title: channel.title || '',
    curator: channel.curator || null,
    summary: channel.summary || null,
    cover_image_uri: channel.coverImage || channel.coverImageUri || null,
    created_at_us: createdAtUs,
    updated_at_us: createdAtUs,
    sort_order: Number.isFinite(sortOrder) ? sortOrder : null,
  });
}

function ingestChannelPlaylists(data, channel, playlists, baseUrl) {
  for (const playlist of playlists) {
    if (!playlist?.id) {
      continue;
    }
    const createdAtUs = toMicros(playlist.created) || NOW_US;
    const signature = typeof playlist.signature === 'string' ? playlist.signature : '';
    const signaturesRaw = Array.isArray(playlist.signatures)
      ? playlist.signatures
      : (signature ? [signature] : []);
    const signatures = signaturesRaw.map((s) => String(s));
    const dynamicQueries = Array.isArray(playlist.dynamicQueries)
      ? playlist.dynamicQueries
      : [];
    const sortMode = dynamicQueries.length > 0 ? 1 : 0;
    const items = Array.isArray(playlist.items) ? playlist.items : [];

    data.playlists.set(playlist.id, {
      id: playlist.id,
      channel_id: channel.id,
      type: 0,
      base_url: baseUrl,
      dp_version: playlist.dpVersion || null,
      slug: playlist.slug || null,
      title: playlist.title || '',
      created_at_us: createdAtUs,
      updated_at_us: createdAtUs,
      signatures_json: JSON.stringify(signatures),
      defaults_json: playlist.defaults ? JSON.stringify(playlist.defaults) : null,
      dynamic_queries_json: dynamicQueries.length > 0 ? JSON.stringify(dynamicQueries) : null,
      owner_address: null,
      owner_chain: null,
      sort_mode: sortMode,
      item_count: items.length,
    });

    for (let position = 0; position < items.length; position += 1) {
      const item = items[position];
      const itemId = String(item.id || '');
      if (!itemId) {
        continue;
      }
      const existing = data.items.get(itemId);
      const merged = mergeFeedItem(existing, item);
      data.items.set(itemId, merged);
      if (!data.channelItemIds.has(channel.id)) {
        data.channelItemIds.set(channel.id, new Set());
      }
      data.channelItemIds.get(channel.id).add(itemId);

      const entryKey = `${playlist.id}::${itemId}`;
      data.entries.set(entryKey, {
        playlist_id: playlist.id,
        item_id: itemId,
        position,
        sort_key_us: 0,
        updated_at_us: NOW_US,
      });
    }
  }
}

function mergeFeedItem(existing, feedItem) {
  const base = existing || {
    id: String(feedItem.id),
    kind: 0,
    title: null,
    subtitle: null,
    thumbnail_uri: FALLBACK_THUMBNAIL_URI,
    duration_sec: null,
    provenance_json: null,
    source_uri: null,
    ref_uri: null,
    license: null,
    repro_json: null,
    override_json: null,
    display_json: null,
    token_data_json: null,
    list_artist_json: null,
    enrichment_status: 0,
    updated_at_us: NOW_US,
  };

  const nextTitle = chooseValue(base.title, feedItem.title, 'Unknown');
  return {
    ...base,
    kind: 0,
    title: nextTitle,
    duration_sec: toInt(feedItem.duration),
    provenance_json: feedItem.provenance
      ? JSON.stringify(feedItem.provenance)
      : base.provenance_json,
    source_uri: chooseValue(base.source_uri, feedItem.source, null),
    ref_uri: chooseValue(base.ref_uri, feedItem.ref, null),
    license: chooseValue(base.license, feedItem.license, null),
    repro_json: feedItem.repro ? JSON.stringify(feedItem.repro) : base.repro_json,
    display_json: feedItem.display ? JSON.stringify(feedItem.display) : base.display_json,
    thumbnail_uri: chooseValue(
      base.thumbnail_uri,
      feedItem.thumbnailUri || feedItem.thumbnail_uri,
      FALLBACK_THUMBNAIL_URI,
    ),
    updated_at_us: NOW_US,
  };
}

function chooseValue(currentValue, incomingValue, fallback) {
  if (currentValue !== null && currentValue !== undefined && currentValue !== '') {
    return currentValue;
  }
  if (incomingValue !== null && incomingValue !== undefined && incomingValue !== '') {
    return incomingValue;
  }
  return fallback;
}

function collectCidToItemIds(itemsMap) {
  const cidMap = new Map();
  for (const [itemId, item] of itemsMap.entries()) {
    if (!item.provenance_json) {
      continue;
    }
    let provenance;
    try {
      provenance = JSON.parse(item.provenance_json);
    } catch {
      continue;
    }
    const cid = provenanceToCid(provenance);
    if (!cid) {
      continue;
    }
    if (!cidMap.has(cid)) {
      cidMap.set(cid, []);
    }
    cidMap.get(cid).push(itemId);
  }
  return cidMap;
}

function provenanceToCid(provenance) {
  if (!provenance || typeof provenance !== 'object') {
    return null;
  }
  const contract = provenance.contract;
  if (!contract || typeof contract !== 'object') {
    return null;
  }
  const chain = String(contract.chain || '').toLowerCase();
  const standard = String(contract.standard || '').toLowerCase();
  const address = String(contract.address || '');
  const tokenId = String(contract.tokenId || '');
  let prefix = '';
  if (chain === 'evm') {
    prefix = 'eip155:1';
  } else if (chain === 'tezos') {
    prefix = 'tezos:mainnet';
  }
  if (!prefix || !standard || standard === 'other' || !address || !tokenId) {
    return null;
  }
  return `${prefix}:${standard}:${address}:${tokenId}`;
}

async function fetchIndexerTokensByCids({
  indexerApiUrl,
  cids,
  batchSize = 50,
  channelId = '',
}) {
  const out = new Map();
  const uniqueCids = [...new Set(cids)].filter(Boolean);
  const chunks = chunk(uniqueCids, Math.max(1, Math.min(255, batchSize)));
  let loaded = 0;
  for (const cidChunk of chunks) {
    const payload = await fetchJson(`${trimSlash(indexerApiUrl)}/graphql`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        query: INDEXER_GET_TOKENS_QUERY,
        variables: {
          token_cids: cidChunk,
          limit: Math.min(255, cidChunk.length),
          offset: 0,
        },
      }),
    });
    const tokens = payload?.data?.tokens?.items;
    if (!Array.isArray(tokens)) {
      throw new Error(
        `Invalid indexer response for batch (${cidChunk.length}).`,
      );
    }
    for (const token of tokens) {
      const cid = token?.token_cid || token?.cid;
      if (cid) {
        out.set(String(cid), token);
      }
    }
    loaded += tokens.length;
    console.log(
      `[indexer] channel=${channelId || '-'} batch=${cidChunk.length} loaded=${loaded}/${uniqueCids.length}`,
    );
  }
  return out;
}

function applyIndexerEnrichment(itemsMap, cidToItemIds, tokensByCid) {
  for (const [cid, itemIds] of cidToItemIds.entries()) {
    const token = tokensByCid.get(cid);
    if (!token) {
      for (const itemId of itemIds) {
        const row = itemsMap.get(itemId);
        if (!row) {
          continue;
        }
        row.enrichment_status = 2;
        row.updated_at_us = NOW_US;
      }
      continue;
    }
    for (const itemId of itemIds) {
      const row = itemsMap.get(itemId);
      if (!row) {
        continue;
      }
      const enriched = tokenToItemPatch(token);
      row.kind = 1;
      row.title = enriched.title;
      row.subtitle = enriched.subtitle;
      row.thumbnail_uri = enriched.thumbnailUri;
      row.list_artist_json = enriched.listArtistJson;
      row.token_data_json = JSON.stringify(toRestTokenJson(token));
      row.enrichment_status = 1;
      row.updated_at_us = NOW_US;
    }
  }
}

function tokenToItemPatch(token) {
  const artists = (token?.display?.artists || [])
    .filter((artist) => artist && (artist.name || artist.did))
    .map((artist) => ({
      id: artist.did || '',
      name: artist.name || '',
    }));
  const subtitle = artists.length > 0
    ? artists
      .map((artist) => artist.name)
      .filter((name) => Boolean(name))
      .join(', ')
    : null;
  return {
    title: token?.display?.name || 'Untitled',
    subtitle,
    thumbnailUri: resolveThumbnailUrl(token),
    listArtistJson: artists.length > 0 ? JSON.stringify(artists) : null,
  };
}

function resolveThumbnailUrl(token) {
  const imageUrl = token?.display?.image_url;
  const mediaAssets = Array.isArray(token?.media_assets)
    ? token.media_assets
    : [];

  // Find media asset matching the image_url
  if (imageUrl) {
    for (const asset of mediaAssets) {
      if (asset?.source_url === imageUrl) {
        // Verify it's an image by checking mime_type
        const mimeType = asset?.mime_type;
        if (mimeType && typeof mimeType === 'string' && mimeType.startsWith('image/')) {
          // Check for xs variant first
          const variants = asset?.variants;
          if (variants && typeof variants === 'object' && variants.xs) {
            return String(variants.xs);
          }
          // Fall back to source_url
          return imageUrl;
        }
        // If mime_type is not an image, fall back to source_url
        return imageUrl;
      }
    }
    // If no matching asset found, return the image_url directly
    return imageUrl;
  }

  // Final fallback to any media asset source_url
  for (const asset of mediaAssets) {
    if (asset?.source_url) {
      return asset.source_url;
    }
  }

  return FALLBACK_THUMBNAIL_URI;
}

function toRestTokenJson(token) {
  return {
    id: asInt(token?.id),
    cid: token?.token_cid || token?.cid || '',
    chain: token?.chain || '',
    standard: token?.standard || '',
    contract_address: token?.contract_address || '',
    token_number: token?.token_number != null ? String(token.token_number) : '',
    display: token?.display || null,
    owners: token?.owners || null,
    provenance_events: token?.provenance_events || null,
    owner_provenances: token?.owner_provenances || null,
    media_assets: token?.media_assets || null,
    current_owner: token?.current_owner || null,
    updated_at: token?.updated_at || null,
  };
}

function countEnriched(itemsMap) {
  let count = 0;
  for (const row of itemsMap.values()) {
    if (row.enrichment_status === 1) {
      count += 1;
    }
  }
  return count;
}

function normalizeThreads(rawThreads) {
  const parsed = Number(rawThreads);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return 1;
  }
  return Math.max(1, Math.trunc(parsed));
}

function buildChannelEnrichmentTasks({channelItemIds, items}) {
  const tasks = [];
  for (const [channelId, itemIdsSet] of channelItemIds.entries()) {
    const cidToItemIds = new Map();
    for (const itemId of itemIdsSet) {
      const item = items.get(itemId);
      if (!item?.provenance_json) {
        continue;
      }
      let provenance;
      try {
        provenance = JSON.parse(item.provenance_json);
      } catch {
        continue;
      }
      const cid = provenanceToCid(provenance);
      if (!cid) {
        continue;
      }
      if (!cidToItemIds.has(cid)) {
        cidToItemIds.set(cid, []);
      }
      cidToItemIds.get(cid).push(itemId);
    }
    if (cidToItemIds.size > 0) {
      tasks.push({
        channelId,
        cidToItemIds,
        cids: [...cidToItemIds.keys()],
      });
    }
  }
  return tasks;
}

async function runWithConcurrency(items, concurrency, worker) {
  const queue = [...items];
  const workers = [];
  const count = Math.min(queue.length, Math.max(1, concurrency));
  for (let i = 0; i < count; i += 1) {
    workers.push((async () => {
      while (queue.length > 0) {
        const task = queue.shift();
        if (!task) {
          continue;
        }
        await worker(task);
      }
    })());
  }
  await Promise.all(workers);
}

function ensureAllItemsHaveThumbnail(itemsMap) {
  for (const item of itemsMap.values()) {
    if (!item.thumbnail_uri || String(item.thumbnail_uri).trim().length === 0) {
      item.thumbnail_uri = FALLBACK_THUMBNAIL_URI;
    }
  }
}

function buildSql({publishers, channels, playlists, items, entries}) {
  const lines = [];
  lines.push('PRAGMA foreign_keys = ON;');
  lines.push('PRAGMA journal_mode = WAL;');
  lines.push('PRAGMA synchronous = NORMAL;');
  lines.push(`PRAGMA user_version = ${SCHEMA_VERSION};`);
  lines.push('BEGIN IMMEDIATE;');

  lines.push(`
CREATE TABLE IF NOT EXISTS publishers (
  id INTEGER NOT NULL PRIMARY KEY,
  title TEXT NOT NULL,
  created_at_us INTEGER NOT NULL,
  updated_at_us INTEGER NOT NULL
);`);

  lines.push(`
CREATE TABLE IF NOT EXISTS channels (
  id TEXT NOT NULL PRIMARY KEY,
  type INTEGER NOT NULL,
  base_url TEXT,
  slug TEXT,
  publisher_id INTEGER REFERENCES publishers(id),
  title TEXT NOT NULL,
  curator TEXT,
  summary TEXT,
  cover_image_uri TEXT,
  created_at_us INTEGER NOT NULL,
  updated_at_us INTEGER NOT NULL,
  sort_order INTEGER
);`);

  lines.push(`
CREATE TABLE IF NOT EXISTS playlists (
  id TEXT NOT NULL PRIMARY KEY,
  channel_id TEXT,
  type INTEGER NOT NULL,
  base_url TEXT,
  dp_version TEXT,
  slug TEXT,
  title TEXT NOT NULL,
  created_at_us INTEGER NOT NULL,
  updated_at_us INTEGER NOT NULL,
  signatures_json TEXT NOT NULL,
  defaults_json TEXT,
  dynamic_queries_json TEXT,
  owner_address TEXT,
  owner_chain TEXT,
  sort_mode INTEGER NOT NULL,
  item_count INTEGER NOT NULL DEFAULT 0
);`);

  lines.push(`
CREATE TABLE IF NOT EXISTS items (
  id TEXT NOT NULL PRIMARY KEY,
  kind INTEGER NOT NULL,
  title TEXT,
  subtitle TEXT,
  thumbnail_uri TEXT,
  duration_sec INTEGER,
  provenance_json TEXT,
  source_uri TEXT,
  ref_uri TEXT,
  license TEXT,
  repro_json TEXT,
  override_json TEXT,
  display_json TEXT,
  token_data_json TEXT,
  list_artist_json TEXT,
  enrichment_status INTEGER NOT NULL DEFAULT 0,
  updated_at_us INTEGER NOT NULL
);`);

  lines.push(`
CREATE TABLE IF NOT EXISTS playlist_entries (
  playlist_id TEXT NOT NULL,
  item_id TEXT NOT NULL,
  position INTEGER,
  sort_key_us INTEGER NOT NULL,
  updated_at_us INTEGER NOT NULL,
  PRIMARY KEY (playlist_id, item_id)
);`);

  lines.push(`
CREATE INDEX IF NOT EXISTS idx_channels_publisher
ON channels(publisher_id);`);
  lines.push(`
CREATE INDEX IF NOT EXISTS idx_channels_type_order
ON channels(type, sort_order);`);
  lines.push(`
CREATE INDEX IF NOT EXISTS idx_playlists_channel
ON playlists(channel_id, type);`);
  lines.push(`
CREATE INDEX IF NOT EXISTS idx_playlists_owner
ON playlists(type, owner_address);`);
  lines.push(`
CREATE INDEX IF NOT EXISTS idx_items_kind_updated
ON items(kind, updated_at_us);`);
  lines.push(`
CREATE INDEX IF NOT EXISTS idx_entries_sort
ON playlist_entries(playlist_id, sort_key_us DESC, item_id DESC);`);
  lines.push(`
CREATE INDEX IF NOT EXISTS idx_entries_position
ON playlist_entries(playlist_id, position ASC, item_id ASC);`);
  lines.push(`
CREATE INDEX IF NOT EXISTS idx_entries_item
ON playlist_entries(item_id, playlist_id);`);

  lines.push(`
CREATE VIRTUAL TABLE IF NOT EXISTS channels_fts
USING fts5(
  id UNINDEXED,
  title,
  tokenize = 'unicode61 remove_diacritics 2'
);`);
  lines.push(`
CREATE VIRTUAL TABLE IF NOT EXISTS playlists_fts
USING fts5(
  id UNINDEXED,
  title,
  tokenize = 'unicode61 remove_diacritics 2'
);`);
  lines.push(`
CREATE VIRTUAL TABLE IF NOT EXISTS items_fts
USING fts5(
  id UNINDEXED,
  title,
  tokenize = 'unicode61 remove_diacritics 2'
);`);
  lines.push(`
CREATE VIRTUAL TABLE IF NOT EXISTS item_artists_fts
USING fts5(
  id UNINDEXED,
  artist_name,
  tokenize = 'unicode61 remove_diacritics 2'
);`);

  lines.push(`
CREATE TRIGGER IF NOT EXISTS channels_ai AFTER INSERT ON channels BEGIN
  INSERT INTO channels_fts(id, title) VALUES (new.id, new.title);
END;`);
  lines.push(`
CREATE TRIGGER IF NOT EXISTS channels_ad AFTER DELETE ON channels BEGIN
  DELETE FROM channels_fts WHERE id = old.id;
END;`);
  lines.push(`
CREATE TRIGGER IF NOT EXISTS channels_au AFTER UPDATE ON channels BEGIN
  DELETE FROM channels_fts WHERE id = old.id;
  INSERT INTO channels_fts(id, title) VALUES (new.id, new.title);
END;`);

  lines.push(`
CREATE TRIGGER IF NOT EXISTS playlists_ai AFTER INSERT ON playlists BEGIN
  INSERT INTO playlists_fts(id, title) VALUES (new.id, new.title);
END;`);
  lines.push(`
CREATE TRIGGER IF NOT EXISTS playlists_ad AFTER DELETE ON playlists BEGIN
  DELETE FROM playlists_fts WHERE id = old.id;
END;`);
  lines.push(`
CREATE TRIGGER IF NOT EXISTS playlists_au AFTER UPDATE ON playlists BEGIN
  DELETE FROM playlists_fts WHERE id = old.id;
  INSERT INTO playlists_fts(id, title) VALUES (new.id, new.title);
END;`);

  lines.push(`
CREATE TRIGGER IF NOT EXISTS items_ai AFTER INSERT ON items BEGIN
  INSERT INTO items_fts(id, title) VALUES (new.id, COALESCE(new.title, ''));
  INSERT INTO item_artists_fts(id, artist_name)
  SELECT new.id, COALESCE(json_extract(j.value, '$.name'), '')
  FROM json_each(
    CASE
      WHEN json_valid(new.list_artist_json) THEN new.list_artist_json
      ELSE '[]'
    END
  ) AS j
  WHERE COALESCE(json_extract(j.value, '$.name'), '') != '';
END;`);
  lines.push(`
CREATE TRIGGER IF NOT EXISTS items_ad AFTER DELETE ON items BEGIN
  DELETE FROM items_fts WHERE id = old.id;
  DELETE FROM item_artists_fts WHERE id = old.id;
END;`);
  lines.push(`
CREATE TRIGGER IF NOT EXISTS items_au AFTER UPDATE ON items BEGIN
  DELETE FROM items_fts WHERE id = old.id;
  INSERT INTO items_fts(id, title) VALUES (new.id, COALESCE(new.title, ''));
  DELETE FROM item_artists_fts WHERE id = old.id;
  INSERT INTO item_artists_fts(id, artist_name)
  SELECT new.id, COALESCE(json_extract(j.value, '$.name'), '')
  FROM json_each(
    CASE
      WHEN json_valid(new.list_artist_json) THEN new.list_artist_json
      ELSE '[]'
    END
  ) AS j
  WHERE COALESCE(json_extract(j.value, '$.name'), '') != '';
END;`);

  for (const row of publishers.values()) {
    lines.push(insertUpsertSql('publishers', [
      'id',
      'title',
      'created_at_us',
      'updated_at_us',
    ], row, ['id']));
  }

  for (const row of channels.values()) {
    lines.push(insertUpsertSql('channels', [
      'id',
      'type',
      'base_url',
      'slug',
      'publisher_id',
      'title',
      'curator',
      'summary',
      'cover_image_uri',
      'created_at_us',
      'updated_at_us',
      'sort_order',
    ], row, ['id']));
  }

  for (const row of playlists.values()) {
    lines.push(insertUpsertSql('playlists', [
      'id',
      'channel_id',
      'type',
      'base_url',
      'dp_version',
      'slug',
      'title',
      'created_at_us',
      'updated_at_us',
      'signatures_json',
      'defaults_json',
      'dynamic_queries_json',
      'owner_address',
      'owner_chain',
      'sort_mode',
      'item_count',
    ], row, ['id']));
  }

  for (const row of items.values()) {
    lines.push(insertUpsertSql('items', [
      'id',
      'kind',
      'title',
      'subtitle',
      'thumbnail_uri',
      'duration_sec',
      'provenance_json',
      'source_uri',
      'ref_uri',
      'license',
      'repro_json',
      'override_json',
      'display_json',
      'token_data_json',
      'list_artist_json',
      'enrichment_status',
      'updated_at_us',
    ], row, ['id']));
  }

  for (const row of entries.values()) {
    lines.push(insertUpsertSql('playlist_entries', [
      'playlist_id',
      'item_id',
      'position',
      'sort_key_us',
      'updated_at_us',
    ], row, ['playlist_id', 'item_id']));
  }

  lines.push('DELETE FROM channels_fts;');
  lines.push('INSERT INTO channels_fts(id, title) SELECT id, title FROM channels;');
  lines.push('DELETE FROM playlists_fts;');
  lines.push("INSERT INTO playlists_fts(id, title) SELECT id, title FROM playlists;");
  lines.push('DELETE FROM items_fts;');
  lines.push("INSERT INTO items_fts(id, title) SELECT id, COALESCE(title, '') FROM items;");
  lines.push('DELETE FROM item_artists_fts;');
  lines.push(`
INSERT INTO item_artists_fts(id, artist_name)
SELECT i.id, COALESCE(json_extract(j.value, '$.name'), '')
FROM items i,
     json_each(
       CASE
         WHEN json_valid(i.list_artist_json) THEN i.list_artist_json
         ELSE '[]'
       END
     ) AS j
WHERE COALESCE(json_extract(j.value, '$.name'), '') != '';`);

  lines.push('COMMIT;');
  return `${lines.join('\n')}\n`;
}

function insertUpsertSql(table, columns, row, conflictColumns) {
  const values = columns.map((col) => sqlValue(row[col])).join(', ');
  const updateAssignments = columns
    .filter((col) => !conflictColumns.includes(col))
    .map((col) => `${col}=excluded.${col}`)
    .join(', ');
  return `INSERT INTO ${table} (${columns.join(', ')})
VALUES (${values})
ON CONFLICT(${conflictColumns.join(', ')}) DO UPDATE SET ${updateAssignments};`;
}

function execSqlite(databasePath, sql) {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'ff-seed-sql-'));
  const sqlPath = path.join(tmpDir, 'seed.sql');
  fs.writeFileSync(sqlPath, sql, 'utf8');
  try {
    execFileSync('sqlite3', [databasePath, `.read ${sqlPath}`], {
      stdio: 'inherit',
    });
  } finally {
    fs.rmSync(tmpDir, {recursive: true, force: true});
  }
}

function validateOutputDatabase(databasePath) {
  const query = `
SELECT count(*) FROM channels;
SELECT count(*) FROM playlists;
SELECT count(*) FROM items;
SELECT count(*) FROM items WHERE thumbnail_uri IS NULL OR trim(thumbnail_uri) = '';
`;
  const output = execFileSync('sqlite3', [databasePath, query], {
    encoding: 'utf8',
  })
    .trim()
    .split(/\r?\n/u)
    .map((line) => Number(line.trim()));

  if (output.length < 4) {
    throw new Error('Validation failed: unexpected sqlite output.');
  }
  const [channels, playlists, items, missingThumbnails] = output;
  console.log(
    `[validate] channels=${channels} playlists=${playlists} items=${items} missing_thumbnail=${missingThumbnails}`,
  );
  if (missingThumbnails > 0) {
    throw new Error(
      `Validation failed: ${missingThumbnails} items have empty thumbnail_uri.`,
    );
  }
}

function resolveS3Config({args, env}) {
  const accessKeyId = (
    args.s3AccessKeyId ||
    env.S3_ACCESS_KEY_ID ||
    ''
  ).trim();
  const secretAccessKey = (
    args.s3SecretAccessKey ||
    env.S3_SECRET_ACCESS_KEY ||
    ''
  ).trim();
  const endpoint = (args.s3Endpoint || env.S3_ENDPOINT || '').trim();
  const objectKey = SEED_FILENAME;

  const hasAnyS3Input = [
    accessKeyId,
    secretAccessKey,
    endpoint,
  ].some((value) => String(value).trim().length > 0);

  if (!hasAnyS3Input) {
    return null;
  }
  if (!accessKeyId || !secretAccessKey || !endpoint) {
    throw new Error(
      'Incomplete S3 config. Required: access key, secret key, and endpoint.',
    );
  }
  const parsedEndpoint = new URL(endpoint);
  const pathBucket = parsedEndpoint.pathname.replace(/^\/+/u, '').split('/')[0];
  if (!pathBucket) {
    throw new Error(
      'S3_ENDPOINT must include bucket in path, e.g. '
      + 'https://<account>.r2.cloudflarestorage.com/<bucket-name>',
    );
  }

  return {
    accessKeyId,
    secretAccessKey,
    sessionToken: null,
    bucket: pathBucket,
    region: 'auto',
    endpoint: `${parsedEndpoint.protocol}//${parsedEndpoint.host}`,
    objectKey,
    pathStyle: true,
  };
}

function finalizeDatabaseFile(databasePath) {
  const finalizeSql = `
PRAGMA wal_checkpoint(TRUNCATE);
PRAGMA journal_mode=DELETE;
VACUUM;
`;
  execFileSync('sqlite3', [databasePath, finalizeSql], {
    stdio: 'ignore',
  });
  removeSqliteSidecars(databasePath);
}

function removeSqliteSidecars(databasePath) {
  const walPath = `${databasePath}-wal`;
  const shmPath = `${databasePath}-shm`;
  for (const sidecar of [walPath, shmPath]) {
    if (fs.existsSync(sidecar)) {
      fs.rmSync(sidecar, {force: true});
    }
  }
}

async function uploadToS3({filePath, config}) {
  const fileStat = fs.statSync(filePath);
  const payloadHash = await sha256FileHex(filePath);
  const amzDate = toAmzDate(new Date());
  const dateStamp = amzDate.slice(0, 8);

  const endpointUrl = config.endpoint
    ? new URL(config.endpoint)
    : new URL(`https://s3.${config.region}.amazonaws.com`);
  const host = config.pathStyle
    ? endpointUrl.host
    : `${config.bucket}.${endpointUrl.host}`;
  const protocol = endpointUrl.protocol || 'https:';

  const encodedKey = encodeS3Key(config.objectKey);
  const canonicalUri = config.pathStyle
    ? `/${encodeURIComponent(config.bucket)}/${encodedKey}`
    : `/${encodedKey}`;

  const headers = {
    host,
    'x-amz-content-sha256': payloadHash,
    'x-amz-date': amzDate,
    'content-length': String(fileStat.size),
  };
  if (config.sessionToken) {
    headers['x-amz-security-token'] = config.sessionToken;
  }

  const signedHeaderKeys = Object.keys(headers).sort();
  const canonicalHeaders = signedHeaderKeys
    .map((key) => `${key}:${String(headers[key]).trim()}\n`)
    .join('');
  const signedHeaders = signedHeaderKeys.join(';');
  const canonicalRequest = [
    'PUT',
    canonicalUri,
    '',
    canonicalHeaders,
    signedHeaders,
    payloadHash,
  ].join('\n');
  const canonicalRequestHash = sha256Hex(canonicalRequest);

  const credentialScope =
    `${dateStamp}/${config.region}/s3/aws4_request`;
  const stringToSign = [
    'AWS4-HMAC-SHA256',
    amzDate,
    credentialScope,
    canonicalRequestHash,
  ].join('\n');
  const signingKey = getSignatureKey(
    config.secretAccessKey,
    dateStamp,
    config.region,
    's3',
  );
  const signature = hmacHex(signingKey, stringToSign);
  const authorization = [
    `AWS4-HMAC-SHA256 Credential=${config.accessKeyId}/${credentialScope}`,
    `SignedHeaders=${signedHeaders}`,
    `Signature=${signature}`,
  ].join(', ');

  const requestHeaders = {
    Host: host,
    'x-amz-content-sha256': payloadHash,
    'x-amz-date': amzDate,
    Authorization: authorization,
    'Content-Length': String(fileStat.size),
  };
  if (config.sessionToken) {
    requestHeaders['x-amz-security-token'] = config.sessionToken;
  }

  const requestUrl = `${protocol}//${host}${canonicalUri}`;
  await httpPutFile({
    url: new URL(requestUrl),
    headers: requestHeaders,
    filePath,
  });

  return {url: requestUrl};
}

function toAmzDate(date) {
  const yyyy = String(date.getUTCFullYear());
  const mm = String(date.getUTCMonth() + 1).padStart(2, '0');
  const dd = String(date.getUTCDate()).padStart(2, '0');
  const hh = String(date.getUTCHours()).padStart(2, '0');
  const mi = String(date.getUTCMinutes()).padStart(2, '0');
  const ss = String(date.getUTCSeconds()).padStart(2, '0');
  return `${yyyy}${mm}${dd}T${hh}${mi}${ss}Z`;
}

function encodeS3Key(key) {
  return key
    .split('/')
    .map((part) => encodeURIComponent(part))
    .join('/');
}

function sha256Hex(input) {
  return crypto.createHash('sha256').update(input, 'utf8').digest('hex');
}

function hmac(key, value) {
  return crypto.createHmac('sha256', key).update(value, 'utf8').digest();
}

function hmacHex(key, value) {
  return crypto.createHmac('sha256', key).update(value, 'utf8').digest('hex');
}

function getSignatureKey(secretKey, dateStamp, regionName, serviceName) {
  const kDate = hmac(`AWS4${secretKey}`, dateStamp);
  const kRegion = hmac(kDate, regionName);
  const kService = hmac(kRegion, serviceName);
  return hmac(kService, 'aws4_request');
}

function sha256FileHex(filePath) {
  return new Promise((resolve, reject) => {
    const hash = crypto.createHash('sha256');
    const stream = fs.createReadStream(filePath);
    stream.on('data', (chunk) => hash.update(chunk));
    stream.on('end', () => resolve(hash.digest('hex')));
    stream.on('error', reject);
  });
}

function httpPutFile({url, headers, filePath}) {
  return new Promise((resolve, reject) => {
    const req = https.request(
      {
        protocol: url.protocol,
        hostname: url.hostname,
        port: url.port || undefined,
        path: `${url.pathname}${url.search}`,
        method: 'PUT',
        headers,
      },
      (res) => {
        let body = '';
        res.setEncoding('utf8');
        res.on('data', (chunk) => {
          body += chunk;
        });
        res.on('end', () => {
          if (res.statusCode && res.statusCode >= 200 && res.statusCode < 300) {
            resolve();
            return;
          }
          reject(
            new Error(
              `S3 upload failed: ${res.statusCode} ${res.statusMessage} ${body.slice(0, 500)}`,
            ),
          );
        });
      },
    );
    req.on('error', reject);
    const readStream = fs.createReadStream(filePath);
    readStream.on('error', reject);
    readStream.pipe(req);
  });
}

function trimSlash(value) {
  return String(value || '').replace(/\/+$/u, '');
}

function sqlValue(value) {
  if (value === null || value === undefined) {
    return 'NULL';
  }
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) {
      return 'NULL';
    }
    return String(Math.trunc(value));
  }
  if (typeof value === 'bigint') {
    return String(value);
  }
  if (typeof value === 'boolean') {
    return value ? '1' : '0';
  }
  return `'${String(value).replace(/'/gu, "''")}'`;
}

function toMicros(raw) {
  if (!raw) {
    return null;
  }
  const parsed = Date.parse(String(raw));
  if (Number.isNaN(parsed)) {
    return null;
  }
  return String(parsed * 1000);
}

function toInt(value) {
  if (value === null || value === undefined || value === '') {
    return null;
  }
  const num = Number(value);
  if (!Number.isFinite(num)) {
    return null;
  }
  return Math.trunc(num);
}

function asInt(value) {
  const num = Number(value);
  if (Number.isFinite(num)) {
    return Math.trunc(num);
  }
  return 0;
}

function chunk(items, size) {
  const out = [];
  for (let i = 0; i < items.length; i += size) {
    out.push(items.slice(i, i + size));
  }
  return out;
}

async function fetchJson(url, options = {}) {
  const res = await fetch(url, options);
  const body = await res.text();
  if (!res.ok) {
    throw new Error(
      `HTTP ${res.status} ${res.statusText} for ${url} - ${body.slice(0, 800)}`,
    );
  }
  try {
    return JSON.parse(body);
  } catch (error) {
    throw new Error(`Invalid JSON from ${url}: ${error}`);
  }
}
