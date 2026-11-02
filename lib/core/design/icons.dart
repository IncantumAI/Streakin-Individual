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

  // ── Additional glyphs (single source for the Icons.* lint) ───────────────
  static const boltRounded = Icons.bolt_rounded;
  static const lockReset = Icons.lock_reset;
  static const articleOutlined = Icons.article_outlined;
  static const chevronRight = Icons.chevron_right;
  static const calendarTodayOutlined = Icons.calendar_today_outlined;
  static const checkCircleOutline = Icons.check_circle_outline;
  static const cancelOutlined = Icons.cancel_outlined;
  static const trackChangesOutlined = Icons.track_changes_outlined;
  static const coffee = Icons.coffee;
  static const event = Icons.event;
  static const sync = Icons.sync;
  static const errorOutline = Icons.error_outline;
  static const formatBold = Icons.format_bold;
  static const formatItalic = Icons.format_italic;
  static const formatUnderline = Icons.format_underline;
  static const formatStrikethrough = Icons.format_strikethrough;
  static const title = Icons.title;
  static const formatListBulleted = Icons.format_list_bulleted;
  static const formatListNumbered = Icons.format_list_numbered;
  static const formatQuote = Icons.format_quote;
  static const horizontalRule = Icons.horizontal_rule;
  static const addTask = Icons.add_task;
  static const linkOff = Icons.link_off;
  static const tagIcon = Icons.tag;
  static const layersOutlined = Icons.layers_outlined;
  static const openInNew = Icons.open_in_new;
  static const pictureAsPdfOutlined = Icons.picture_as_pdf_outlined;
  static const descriptionOutlined = Icons.description_outlined;
  static const slideshowOutlined = Icons.slideshow_outlined;
  static const autoAwesomeOutlined = Icons.auto_awesome_outlined;
  static const imageOutlined = Icons.image_outlined;
  static const tableChartOutlined = Icons.table_chart_outlined;
  static const textSnippetOutlined = Icons.text_snippet_outlined;
  static const folderSpecialOutlined = Icons.folder_special_outlined;
  static const createNewFolderOutlined = Icons.create_new_folder_outlined;
  static const inboxOutlined = Icons.inbox_outlined;
  static const keyboardArrowDown = Icons.keyboard_arrow_down;
  static const keyboardArrowRight = Icons.keyboard_arrow_right;
  static const driveFileRenameOutline = Icons.drive_file_rename_outline;
  static const visibility = Icons.visibility;
  static const visibilityOff = Icons.visibility_off;
  static const timerOutlined = Icons.timer_outlined;
  static const addModeratorOutlined = Icons.add_moderator_outlined;
  static const autorenew = Icons.autorenew;
  static const deleteForeverOutlined = Icons.delete_forever_outlined;
  static const swapHoriz = Icons.swap_horiz;
  static const cleaningServicesOutlined = Icons.cleaning_services_outlined;
  static const deleteForever = Icons.delete_forever;
  static const paletteOutlined = Icons.palette_outlined;
  static const shieldOutlined = Icons.shield_outlined;
  static const storageOutlined = Icons.storage_outlined;
  static const keyboardOutlined = Icons.keyboard_outlined;
  static const accessibilityNewOutlined = Icons.accessibility_new_outlined;
  static const mailOutline = Icons.mail_outline;
  static const privacyTipOutlined = Icons.privacy_tip_outlined;
  static const lightModeOutlined = Icons.light_mode_outlined;
  static const brightnessAutoOutlined = Icons.brightness_auto_outlined;
  static const darkModeOutlined = Icons.dark_mode_outlined;
  static const animationOutlined = Icons.animation_outlined;
  static const notificationAddOutlined = Icons.notification_add_outlined;
  static const lockClockOutlined = Icons.lock_clock_outlined;
  static const alternateEmail = Icons.alternate_email;
  static const checklistOutlined = Icons.checklist_outlined;
  static const warningAmberOutlined = Icons.warning_amber_outlined;
  static const checkCircleOutlined = Icons.check_circle_outlined;
  static const doNotDisturbAltOutlined = Icons.do_not_disturb_alt_outlined;
  static const titleOutlined = Icons.title_outlined;
  static const helpOutline = Icons.help_outline;
  static const infoOutline = Icons.info_outline;
  static const newReleasesOutlined = Icons.new_releases_outlined;
  static const devices = Icons.devices;
  static const addLink = Icons.add_link;
  static const eventOutlined = Icons.event_outlined;
  static const doneAll = Icons.done_all;
  static const scheduleOutlined = Icons.schedule_outlined;
  static const editNote = Icons.edit_note;
  static const selfImprovement = Icons.self_improvement;
}

class AppIconSizes {
  AppIconSizes._();
  static const double sm = 20;
  static const double md = 24;
  static const double lg = 32;
}
