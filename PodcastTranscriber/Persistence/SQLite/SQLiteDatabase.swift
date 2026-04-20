import Foundation
import SQLite3

/// A lightweight SQLite database wrapper.
class SQLiteDatabase {
    private var db: OpaquePointer?

    init(path: String) throws {
        if sqlite3_open(path, &db) != SQLITE_OK {
            throw SQLiteError.openDatabase(message: "Unable to open database at \(path)")
        }
    }

    deinit {
        sqlite3_close(db)
    }

    func execute(_ sql: String) throws {
        var errMsg: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            let message = String(cString: errMsg!)
            sqlite3_free(errMsg)
            throw SQLiteError.executionFailed(message: message)
        }
    }

    func query(_ sql: String) throws -> [[String: Any]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.executionFailed(message: "Failed to prepare query")
        }
        defer { sqlite3_finalize(statement) }

        var rows: [[String: Any]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String: Any] = [:]
            for column in 0..<sqlite3_column_count(statement) {
                let name = String(cString: sqlite3_column_name(statement, column))
                let value: Any
                switch sqlite3_column_type(statement, column) {
                case SQLITE_INTEGER:
                    value = sqlite3_column_int64(statement, column)
                case SQLITE_FLOAT:
                    value = sqlite3_column_double(statement, column)
                case SQLITE_TEXT:
                    value = String(cString: sqlite3_column_text(statement, column))
                case SQLITE_NULL:
                    value = NSNull()
                default:
                    value = NSNull()
                }
                row[name] = value
            }
            rows.append(row)
        }
        return rows
    }
}

/// SQLite-related errors.
enum SQLiteError: Error {
    case openDatabase(message: String)
    case executionFailed(message: String)
}