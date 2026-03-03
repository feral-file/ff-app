//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

// ignore_for_file: public_member_api_docs, constant_identifier_names // Reason: copied from the legacy mobile app to keep constants stable/portable.

// NOTE: This file is a minimal subset extracted from the old mobile app.
// Keep identifiers stable to reduce churn when copying extensions/models.

const TEIA_ART_CONTRACT_ADDRESSES = [
  'KT1RJ6PbjHpwc3M5rw5s2Nbmefwbuwbdxton',
];

const OPENSEA_ASSET_PREFIX = 'https://opensea.io/item/ethereum';
const OBJKT_ASSET_PREFIX_MAINNET = 'https://objkt.com/asset/';
const TEIA_ART_ASSET_PREFIX = 'https://teia.art/objkt/';
const FXHASH_IDENTIFIER = 'fxhash.xyz';

// Old repo derives this from environment (testnet vs mainnet).
// We default to mainnet here to keep domain pure.
String get objktAssetPrefix => OBJKT_ASSET_PREFIX_MAINNET;
