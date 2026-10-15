import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/mini_game_model.dart';
import 'sky_jumper/sky_jumper_page.dart';
import 'sky_jumper/sky_jumper_setup.dart';

/// Maps a database game to the engine shipped in this build.
///
/// `mini_games.code` is the contract between the two halves: the server owns
/// the metadata and the entitlement, the app owns the engine. A row whose code
/// this build does not know simply has no engine — the listing keeps showing it
/// with the "coming soon" message instead of crashing, which is what lets the
/// backend list a game before the client that plays it has shipped.
const _playableCodes = {'sky_jumper'};

/// Whether this build can actually play [game].
bool hasEngineFor(MiniGame game) => _playableCodes.contains(game.code);

/// Build the engine for [game].
///
/// [avatarSprite] is the player's composed avatar, already flattened to a
/// bitmap by the caller. Optional on purpose: a game must still start when the
/// avatar could not be rasterised (nothing owned yet, artwork not downloaded),
/// and each engine falls back to its own primitive player.
Widget? buildMiniGame(
  MiniGame game, {
  required int seed,
  ui.Image? avatarSprite,
}) {
  switch (game.code) {
    case 'sky_jumper':
      return SkyJumperPage(
        title: game.title,
        setup: SkyJumperSetup.fromJson(game.setup),
        seed: seed,
        avatarSprite: avatarSprite,
      );
    default:
      return null;
  }
}
