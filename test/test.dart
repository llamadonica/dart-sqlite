import 'dart:io';
import 'dart:math';

import 'package:dart_sqlite/sqlite.dart' as sqlite;

import 'package:guinness2/guinness2.dart';

testFirst(res) {
  it("handles evaluations", () {
    var db = res[0];

    var row = db.first("SELECT ?+2, UPPER(?)", [3, "hello"]);

    expect(5).toBe(row[0]);
    expect("HELLO" == row[1]).toBe(true);
  });
}

testRow(res) {
  it("does basic queries", () {
    var db = res[0];
    var row = db.first("SELECT 42 AS foo");
    expect(0).toBe(row.index);

    expect(42).toBe(row[0]);
    expect(42).toBe(row['foo']);
    //expect(42).toBe(row.foo);

    var resultAsList = row.asList();
    expect(resultAsList.length).toBe(1);
    expect(resultAsList).toContain(42);
    var resultAsMap = row.asMap();
    expect(resultAsMap.length).toBe(1);
    expect(resultAsMap['foo']).toBe(42);
  });
}

testBulk(res) {
  it("does database operations", () {
    var db = res[0];
    createBlogTable(db);
    var insert = db.prepare("INSERT INTO posts (title, body) VALUES (?,?)");
    try {
      expect(1).toBe(insert.execute(["hi", "hello world"]));
      expect(1).toBe(insert.execute(["bye", "goodbye cruel world"]));
    } finally {
      insert.close();
    }
    var rows = [];
    expect(2).toBe(db.execute("SELECT * FROM posts", callback: (row) {
      rows.add(row);
    }));
    expect(2).toBe(rows.length);
    expect("hi" == rows[0]['title']);
    expect("bye" == rows[1]['title']).toBe(true);
    expect(0).toBe(rows[0].index);
    expect(1).toBe(rows[1].index);
    rows = [];
    expect(1).toBe(db.execute("SELECT * FROM posts", callback: (row) {
      rows.add(row);
      return true;
    }));
    expect(1).toBe(rows.length);
    expect("hi" == rows[0]['title']).toBe(true);
  });
}

testTransactionSuccess(res) {
  it("handles transactions", () {
    var db = res[0];
    createBlogTable(db);
    expect(42).toBe(db.transaction(() {
      db.execute("INSERT INTO posts (title, body) VALUES (?,?)");
      return 42;
    }));
    expect(1).toBe(db.execute("SELECT * FROM posts"));
  });
}

testTransactionFailure(res) {
  it("cancels the transaction when interrupted", () {
    var db = res[0];
    createBlogTable(db);
    try {
      db.transaction(() {
        db.execute("INSERT INTO posts (title, body) VALUES (?,?)");
        throw new ArgumentError("whee");
      });
    } catch (expected) {}
    expect(0).toBe(db.execute("SELECT * FROM posts"));
  });
}

testSyntaxError(res) {
  it("throws an exception for non-sql", () {
    var db = res[0];
    expect(() => db.execute("random non sql")).toThrowWith(
        type: sqlite.SqliteSyntaxException);
  });
}

testColumnError(res) {
  it("throws an error on a bad interpreted query", () {
    var db = res[0];
    expect(() => db.first("select 2+2")['qwerty']).toThrowWith(
        type: sqlite.SqliteException);
  });
}

main() {
  [testFirst, testRow, testBulk, testSyntaxError, testColumnError].forEach((test) {
    connectionOnDisk(test);
    connectionInMemory(test);
  });
  print("All tests pass!");
}

createBlogTable(db) {
  db.execute("CREATE TABLE posts (title text, body text)");
}

deleteWhenDone(callback(filename)) {
  var rng = new Random();
  var nonce = rng.nextInt(100000000);
  var filename = "dart-sqlite-test-${nonce}";

  afterEach(() {
    var f = new File(filename);
    if (f.existsSync()) f.deleteSync();
  });
    callback(filename);
}

connectionOnDisk(callback(connection)) {
  describe("with file", ()
  {
    deleteWhenDone((filename) {
      List c = [];
      beforeEach(() {
        c.add(new sqlite.Database.inMemory());
      });
      afterEach(() {
        c.last.close();
      });
      callback(c);
    });
  });
}

connectionInMemory(callback(connection)) {
  describe("in memory", ()
  {
    List c = [];// = new sqlite.Database.inMemory();
    beforeEach(() {
      c.add(new sqlite.Database.inMemory());
    });
    afterEach(() {
      c.last.close();
    });
    callback(c);
  });
}
