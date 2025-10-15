# Azure Blob Storage Organization - Implementation Summary

## Overview
Implemented a comprehensive categorization system for Azure Blob Storage uploads to organize files by data source and date.

## New Structure

### Before (Old Structure)
```
container/
  └── 2025/01/15/10/  (hourly folders)
      └── abc12345_filename.json
```

### After (New Structure)
```
container/
  └── [datasource-name]/  (e.g., "camera-01", "gps-tracker", "api-weather")
      └── 20250115/  (daily folders, compact format)
          └── datasource-name_20250115_103045_filename.json
```

**Example:**
- **File Monitor**: `camera-01/20250115/camera-01_20250115_143022_image001.jpg`
- **API Monitor**: `api-weather-data/20250115/api-weather-data_20250115_103045_api_response.json`

## Architecture Flow

```
┌─────────────────────────────┐
│  APIMonitorWorkerService    │
│  - Polls API endpoints      │
│  - Saves to temp folder     │
│    /data/api-weather/       │
└──────────┬──────────────────┘
           │ (saves files)
           ▼
┌─────────────────────────────┐
│  FileMonitorWorkerService   │
│  - Monitors folders         │
│  - Reads data source info   │
│  - Uploads to Azure with    │
│    categorization           │
└──────────┬──────────────────┘
           │ (uploads)
           ▼
┌─────────────────────────────┐
│  Azure Blob Storage         │
│  datasource/YYYYMMDD/       │
│  datasource_timestamp_file  │
└─────────────────────────────┘
```

## Changes Made

### 1. FileMonitorWorkerService

#### A. Model Updates (`Models/UploadQueue.cs`)
- ✅ Added `DataSourceId` (nullable int) - ID of the data source
- ✅ Added `DataSourceName` (nullable string, max 100 chars) - Name for categorization

#### B. Service Updates

**`Services/FolderWatcherService.cs`**
- ✅ Updated to capture data source info when creating upload queue entries
- ✅ Populates `DataSourceId` and `DataSourceName` from `FileDataSourceConfig`

**`Services/AzureStorageService.cs`**
- ✅ Updated `UploadFileAsync()` to accept optional `dataSourceName` parameter
- ✅ Updated `UploadDataAsync()` to accept optional `dataSourceName` parameter
- ✅ Completely rewrote `GenerateBlobName()` method:
  - Uses format: `{datasource}/{YYYYMMDD}/{datasource}_{YYYYMMDD_HHMMSS}_{filename}`
  - Sanitizes data source names (lowercase, spaces to hyphens)
  - Falls back to "uncategorized" folder if no data source provided

**`Services/UploadProcessService.cs`**
- ✅ Updated to pass `DataSourceName` to Azure upload methods
- ✅ Removed manual blob name generation (now auto-generated with categorization)

#### C. Database Migration (`Data/DatabaseInitializer.cs`)
- ✅ Updated `UploadQueues` table schema to include new columns
- ✅ Added `ApplySchemaUpdatesAsync()` method for existing databases:
  - Checks for column existence using `PRAGMA table_info`
  - Adds `DataSourceId` column if missing
  - Adds `DataSourceName` column if missing
  - Creates index on `DataSourceId`
- ✅ Backward compatible - won't break existing installations

### 2. APIMonitorWorkerService

**NO CHANGES NEEDED** - This service continues to work as designed:
- ✅ Polls API endpoints periodically
- ✅ Saves responses to local temp folder
- ✅ Filename format: `api_response_{configName}_{timestamp}.{extension}`
- ✅ FileMonitorWorkerService picks up these files and uploads to Azure with categorization

**Why no changes?**
The architecture already handles this correctly:
1. APIMonitorWorkerService saves API data to temp folders (e.g., `/data/api-temp/`)
2. FileMonitorWorkerService monitors those folders
3. FileMonitorWorkerService uploads with proper categorization based on folder data source configuration

## Configuration

Both services use the same Azure configuration keys:
- `Azure.StorageConnectionString` - Azure Storage connection string
- `Azure.DefaultContainer` - Container name (default: "gateway-data")

## Benefits

### 1. **Better Organization**
- Files grouped by data source (camera, GPS, API, etc.)
- Daily folders for easy date-based navigation
- Clear, descriptive filenames

### 2. **Easy Management**
- Set lifecycle policies per data source folder
- Quick identification of data sources
- Simplified cleanup and archival

### 3. **Improved Searchability**
- Filter by data source prefix
- Navigate by date
- Consistent naming convention

### 4. **Backward Compatibility**
- Existing files remain accessible
- New files use new structure
- No data loss during migration
- Database migration runs automatically

## Examples

### File Monitor Example
**Data Source:** "CameraFrontDoor"
**File:** "IMG_20250115_143022.jpg"
**Upload Path:** `camera-frontdoor/20250115/camera-frontdoor_20250115_143022_IMG_20250115_143022.jpg`

### API Monitor Example
**Setup:**
1. APIMonitorWorkerService saves to: `/data/api-weather/api_response_API-Weather-Service_20250115_103045.json`
2. FileMonitorWorkerService monitors `/data/api-weather/` (configured as data source "API-Weather-Service")
3. FileMonitorWorkerService uploads to Azure

**Upload Path:** `api-weather-service/20250115/api-weather-service_20250115_103045_api_response_API-Weather-Service_20250115_103045.json`

### GPS Data Example (via Push Server)
**Data Source:** "GPS-Tracker-01"
**File:** "gps_data_20250115_120500.json"
**Upload Path:** `gps-tracker-01/20250115/gps-tracker-01_20250115_120500_gps_data.json`

## Testing Checklist

- [ ] FileMonitorWorkerService starts without errors
- [ ] Existing databases are migrated (check logs for "Adding DataSourceId column")
- [ ] New files are uploaded with correct structure
- [ ] APIMonitorWorkerService uploads API responses directly
- [ ] Data source names are properly sanitized
- [ ] Files without data source go to "uncategorized" folder
- [ ] Azure blob metadata is populated correctly

## Migration Notes

### For Existing Installations:
1. **No action required** - migration happens automatically
2. Database will be updated on first service start
3. Check logs for migration confirmation:
   ```
   Adding DataSourceId column to UploadQueues table...
   Adding DataSourceName column to UploadQueues table...
   Schema updates applied successfully
   ```

### For New Installations:
- Tables will be created with new schema from the start

## Rollback Plan

If needed, the changes can be rolled back:
1. Revert code changes
2. Old structure will still work (columns are nullable)
3. No data loss - uploaded blobs remain in Azure

## Future Enhancements

Potential improvements:
- Add virtual folders for file types (images/, json/, etc.)
- Implement custom categorization rules per data source
- Add year/month hierarchy option for long-term archival
- Support custom date format preferences
- Add data source grouping (e.g., cameras/camera-01/)

---

## Files Modified

### FileMonitorWorkerService
1. `Models/UploadQueue.cs`
2. `Services/FolderWatcherService.cs`
3. `Services/AzureStorageService.cs`
4. `Services/UploadProcessService.cs`
5. `Data/DatabaseInitializer.cs`

### APIMonitorWorkerService
**No changes** - Works as originally designed (saves to temp folders)

---

**Implementation Date:** October 15, 2025
**Status:** ✅ Complete - Ready for Testing

