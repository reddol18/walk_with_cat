import 'dart:math';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LogItem {
  int id;
  int walks;
  int seconds;
  int year;
  int month;
  int day;
  int combo;

  LogItem(
      {required this.id,
      required this.walks,
      required this.seconds,
      required this.year,
      required this.month,
      required this.day,
      required this.combo
      });
}

class DbHelper {
  late Database db;

  Future openDb() async {
    final databasePath = await getDatabasesPath();
    String path = join(databasePath, 'hobak_data.db');

    db = await openDatabase(
      path,
      version: 3,
      onConfigure: (Database db) => {},
      onCreate: _onCreate,
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        print("Version Check ${oldVersion}, ${newVersion}");
        if (newVersion == 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS app_info (
              id INTEGER NOT NULL,
              title TEXT
            )
          ''');
        } else if (newVersion == 3) {
          List<Map> res = await db.rawQuery("PRAGMA table_info(last_log)", null);
          bool hasColumn = false;
          for(int i = 0 ; i < res.length; i++) {
            if (res[i]["name"] == "combo") {
              hasColumn = true;
            }
          }
          if (!hasColumn) {
            await db.execute('''
              ALTER TABLE last_log ADD combo INTEGER DEFAULT 0 NOT NULL
            ''');
            await db.execute('''
              ALTER TABLE daily_log ADD combo INTEGER DEFAULT 0 NOT NULL
            ''');
          }
        }
      },
    );
  }

  // 데이터베이스 테이블을 생성한다.
  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_log (
        id INTEGER PRIMARY KEY,
        walks INTEGER NOT NULL,
        seconds INTEGER NOT NULL,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        day INTEGER NOT NULL,
        combo INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS last_log (
        id INTEGER NOT NULL,
        walks INTEGER NOT NULL,
        seconds INTEGER NOT NULL,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        day INTEGER NOT NULL,
        combo INTEGER NOT NULL
      )
    ''');
    await db.execute('''
            CREATE TABLE IF NOT EXISTS app_info (
              id INTEGER NOT NULL,
              title TEXT
            )
          ''');
  }

  Future<LogItem?> getLogItem(int year, month, day) async {
    List<Map> logItems = await db.query("daily_log",
        columns: ["id", "walks", "seconds",
          "year", "month", "day", "combo"],
        where: "year = ? and month = ? and day = ?",
        whereArgs: [year, month, day]);
    if (logItems.length > 0) {
      return LogItem(
        id: logItems.first["id"],
        walks: logItems.first["walks"],
        seconds: logItems.first["seconds"],
        year: logItems.first["year"],
        month: logItems.first["month"],
        day: logItems.first["day"],
        combo: logItems.first["combo"],
      );
    }
    return null;
  }

  Future<LogItem?> getLastLog() async {
    List<Map> logItems = await db.query("last_log",
        columns: ["id", "walks", "seconds",
          "year", "month", "day", "combo"],
        where: "id = ?",
        whereArgs: [1]);
    if (logItems.length > 0) {
      return LogItem(
        id: logItems.first["id"],
        walks: logItems.first["walks"],
        seconds: logItems.first["seconds"],
        year: logItems.first["year"],
        month: logItems.first["month"],
        day: logItems.first["day"],
        combo: logItems.first["combo"],
      );
    }
    return null;
  }

  Future<String?> getAppInfo() async {
    List<Map> logItems = await db.query("app_info",
        columns: ["title"], where: "id = ?", whereArgs: [1]);
    if (logItems.length > 0) {
      return logItems.first["title"];
    }
    return null;
  }

  Future<List<LogItem>> getLogItems(int year, month) async {
    List<Map> result = await db.query("daily_log",
        columns: ["id", "walks", "seconds",
          "year", "month", "day", "combo"],
        where: "year = ? and month = ?",
        whereArgs: [year, month]);
    List<LogItem> rets = <LogItem>[];
    result.forEach((item) {
      rets.add(LogItem(
        id: item["id"],
        walks: item["walks"],
        seconds: item["seconds"],
        year: item["year"],
        month: item["month"],
        day: item["day"],
        combo: item["combo"],
      ));
    });
    return rets;
  }

  // 새로운 데이터를 추가한다.
  Future add(LogItem item) async {
    item.id = await db.insert(
      'daily_log', // table name
      {
        'walks': item.walks,
        'seconds': item.seconds,
        'year': item.year,
        'month': item.month,
        'day': item.day,
        'combo': item.combo,
      }, // new post row data
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return item;
  }

  Future setLastLog(LogItem item) async {
    List<Map> logItems = await db.query("last_log",
        columns: ["id", "walks", "seconds",
          "year", "month", "day", "combo"],
        where: "id = ?",
        whereArgs: [1]);
    if (logItems.length > 0) {
      await db.update(
        'last_log', // table name
        {
          'walks': item.walks,
          'seconds': item.seconds,
          'year': item.year,
          'month': item.month,
          'day': item.day,
          'combo': item.combo,
        }, // new post row data
        where: 'id = ?',
        whereArgs: [1],
      );
    } else {
      item.id = await db.insert(
        'last_log', // table name
        {
          'id': 1,
          'walks': item.walks,
          'seconds': item.seconds,
          'year': item.year,
          'month': item.month,
          'day': item.day,
          'combo': item.combo,
        }, // new post row data
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    return item;
  }

  Future setTitle(String newTitle) async {
    List<Map> logItems = await db.query("app_info",
        columns: ["id", "title"], where: "id = ?", whereArgs: [1]);
    if (logItems.length > 0) {
      await db.update(
        'app_info', // table name
        {'title': newTitle}, // new post row data
        where: 'id = ?',
        whereArgs: [1],
      );
    } else {
      await db.insert(
        'app_info', // table name
        {'id': 1, 'title': newTitle}, // new post row data
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // 변경된 데이터를 업데이트한다.
  Future update(item) async {
    await db.update(
      'daily_log', // table name
      {
        'walks': item.walks,
        'seconds': item.seconds,
        'year': item.year,
        'month': item.month,
        'day': item.day,
        'combo': item.combo,
      }, // new post row data
      where: 'id = ?',
      whereArgs: [item.id],
    );
    return item;
  }

  // 데이터를 삭제한다.
  Future<int> remove(int id) async {
    await db.delete(
      'daily_log', // table name
      where: 'id = ?',
      whereArgs: [id],
    );
    return id;
  }

  Future close() async => db.close();
}
