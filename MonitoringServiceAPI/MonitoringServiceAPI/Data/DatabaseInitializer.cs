using Microsoft.EntityFrameworkCore;
using MonitoringServiceAPI.Models;

namespace MonitoringServiceAPI.Data
{
    public class DatabaseInitializer
    {
        public static async Task InitializeAsync(AppDbContext context, IConfiguration configuration, ILogger logger)
        {
            logger.LogInformation("=== Starting Database Initialization ===");

            try
            {
                logger.LogInformation("Testing database connection...");
                var canConnect = await context.Database.CanConnectAsync();
                if (!canConnect)
                {
                    logger.LogWarning("Cannot connect to database, attempting to create...");
                }
                else
                {
                    logger.LogInformation("Database connection test successful");
                }

                logger.LogInformation("Ensuring database exists and is up to date...");
                await context.Database.EnsureCreatedAsync();
                logger.LogInformation("Database schema ensured successfully");

                // Ensure all required tables exist
                await EnsureAllTablesExistAsync(context, logger);

                // Seed PushServerSetting if it doesn't exist
                await SeedPushServerSettingAsync(context, configuration, logger);

                await LogDatabaseStatisticsAsync(context, logger);

                logger.LogInformation("=== Database Initialization Complete ===");
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "An error occurred while initializing the database");
                throw;
            }
        }

        private static async Task<List<string>> GetTableNamesAsync(AppDbContext context)
        {
            try
            {
                var tableNames = new List<string>();
                using var connection = context.Database.GetDbConnection();
                await connection.OpenAsync();

                var command = connection.CreateCommand();
                command.CommandText = "SELECT name FROM sqlite_master WHERE type='table'";

                using var result = await command.ExecuteReaderAsync();
                while (await result.ReadAsync())
                {
                    tableNames.Add(result.GetString(0));
                }

                return tableNames;
            }
            catch
            {
                return new List<string>();
            }
        }

        public static async Task EnsureAllTablesExistAsync(AppDbContext context, ILogger logger)
        {
            try
            {
                logger.LogInformation("Checking for required database tables...");

                var requiredTables = new[]
                {
                    "Configurations",
                    "FileDataSourceConfigs",
                    "UploadQueues",
                    "FileMonitorServiceHeartBeats",
                    "PushServerSettings"
                };

                var existingTables = await GetTableNamesAsync(context);
                var missingTables = requiredTables.Where(table =>
                    !existingTables.Any(existing =>
                        string.Equals(existing, table, StringComparison.OrdinalIgnoreCase))).ToList();

                if (missingTables.Any())
                {
                    logger.LogWarning("Missing tables detected: {MissingTables}", string.Join(", ", missingTables));
                    logger.LogInformation("Creating missing tables using SQL...");

                    using var connection = context.Database.GetDbConnection();
                    await connection.OpenAsync();

                    foreach (var tableName in missingTables)
                    {
                        try
                        {
                            var createTableSql = GetCreateTableSql(tableName);
                            logger.LogInformation("Creating table: {TableName}", tableName);

                            using var command = connection.CreateCommand();
                            command.CommandText = createTableSql;
                            await command.ExecuteNonQueryAsync();

                            logger.LogInformation("Successfully created table: {TableName}", tableName);
                        }
                        catch (Exception ex)
                        {
                            logger.LogError(ex, "Failed to create table: {TableName}", tableName);
                            throw;
                        }
                    }

                    // Verify tables were created
                    var updatedTables = await GetTableNamesAsync(context);
                    var stillMissing = requiredTables.Where(table =>
                        !updatedTables.Any(existing =>
                            string.Equals(existing, table, StringComparison.OrdinalIgnoreCase))).ToList();

                    if (stillMissing.Any())
                    {
                        logger.LogError("Failed to create tables: {StillMissing}", string.Join(", ", stillMissing));
                        throw new InvalidOperationException($"Could not create required tables: {string.Join(", ", stillMissing)}");
                    }

                    logger.LogInformation("Successfully created all missing tables");
                }
                else
                {
                    logger.LogInformation("All required tables already exist");
                }

                // Log final table status
                var finalTables = await GetTableNamesAsync(context);
                logger.LogInformation("Database now contains {Count} tables: {Tables}",
                    finalTables.Count, string.Join(", ", finalTables));
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Error ensuring all tables exist");
                throw;
            }
        }

        private static string GetCreateTableSql(string tableName)
        {
            return tableName switch
            {
                "Configurations" => @"
                    CREATE TABLE IF NOT EXISTS Configurations (
                        Key TEXT PRIMARY KEY,
                        Value TEXT NOT NULL,
                        Description TEXT,
                        UpdatedAt TEXT NOT NULL,
                        Category TEXT,
                        IsEncrypted INTEGER NOT NULL DEFAULT 0
                    )",
                "FileDataSourceConfigs" => @"
                    CREATE TABLE IF NOT EXISTS FileDataSourceConfigs (
                        Id INTEGER PRIMARY KEY AUTOINCREMENT,
                        Name TEXT NOT NULL,
                        IsEnabled INTEGER NOT NULL DEFAULT 1,
                        IsRefreshing INTEGER NOT NULL DEFAULT 1,
                        FolderPath TEXT,
                        FilePattern TEXT,
                        CreatedAt TEXT NOT NULL,
                        LastProcessedAt TEXT
                    )",
                "UploadQueues" => @"
                    CREATE TABLE IF NOT EXISTS UploadQueues (
                        Id INTEGER PRIMARY KEY AUTOINCREMENT,
                        FilePath TEXT NOT NULL,
                        FileName TEXT NOT NULL,
                        FileType INTEGER NOT NULL,
                        Status INTEGER NOT NULL DEFAULT 0,
                        FileSizeBytes INTEGER NOT NULL,
                        CreatedAt TEXT NOT NULL,
                        LastAttemptAt TEXT,
                        AttemptCount INTEGER NOT NULL DEFAULT 0,
                        MaxRetries INTEGER NOT NULL DEFAULT 5,
                        ErrorMessage TEXT,
                        AzureBlobUrl TEXT,
                        AzureContainer TEXT,
                        AzureBlobName TEXT,
                        CompletedAt TEXT,
                        UploadDurationMs INTEGER,
                        Hash TEXT
                    );
                    CREATE INDEX IF NOT EXISTS IX_UploadQueue_Status ON UploadQueues(Status);
                    CREATE INDEX IF NOT EXISTS IX_UploadQueue_CreatedAt ON UploadQueues(CreatedAt);
                    CREATE INDEX IF NOT EXISTS IX_UploadQueue_Hash ON UploadQueues(Hash);",
                "FileMonitorServiceHeartBeats" => @"
                    CREATE TABLE IF NOT EXISTS FileMonitorServiceHeartBeats (
                        Id INTEGER PRIMARY KEY,
                        LastRun TEXT
                    )",
                "PushServerSettings" => @"
                    CREATE TABLE IF NOT EXISTS PushServerSettings (
                        Id INTEGER PRIMARY KEY AUTOINCREMENT,
                        IsEnabled INTEGER NOT NULL DEFAULT 0,
                        DataFolderPath TEXT NOT NULL,
                        UpdatedAt TEXT NOT NULL,
                        UpdatedBy TEXT
                    )",
                _ => throw new ArgumentException($"Unknown table name: {tableName}")
            };
        }

        private static async Task SeedPushServerSettingAsync(AppDbContext context, IConfiguration configuration, ILogger logger)
        {
            try
            {
                logger.LogInformation("Checking PushServerSetting...");

                var existingSetting = await context.PushServerSettings.FirstOrDefaultAsync();

                if (existingSetting == null)
                {
                    logger.LogInformation("No PushServerSetting found, creating default...");

                    // Get the default path from appsettings.json or use a default
                    var defaultDataFolderPath = configuration["VivotechStorage:DataFolderPath"] ?? "C:\\Data\\VivotekData";

                    var defaultSetting = new PushServerSetting
                    {
                        IsEnabled = false,
                        DataFolderPath = defaultDataFolderPath,
                        UpdatedAt = DateTime.UtcNow,
                        UpdatedBy = "System"
                    };

                    await context.PushServerSettings.AddAsync(defaultSetting);
                    await context.SaveChangesAsync();

                    logger.LogInformation("Successfully created default PushServerSetting with path: {Path}", defaultDataFolderPath);
                }
                else
                {
                    logger.LogInformation("PushServerSetting already exists (IsEnabled: {IsEnabled}, Path: {Path})",
                        existingSetting.IsEnabled, existingSetting.DataFolderPath);
                }
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Error seeding PushServerSetting");
            }
        }

        private static async Task LogDatabaseStatisticsAsync(AppDbContext context, ILogger logger)
        {
            try
            {
                var configCount = await context.Configurations.CountAsync();
                var sourceCount = await context.FileDataSourceConfigs.CountAsync();
                var queueCount = await context.UploadQueues.CountAsync();
                var heartbeatCount = await context.FileMonitorServiceHeartBeats.CountAsync();
                var pushServerCount = await context.PushServerSettings.CountAsync();

                logger.LogInformation("DB Stats -> Configurations: {Configs}, DataSources: {Sources}, UploadQueue: {Queue}, HeartBeats: {HeartBeats}, PushServerSettings: {PushSettings}",
                    configCount, sourceCount, queueCount, heartbeatCount, pushServerCount);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Error logging database statistics");
            }
        }
    }
}

