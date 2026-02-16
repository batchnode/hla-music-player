import 'package:flutter/material.dart';
import 'dart:math';

import '../models/song.dart';

final Random _random = Random();

Color _generateRandomColor() {
  return Color.fromARGB(
    255,
    _random.nextInt(256),
    _random.nextInt(256),
    _random.nextInt(256),
  );
}

List<Song> mockSongs = [
  Song(
    id: 1,
    title: 'Song Title 1',
    artist: 'Artist Name 1',
    albumArtUrl: 'https://picsum.photos/id/100/200/200',
  ),
  Song(
    id: 2,
    title: 'Song Title 2',
    artist: 'Artist Name 2',
    color: _generateRandomColor(),
  ),
  Song(
    id: 3,
    title: 'Song Title 3',
    artist: 'Artist Name 3',
    albumArtUrl: 'https://picsum.photos/id/101/200/200',
  ),
  Song(
    id: 4,
    title: 'Song Title 4',
    artist: 'Artist Name 4',
    color: _generateRandomColor(),
  ),
  Song(
    id: 5,
    title: 'Song Title 5',
    artist: 'Artist Name 5',
    albumArtUrl: 'https://picsum.photos/id/102/200/200',
  ),
  Song(
    id: 6,
    title: 'Song Title 6',
    artist: 'Artist Name 6',
    color: _generateRandomColor(),
  ),
  Song(
    id: 7,
    title: 'Song Title 7',
    artist: 'Artist Name 7',
    albumArtUrl: 'https://picsum.photos/id/103/200/200',
  ),
  Song(
    id: 8,
    title: 'Song Title 8',
    artist: 'Artist Name 8',
    color: _generateRandomColor(),
  ),
  Song(
    id: 9,
    title: 'Song Title 9',
    artist: 'Artist Name 9',
    albumArtUrl: 'https://picsum.photos/id/104/200/200',
  ),
  Song(
    id: 10,
    title: 'Song Title 10',
    artist: 'Artist Name 10',
    color: _generateRandomColor(),
  ),
  Song(
    id: 11,
    title: 'Song Title 11',
    artist: 'Artist Name 11',
    albumArtUrl: 'https://picsum.photos/id/105/200/200',
  ),
  Song(
    id: 12,
    title: 'Song Title 12',
    artist: 'Artist Name 12',
    color: _generateRandomColor(),
  ),
];
