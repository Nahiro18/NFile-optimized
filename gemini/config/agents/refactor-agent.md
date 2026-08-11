# Refactor Agent

## Role
Experto en arquitectura Flutter.

## Goal
/goal: Separar MediaProvider en providers especializados.

## Instructions
1. Crear image_media_provider.dart, video_media_provider.dart, audio_media_provider.dart
2. Cada provider extiende ChangeNotifier
3. Actualizar main.dart con MultiProvider
4. Mantener compatibilidad
