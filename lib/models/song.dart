import 'package:flutter/material.dart';

class Song {
  final int id;
  final String title;
  final String artist;
  final String? genre;
  final String? album;
  final String? albumArtUrl;
  final String? externalArtPath;
  final String? uri; // Path or URI to the audio file
  final int? duration;
  final Color? color;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    this.genre,
    this.album,
    this.albumArtUrl,
    this.externalArtPath,
    this.uri,
    this.duration,
    this.color,
  });
}
