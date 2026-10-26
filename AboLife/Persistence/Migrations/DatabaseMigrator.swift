import Foundation
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

        migrator.registerMigration("v2_create_weekly_reviews") { db in
            try db.create(table: "weekly_reviews") { table in
                table.column("id", .text).primaryKey()
                table.column("week_start_date", .text).notNull().unique()
                table.column("wins_text", .text).notNull()
                table.column("challenges_text", .text).notNull()
                table.column("next_week_focus_text", .text).notNull()
                table.column("rating", .integer)
                table.column("created_at", .datetime).notNull()
                table.column("updated_at", .datetime).notNull()
            }
        }

        migrator.registerMigration("v3_add_weekly_workout_target") { db in
            try db.alter(table: "app_settings") { table in
                table.add(column: "weekly_workout_target", .integer)
                    .notNull()
                    .defaults(to: 3)
            }
        }

        migrator.registerMigration("v4_add_measurable_habit_fields") { db in
            try db.alter(table: "habit_entries") { table in
                table.add(column: "value", .double)
                table.add(column: "target_value", .double)
                table.add(column: "unit", .text)
            }

            try db.execute(sql: """
                UPDATE habit_entries
                SET
                    target_value = CASE habit_key
                        WHEN 'water' THEN 3.0
                        WHEN 'movement' THEN 60.0
                        WHEN 'nutrition' THEN 3.0
                        WHEN 'learning' THEN 60.0
                        WHEN 'sleep' THEN 1.0
                        ELSE 1.0
                    END,
                    unit = CASE habit_key
                        WHEN 'water' THEN 'Liter'
                        WHEN 'movement' THEN 'Min.'
                        WHEN 'nutrition' THEN 'Mahlzeiten'
                        WHEN 'learning' THEN 'Min.'
                        ELSE ''
                    END,
                    value = CASE
                        WHEN is_completed THEN CASE habit_key
                            WHEN 'water' THEN 3.0
                            WHEN 'movement' THEN 60.0
                            WHEN 'nutrition' THEN 3.0
                            WHEN 'learning' THEN 60.0
                            WHEN 'sleep' THEN 1.0
                            ELSE 1.0
                        END
                        ELSE 0.0
                    END
                WHERE value IS NULL
            """)
        }

        migrator.registerMigration("v5_create_weight_entries") { db in
            try db.create(table: "weight_entries") { table in
                table.column("id", .text).primaryKey()
                table.column("date", .text).notNull().unique()
                table.column("weight_kg", .double).notNull()
                table.column("created_at", .datetime).notNull()
                table.column("updated_at", .datetime).notNull()
            }
        }

        migrator.registerMigration("v6_create_nutrition_templates") { db in
            try db.create(table: "nutrition_templates") { table in
                table.column("id", .text).primaryKey()
                table.column("kind", .text).notNull()
                table.column("name", .text).notNull()
                table.column("calories_kcal", .integer).notNull()
                table.column("protein_g", .double).notNull()
                table.column("default_portion", .text)
                table.column("meal_type", .text)
                table.column("note", .text)
                table.column("created_at", .datetime).notNull()
                table.column("updated_at", .datetime).notNull()
            }
        }

        migrator.registerMigration("v7_create_finance_planning_tables") { db in
            try db.create(table: "finance_category_budgets") { table in
                table.column("id", .text).primaryKey()
                table.column("month_key", .text).notNull()
                table.column("category", .text).notNull()
                table.column("budget_amount", .double).notNull()
                table.column("currency", .text).notNull()
                table.column("created_at", .datetime).notNull()
                table.column("updated_at", .datetime).notNull()
                table.uniqueKey(["month_key", "category"])
            }

            try db.create(table: "finance_fixed_costs") { table in
                table.column("id", .text).primaryKey()
                table.column("title", .text).notNull()
                table.column("amount", .double).notNull()
                table.column("currency", .text).notNull()
                table.column("category", .text).notNull()
                table.column("due_day", .integer).notNull()
                table.column("is_active", .boolean).notNull()
                table.column("note", .text)
                table.column("created_at", .datetime).notNull()
                table.column("updated_at", .datetime).notNull()
            }

            try db.create(table: "finance_savings_goals") { table in
                table.column("id", .text).primaryKey()
                table.column("title", .text).notNull()
                table.column("target_amount", .double).notNull()
                table.column("current_amount", .double).notNull()
                table.column("currency", .text).notNull()
                table.column("target_date", .datetime)
                table.column("is_active", .boolean).notNull()
                table.column("note", .text)
                table.column("created_at", .datetime).notNull()
                table.column("updated_at", .datetime).notNull()
            }
        }

        migrator.registerMigration("v8_add_weight_targets_to_settings") { db in
            try db.alter(table: "app_settings") { table in
                table.add(column: "target_weight_kg", .double)
                table.add(column: "target_weight_lower_kg", .double)
                table.add(column: "target_weight_upper_kg", .double)
            }
        }

        migrator.registerMigration("v9_add_reminder_times_to_settings") { db in
            try db.alter(table: "app_settings") { table in
                table.add(column: "morning_reminder_minute_of_day", .integer)
                    .notNull()
                    .defaults(to: AppSettingsDefaults.morningReminderMinuteOfDay)
                table.add(column: "training_reminder_minute_of_day", .integer)
                    .notNull()
                    .defaults(to: AppSettingsDefaults.trainingReminderMinuteOfDay)
                table.add(column: "evening_reminder_minute_of_day", .integer)
                    .notNull()
                    .defaults(to: AppSettingsDefaults.eveningReminderMinuteOfDay)
            }
        }

        migrator.registerMigration("v10_create_finance_categories") { db in
            try db.create(table: "finance_categories") { table in
                table.column("id", .text).primaryKey()
                table.column("name", .text).notNull()
                table.column("normalized_key", .text).notNull()
                table.column("kind", .text).notNull().defaults(to: "expense")
                table.column("is_default", .boolean).notNull().defaults(to: false)
                table.column("is_active", .boolean).notNull().defaults(to: true)
                table.column("sort_order", .integer).notNull().defaults(to: 0)
                table.column("created_at", .datetime).notNull()
                table.column("updated_at", .datetime).notNull()
                table.uniqueKey(["kind", "normalized_key"])
            }

            let now = Date()
            for (index, category) in FinanceCategoryCatalog.defaultExpenseCategories.enumerated() {
                try FinanceCategoryRecord(
                    name: category,
                    kind: "expense",
                    isDefault: true,
                    isActive: true,
                    sortOrder: index,
                    createdAt: now,
                    updatedAt: now
                ).insert(db)
            }
        }

        migrator.registerMigration("v11_create_workout_detail_tables") { db in
            try db.alter(table: "workout_sessions") { table in
                table.add(column: "workout_intensity", .text)
                table.add(column: "pain_reported", .boolean)
                    .notNull()
                    .defaults(to: false)
            }

            try db.create(table: "workout_exercises") { table in
                table.column("id", .text).primaryKey()
                table.column("session_id", .text)
                    .notNull()
                    .indexed()
                    .references("workout_sessions", onDelete: .cascade)
                table.column("exercise_name", .text).notNull()
                table.column("sort_order", .integer).notNull()
                table.column("is_completed", .boolean).notNull().defaults(to: false)
                table.column("note", .text)
                table.column("pain_reported", .boolean).notNull().defaults(to: false)
                table.column("created_at", .datetime).notNull()
                table.column("updated_at", .datetime).notNull()
            }

            try db.create(table: "workout_sets") { table in
                table.column("id", .text).primaryKey()
                table.column("exercise_id", .text)
                    .notNull()
                    .indexed()
                    .references("workout_exercises", onDelete: .cascade)
                table.column("set_number", .integer).notNull()
                table.column("reps", .integer)
                table.column("weight_kg", .double)
                table.column("duration_sec", .integer)
                table.column("rpe", .double)
                table.column("note", .text)
                table.column("pain_reported", .boolean).notNull().defaults(to: false)
                table.column("created_at", .datetime).notNull()
                table.column("updated_at", .datetime).notNull()
            }
        }

        return migrator
    }
}
