import GRDB

enum DatabaseMigrationPlan {
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_create_core_tables") { db in
            try db.create(table: "nutrition_entries") { table in
                table.column("id", .text).primaryKey()
                table.column("occurred_at", .datetime).notNull()
                table.column("title", .text).notNull()
                table.column("calories_kcal", .integer).notNull()
                table.column("protein_g", .double).notNull()
                table.column("note", .text)
                table.column("created_at", .datetime).notNull()
                table.column("updated_at", .datetime).notNull()
            }

            try db.create(table: "workout_sessions") { table in
                table.column("id", .text).primaryKey()
                table.column("occurred_at", .datetime).notNull()
                table.column("workout_type", .text).notNull()
                table.column("duration_min", .integer).notNull()
                table.column("status", .text).notNull()
                table.column("note", .text)
                table.column("created_at", .datetime).notNull()
                table.column("updated_at", .datetime).notNull()
            }

            try db.create(table: "finance_entries") { table in
                table.column("id", .text).primaryKey()
                table.column("occurred_at", .datetime).notNull()
                table.column("title", .text).notNull()
                table.column("amount", .double).notNull()
                table.column("currency", .text).notNull()
                table.column("category", .text).notNull()
                table.column("note", .text)
                table.column("created_at", .datetime).notNull()
                table.column("updated_at", .datetime).notNull()
            }

            try db.create(table: "habit_entries") { table in
                table.column("id", .text).primaryKey()
                table.column("habit_key", .text).notNull()
                table.column("date", .text).notNull()
                table.column("is_completed", .boolean).notNull()
                table.column("note", .text)
                table.column("created_at", .datetime).notNull()
                table.column("updated_at", .datetime).notNull()
            }

            try db.create(table: "body_metric_entries") { table in
                table.column("id", .text).primaryKey()
                table.column("occurred_at", .datetime).notNull()
                table.column("weight_kg", .double)
                table.column("day_rating", .integer)
                table.column("note", .text)
                table.column("created_at", .datetime).notNull()
                table.column("updated_at", .datetime).notNull()
            }

            try db.create(table: "app_settings") { table in
                table.column("id", .text).primaryKey()
                table.column("calories_target", .integer).notNull()
                table.column("protein_target_g", .double).notNull()
                table.column("monthly_budget", .double).notNull()
                table.column("default_currency", .text).notNull()
                table.column("week_starts_on", .integer).notNull()
                table.column("created_at", .datetime).notNull()
                table.column("updated_at", .datetime).notNull()
            }
        }

        return migrator
    }
}
