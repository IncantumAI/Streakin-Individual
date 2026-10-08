// lib/core/design/icons.dart
// AppIcons registry — ALL icon references go through here.
// Spec §5.4: one family (Phosphor). Since phosphor_flutter 2.1.0 is
// incompatible with Flutter 3.47 (IconData became final), we use Material
// icons as a temporary stand-in with TODO(phosphor) markers.
// When a compatible phosphor_flutter version is available, replace each
// entry with its Phosphor equivalent — no other files need to change.
// TODO(phosphor): upgrade phosphor_flutter when Flutter 3.47-compatible version ships.

import 'package:flutter/material.dart';

// Expose IconData as the public type for icon values.
export 'package:flutter/material.dart' show Icons;

typedef PhosphorIconData = IconData;

class AppIcons {
  AppIcons._();

  // ── Navigation ────────────────────────────────────────────────────────────
  static const home = Icons.home_outlined;
  static const homeActive = Icons.home;
  static const habits = Icons.check_box_outlined;
  static const habitsActive = Icons.check_box;
  static const notes = Icons.note_outlined;
  static const notesActive = Icons.note;
  static const calendar = Icons.calendar_month_outlined;
  static const calendarActive = Icons.calendar_month;
  static const tasks = Icons.checklist;
  static const tasksActive = Icons.checklist;

  // ── Actions ───────────────────────────────────────────────────────────────
  static const add = Icons.add;
  static const edit = Icons.edit_outlined;
  static const delete = Icons.delete_outline;
  static const archive = Icons.archive_outlined;
  static const close = Icons.close;
  static const back = Icons.arrow_back;
  static const more = Icons.more_vert;
  static const check = Icons.check;
  static const drag = Icons.drag_indicator;
  static const settings = Icons.settings_outlined;
  static const settingsActive = Icons.settings;
  static const lock = Icons.lock_outline;
  static const lockOpen = Icons.lock_open_outlined;
  static const lockFill = Icons.lock;
  static const eye = Icons.visibility_outlined;
  static const eyeOff = Icons.visibility_off_outlined;
  static const export_ = Icons.upload_outlined;
  static const import_ = Icons.download_outlined;
  static const share = Icons.share_outlined;
  static const search = Icons.search;
  static const filter = Icons.filter_list;
  static const sort = Icons.sort;
  static const pin = Icons.push_pin_outlined;
  static const pinFill = Icons.push_pin;
  static const zen = Icons.air;
  static const zenFill = Icons.air;
  static const notification = Icons.notifications_outlined;
  static const notificationFill = Icons.notifications;

  // ── Habits ────────────────────────────────────────────────────────────────
  static const habitDefault = Icons.star_outline;
  static const streak = Icons.local_fire_department_outlined;
  static const streakFill = Icons.local_fire_department;
  static const restToken = Icons.coffee_outlined;
  static const skip = Icons.skip_next;
  static const milestone = Icons.emoji_events_outlined;
  static const milestoneFill = Icons.emoji_events;
  static const backfill = Icons.history;

  static const List<IconData> habitIcons = [
    Icons.star_outline,
    Icons.fitness_center,
    Icons.menu_book_outlined,
    Icons.psychology_outlined,
    Icons.coffee_outlined,
    Icons.water_drop_outlined,
    Icons.medical_services_outlined,
    Icons.restaurant_outlined,
    Icons.monitor_heart_outlined,
    Icons.eco_outlined,
    Icons.lightbulb_outline,
    Icons.nightlight_outlined,
    Icons.music_note_outlined,
    Icons.edit_outlined,
    Icons.person_outline,
    Icons.medication_outlined,
    Icons.local_florist_outlined,
    Icons.directions_run,
    Icons.wb_sunny_outlined,
    Icons.my_location_outlined,
    Icons.timer_outlined,
    Icons.directions_walk_outlined,
  ];

  // ── Notes ─────────────────────────────────────────────────────────────────
  static const folder = Icons.folder_outlined;
  static const folderFill = Icons.folder;
  static const folderOpen = Icons.folder_open_outlined;
  static const note = Icons.note_outlined;
  static const noteFill = Icons.note;
  static const tag = Icons.label_outline;
  static const tagFill = Icons.label;
  static const link = Icons.link;
  static const graph = Icons.account_tree_outlined;
  static const attach = Icons.attach_file;
  static const template = Icons.dashboard_outlined;
  static const vault = Icons.security_outlined;
  static const vaultFill = Icons.security;

  // ── To-do ─────────────────────────────────────────────────────────────────
  static const todoCircle = Icons.radio_button_unchecked;
  static const todoChecked = Icons.check_circle;
  static const priority = Icons.flag_outlined;
  static const priorityFill = Icons.flag;
  static const dueDate = Icons.event_available_outlined;

  // ── Security ──────────────────────────────────────────────────────────────
  static const biometric = Icons.fingerprint;
  static const recoveryKey = Icons.key_outlined;
  static const password = Icons.password;
  static const shield = Icons.verified_user_outlined;
  static const shieldFill = Icons.verified_user;

  // ── Empty states ──────────────────────────────────────────────────────────
  static const emptyHabits = Icons.check_box_outline_blank;
  static const emptyNotes = Icons.note_add_outlined;
  static const emptyTasks = Icons.playlist_add_check;
  static const emptyCalendar = Icons.event_note_outlined;
  static const emptySearch = Icons.search_off;
  static const emptyGraph = Icons.account_tree_outlined;
}

class AppIconSizes {
  AppIconSizes._();
  static const double sm = 20;
  static const double md = 24;
  static const double lg = 32;
}
